# MVP Spec Sheet — STR Operations Platform

**Version:** 0.3 MVP
**Date:** March 2026
**Status:** Pre-development

---

## Key Decisions

| Decision Area | Choice | Rationale |
|---|---|---|
| WhatsApp API | Twilio | Simpler setup than Meta Cloud API, better docs |
| iCal polling interval | 30 minutes | Balance between freshness and API load |
| Backup cleaner logic | Phase 2 | Adds complexity, not critical for MVP validation |
| WhatsApp language | English only | Focus on single market, add i18n in Phase 2 |
| Cleaner notes | NOTE keyword | Allow cleaners to add notes separate from issues |
| Non-response escalation | Re-send at 2h, email host at 4h | Ensure no missed tasks due to cleaner non-response |
| Deployment | Cloudflare Workers + Pages | Edge compute, low latency, integrated cron |
| Frontend | Vite + React SPA | Fast builds, simpler than Next.js for MVP |
| Cron jobs | Cloudflare Cron Triggers | Native to Workers, no third-party dependency |

---

## Product Summary

A lightweight operations platform for short-term rental hosts that automates cleaning task creation from booking data and dispatches tasks to cleaners via WhatsApp. The host uses a web dashboard. The cleaner never leaves WhatsApp.

**Core loop:** Booking syncs → Task auto-created → Cleaner notified on WhatsApp → Cleaner completes task → Host sees status update.

---

## Tech Stack

- **Frontend:** Vite + React SPA on Cloudflare Pages
- **Backend:** Cloudflare Workers (API + background jobs)
- **Database/Auth/Realtime:** Supabase
- **API validation:** Zod via @hono/zod-openapi
- **API docs:** OpenAPI auto-generated from Zod schemas
- **Messaging:** Twilio WhatsApp API
- **Email:** Resend
- **Cron/Scheduling:** Cloudflare Cron Triggers
- **CI/CD:** GitHub Actions

---

## Monorepo Structure

```
str-platform/
├── frontend/               # Vite + React app (Cloudflare Pages)
│   ├── src/
│   ├── public/
│   ├── vite.config.ts
│   └── package.json
├── worker-api/             # Cloudflare Worker (REST API)
│   ├── src/
│   ├── wrangler.toml
│   └── package.json
├── worker-jobs/            # Cloudflare Worker (cron jobs)
│   ├── src/
│   ├── wrangler.toml
│   └── package.json
├── .github/
│   └── workflows/
│       ├── deploy-frontend.yml
│       ├── deploy-api.yml
│       └── deploy-jobs.yml
├── package.json            # Root workspace
└── pnpm-workspace.yaml
```

---

## Data Model (5 core tables + sessions table)

### users
- id (uuid, PK)
- email
- name
- phone
- role (host)
- created_at

### properties
- id (uuid, PK)
- user_id (FK → users)
- name (e.g. "Vallila Studio")
- address
- door_code
- wifi_password
- checkin_time (default time, e.g. 15:00)
- checkout_time (default time, e.g. 11:00)
- ical_url (Airbnb/Booking.com iCal feed URL)
- default_cleaner_id (FK → cleaners)
- special_instructions (free text)
- checklist (JSON array of checklist items, e.g. ["Vacuum all rooms", "Replace towels", "Check fridge", "Empty bins"])
- created_at

### cleaners
- id (uuid, PK)
- user_id (FK → users, the host who added this cleaner)
- name
- phone (WhatsApp number, international format)
- email (optional)
- active_task_id (FK → tasks, nullable — tracks current task in progress)
- created_at

### tasks
- id (uuid, PK)
- property_id (FK → properties)
- cleaner_id (FK → cleaners, nullable)
- type (enum: turnover_clean, deep_clean, mid_stay_clean, maintenance, ad_hoc)
- status (enum: pending, sent, accepted, in_progress, completed, issue_reported)
- scheduled_date
- time_window_start (e.g. 11:00)
- time_window_end (e.g. 15:00)
- guest_count (integer, nullable)
- checklist_snapshot (JSON, copied from property at task creation time)
- checklist_status (JSON, tracks which items are ticked)
- issue_text (free text, nullable)
- issue_photo_url (nullable)
- cleaner_notes (free text, nullable — added via NOTE keyword)
- completed_at (timestamp, nullable)
- created_at
- source (enum: auto_ical, manual)

### bookings (derived from iCal sync)
- id (uuid, PK)
- property_id (FK → properties)
- ical_uid (unique ID from iCal event, used for dedup)
- guest_name (if available from iCal summary)
- checkin_date
- checkout_date
- guest_count (nullable, often not in iCal)
- created_at

### whatsapp_sessions
- id (uuid, PK)
- cleaner_id (FK → cleaners)
- task_id (FK → tasks)
- conversation_state (enum: awaiting_response, active, completed)
- last_message_at (timestamp)
- created_at

---

## Feature Specs

### 1. Host Authentication

- Email + password signup/login via Supabase Auth
- No social login, no SSO. Keep it simple.
- Single user per account in MVP (no team roles)

### 2. Property Management

**Add property form:**
- Name (required)
- Address (required)
- Door code (required)
- WiFi password (optional)
- Default check-in time (required, time picker)
- Default check-out time (required, time picker)
- iCal URL (optional — can add later)
- Special instructions (free text, optional)
- Default cleaner (dropdown, optional — can assign later)
- Checklist (dynamic list — host adds items as text strings, can reorder and delete)

**Edit property:** Same form, pre-populated.

**Delete property:** Soft delete. Confirm dialog. Does not delete historical tasks.

**No limit on number of properties in MVP.**

### 3. Calendar Sync (iCal)

**How it works:**
- Host pastes an iCal URL from Airbnb, Booking.com, or Vrbo into the property settings.
- A Cloudflare Cron Trigger runs every 30 minutes to poll all iCal URLs.
- The system parses VEVENT entries and upserts into the bookings table using ical_uid for deduplication.
- When a new booking is detected, the system checks if a task already exists for that turnover window. If not, it creates one.

**Task auto-creation logic:**
- For each booking, look at the checkout_date.
- Check if there is a subsequent booking for the same property.
- If yes: create a turnover_clean task with time_window_start = checkout_time and time_window_end = next booking's checkin_time.
- If no subsequent booking: create a turnover_clean task with time_window_start = checkout_time and time_window_end = checkout_time + 4 hours (default buffer).
- Attach the property's checklist as checklist_snapshot.
- Assign the property's default_cleaner_id.
- Set status to "pending".

**Handling booking changes:**
- If a booking's dates change (detected via ical_uid match but different dates), update the booking record and update the associated task's scheduled_date and time_window.
- If a booking is cancelled (ical_uid disappears from feed), mark the associated task as cancelled. Do not delete.

**Edge cases to handle:**
- Same-day turnover (checkout and checkin on same day): flag on host dashboard with a warning if time window is < 3 hours.
- Back-to-back bookings with no gap: still create the task, let the host decide.

### 4. Cleaner Management

**Add cleaner:**
- Name (required)
- Phone number (required, must be valid WhatsApp number in international format e.g. +358401234567)
- Email (optional)

**Edit/delete cleaner.** Deleting a cleaner unassigns them from properties and future tasks.

**Assign default cleaner per property** from the property settings page (dropdown of added cleaners).

**No cleaner login or cleaner-side account.** Cleaners interact entirely via WhatsApp.

### 5. Task Management (Host Dashboard)

**Dashboard view:**
- Default view: list of tasks grouped by date, sorted chronologically.
- Each task card shows: property name, date, time window, assigned cleaner name, status badge (color-coded), task type.
- Filter by: property, status, date range.
- Status badges: Pending (grey), Sent (blue), Accepted (yellow), In Progress (orange), Completed (green), Issue Reported (red).

**Manual task creation:**
- Host can create a task manually for any property.
- Fields: property (dropdown), type (dropdown), date, time, assign cleaner (dropdown), notes (free text).
- Use case: ad-hoc maintenance, deep cleans, restocking.

**Task detail view:**
- All task fields visible.
- Checklist with tick status (read-only for host — cleaner updates via WhatsApp).
- Issue section: if cleaner reported an issue, show the text and photo.
- Cleaner notes section: if cleaner added notes via NOTE keyword, display here.
- Ability to reassign task to a different cleaner (triggers new WhatsApp message to new cleaner).

### 6. WhatsApp Integration (Cleaner Experience)

This is the core differentiator. The cleaner never uses a web app or downloads anything. All interaction happens in WhatsApp.

**Outbound messages from system to cleaner:**

**Task notification (sent when task is created or assigned):**
```
New cleaning task 🏠

Property: Vallila Studio
Date: Thursday 14 March
Time: 11:00 – 15:00
Door code: 4521
WiFi: VallilaGuest2024
Guests: 4

Special instructions: Extra towels in bedroom closet. Check dishwasher salt.

Reply ACCEPT to confirm or DECLINE if unavailable.
```

**Task reminder (sent morning of task day if status is still "accepted", not "in_progress"):**
```
Reminder: You have a clean today 🧹

Property: Vallila Studio
Time: 11:00 – 15:00
Door code: 4521

Reply START when you arrive.
```

**Non-response escalation:**
- If cleaner has not responded (no ACCEPT or DECLINE) within 2 hours of task notification, system re-sends the task notification.
- If still no response after 4 hours total, system sends email to host alerting them to assign the task manually or contact the cleaner directly.

**Inbound messages from cleaner (parsed by the system):**

| Cleaner message | System action |
|---|---|
| ACCEPT | Set task status to "accepted". Notify host. |
| DECLINE | Set task status to "pending". Notify host that cleaner declined. Host must reassign manually in MVP. |
| START | Set task status to "in_progress". Set cleaner.active_task_id to this task. Log start time. |
| DONE | Set task status to "completed". Clear cleaner.active_task_id. Log completion time. Notify host. |
| ISSUE [text] | Set task status to "issue_reported". Save text. Notify host immediately. |
| NOTE [text] | Save text to cleaner_notes field. Acknowledge to cleaner. Does not change status. |
| (any photo) | If task is in_progress or issue_reported, attach photo URL to task. |
| CHECKLIST | System sends the checklist items as a numbered list. Cleaner replies with numbers to tick off items (e.g. "1,2,3" or "all"). |
| Any other text | Reply with: "I didn't understand that. Reply ACCEPT, DECLINE, START, DONE, ISSUE [description], NOTE [text], or CHECKLIST." |

**Keyword matching should be case-insensitive and support common variations:**
- ACCEPT / OK / YES / CONFIRM → accept
- DECLINE / NO / CANT / CAN'T → decline
- START / ARRIVED / HERE → start
- DONE / FINISHED / COMPLETE / READY → done
- ISSUE / PROBLEM / BROKEN → issue (capture rest of message as issue text)
- NOTE → note (capture rest of message as cleaner notes)

**WhatsApp Business API notes:**
- Use Twilio WhatsApp API.
- All outbound messages must use pre-approved message templates (submit for approval during setup).
- Once the cleaner replies, a 24-hour conversation window opens for free-form messaging.
- Store WhatsApp conversation state per cleaner per task in whatsapp_sessions table to track context.

### 7. Notifications to Host

**Email notifications for:**
- Task completed (cleaner replied DONE)
- Issue reported (cleaner replied ISSUE)
- Cleaner declined a task
- Same-day turnover warning (< 3 hour window)
- Non-response escalation (no response after 4 hours)

**In-app notifications:**
- Real-time status updates on the dashboard via Supabase Realtime subscriptions.
- Notification badge/counter showing unread events.

**No push notifications in MVP.** Email + in-app is sufficient.

---

## What Is Explicitly Out of Scope for MVP

- Native mobile apps (iOS/Android)
- Cleaner payments / invoicing
- Cleaner marketplace (finding new cleaners)
- Inventory / supply tracking
- Analytics / reporting / dashboards
- Owner portal (for property owners who use a PM)
- Multiple user roles / team management
- Smart lock integrations
- IoT sensor integrations
- PMS API integrations (Guesty, Hostaway, etc.)
- AI scheduling / route optimization
- Multi-language support (English only in MVP)
- Cleaner performance metrics
- Photo verification of completed cleans (only issue photos in MVP)
- Recurring maintenance scheduling
- Direct booking website
- Guest messaging

---

## Non-Functional Requirements

- **Performance:** Dashboard loads in < 2 seconds. iCal polling completes within 30 seconds per feed.
- **Reliability:** WhatsApp messages must be delivered. Implement retry logic (3 attempts, exponential backoff). Log all failed deliveries.
- **Security:** All data encrypted in transit (HTTPS). Door codes and WiFi passwords encrypted at rest. Supabase RLS policies to ensure hosts only see their own data.
- **Scalability:** Architecture should support 500 properties without changes. No premature optimization beyond that.
- **Uptime:** No formal SLA in MVP, but target 99% availability via Cloudflare/Supabase managed infrastructure.

---

## Success Criteria

The MVP is validated when:

1. 5 hosts have onboarded at least 2 properties each.
2. Cleaners complete tasks via WhatsApp without needing additional explanation.
3. Hosts report they no longer need to message cleaners via personal WhatsApp for routine turnovers.
4. Zero missed cleans due to system failure over a 30-day period.

**The single metric that matters:** Do hosts stop texting their cleaners on WhatsApp for routine turnovers?

---

## Phase 2 — After 50 Properties (Estimated: Month 2–3)

**Photo verification:** Cleaner sends photos during/after clean via WhatsApp. System attaches to task. Host can review on dashboard.

**Backup cleaner logic:** If default cleaner declines or doesn't respond within 60 minutes, system auto-sends the task to a backup cleaner (configurable per property).

**Cleaner payments:** Track what's owed per cleaner per month. Host sets rate per clean per property. System generates monthly summary. Integration with Stripe for direct payouts (Stripe Connect).

**Basic analytics:** Cleans per property per month, average turnaround time, cleaner response time, decline rate.

**Multi-language WhatsApp messages:** Finnish, Estonian, English. Cleaner language preference stored in cleaner profile.

## Phase 3 — After 200 Properties (Estimated: Month 4–6)

**PMS integrations:** Guesty, Hostaway, Lodgify APIs for real-time booking sync (replaces iCal for hosts using a PMS).

**Inventory tracking:** Per-property supply list. Cleaner reports low stock via WhatsApp ("LOW shampoo" or similar keyword). Host sees alerts on dashboard.

**Cleaner marketplace:** Cleaners can create profiles. Hosts can browse available cleaners in their area. Two-sided network effect begins.

**Owner portal:** Read-only view for property owners who use a PM. See task history, costs, maintenance log for their property.

**Smart lock integration:** Nuki, Yale, igloohome APIs. Auto-generate temporary access codes for cleaners, auto-revoke after task completion.

## Phase 4 — After 500 Properties (Estimated: Month 6–12)

**AI scheduling:** Optimize cleaner routes across multiple properties based on geography and time windows. Predict cleaning duration based on property size and guest count.

**Maintenance workflows:** Full ticketing system for non-cleaning tasks. Tradesperson directory. Recurring maintenance rules.

**Multi-market expansion tools:** Multi-currency support. Market-specific regulatory checklists. Localized onboarding.

**API / white-label:** Allow PMS platforms to embed the ops layer. Partner revenue share model.

**Mobile app for hosts:** Native iOS/Android for hosts who want push notifications and on-the-go management.

---

## Development Timeline Estimate

| Phase | Scope | Duration |
|---|---|---|
| Week 1 | Monorepo setup with Wrangler, Supabase setup, data model, auth, install and configure @hono/zod-openapi, define base Zod schemas for all core data model types, property CRUD, iCal parser | 5 days |
| Week 2 | Task auto-creation engine, host dashboard (task list, filters, detail view), manual task creation | 5 days |
| Week 3 | WhatsApp Business API integration, message templates, inbound message parser, cleaner management | 5 days |
| Week 4 | Notifications, non-response escalation, edge case handling, testing with real iCal feeds, bug fixes, deploy | 5 days |

**Total: 4 weeks to live product with real hosts and real cleaners.**
