# STR Platform — Current State

**Last updated:** 2026-03-22

## Project Status

**Phase:** Pre-development
**Timeline:** Week 0 of 4 (5-week plan including Week 1 setup)
**Next Milestone:** Monorepo scaffolding + Supabase setup (Week 1)

## What's Complete

### Phase 0: Specification and Planning ✅
- ✅ Product spec finalized (`spec.md`)
- ✅ Tech stack decisions locked
- ✅ Data model defined (5 core tables + sessions table)
- ✅ MVP scope defined with clear success criteria
- ✅ Out-of-scope features documented for Phase 2+
- ✅ Architecture documentation written (`context/architecture.md`)
- ✅ Coding conventions documented (`context/conventions.md`)
- ✅ Agent skills configured for STR platform:
  - Architect agent (product + tech planning)
  - Developer agent (implementation)
  - PM agent (standup and status tracking)
  - Researcher agent (competitive intel)

### Phase 0: Environment Setup ✅
- ✅ Supabase project created
- ✅ Twilio WhatsApp sandbox configured
- ✅ Cloudflare account ready
- ✅ GitHub repo initialized

## What's Next

### Week 1: Foundation (Target: 5 days)
1. **Monorepo scaffolding**
   - Create frontend/, worker-api/, worker-jobs/, shared/ packages
   - Configure pnpm workspaces
   - Set up Wrangler config for both workers
   - Configure TypeScript strict mode across all packages

2. **Supabase setup**
   - Run database migrations (create all 6 tables)
   - Configure RLS policies for all tables
   - Set up auth (email + password only)
   - Test local development with Supabase CLI

3. **Zod and OpenAPI setup**
   - Install `@hono/zod-openapi` in worker-api
   - Define base Zod schemas for all core data model types (Task, Property, Cleaner, Booking, User, WhatsAppSession)
   - Configure OpenAPI route definitions for all planned endpoints
   - Generate initial OpenAPI spec

4. **Property CRUD**
   - Create property management endpoints in worker-api
   - Build property list and detail views in frontend
   - Implement add/edit/delete property flows

5. **iCal parser**
   - Build VEVENT parser (read DTSTART, DTEND, SUMMARY, UID)
   - Write tests for iCal edge cases (all-day events, timezones, recurring events)
   - Implement booking upsert logic (dedup by ical_uid)

**Acceptance criteria:**
- Host can sign up, log in, add a property
- System can parse an iCal feed and create booking records
- All API endpoints documented via auto-generated OpenAPI spec

### Week 2: Task Engine (Target: 5 days)
- Task auto-creation logic (checkout → next checkin window detection)
- Host dashboard (task list, filters, status badges)
- Manual task creation form
- Task detail view with checklist

### Week 3: WhatsApp Integration (Target: 5 days)
- Twilio message templates (submit for approval)
- Inbound webhook handler (keyword parsing)
- Cleaner management (add/edit/assign to properties)
- Task notification and reminder flows

### Week 4: Polish and Deploy (Target: 5 days)
- Email notifications (Resend integration)
- Non-response escalation logic
- Same-day turnover warnings
- Testing with real iCal feeds from Airbnb/Booking.com
- Bug fixes and edge case handling
- Production deployment

## Known Blockers

**None.** All pre-development setup complete. Ready to start Week 1.

## Technical Decisions Made

### Why Cloudflare Workers?
Edge compute with native cron support, low cost at scale, integrated with Pages.

### Why Supabase?
Postgres with RLS for secure multi-tenancy, auth included, realtime subscriptions for live updates.

### Why Twilio WhatsApp API?
Simpler setup than Meta Cloud API, better docs, allows pre-approved message templates.

### Why @hono/zod-openapi?
Single source of truth for API contracts, type-safe request/response validation, auto-generated docs.

### Why No Shared Database Code?
Workers deploy independently. Tight coupling slows iteration. Each worker imports Drizzle schema directly.

## Repository Structure

```
str-platform/
├── spec.md                    # Product spec (source of truth)
├── context/
│   ├── architecture.md        # Tech stack, monorepo, constraints
│   ├── conventions.md         # Coding standards
│   └── current-state.md       # This file
├── frontend/                  # (Not created yet)
├── worker-api/                # (Not created yet)
├── worker-jobs/               # (Not created yet)
└── shared/                    # (Not created yet)
```

## Success Criteria (Reminder)

The MVP is validated when:
1. **5 hosts** have onboarded at least **2 properties** each
2. **Cleaners complete tasks via WhatsApp** without needing additional explanation
3. **Hosts stop texting their cleaners** via personal WhatsApp for routine turnovers
4. **Zero missed cleans** due to system failure over a 30-day period

**The metric that matters:** Do hosts stop texting their cleaners on WhatsApp for routine turnovers?

## What We're NOT Building in MVP

- Native mobile apps
- Cleaner payments / invoicing
- Cleaner marketplace
- Inventory / supply tracking
- Analytics / dashboards
- Multi-user roles / team management
- Smart lock integrations
- PMS API integrations
- AI scheduling
- Multi-language support (English only)
- Photo verification of completed cleans (only issue photos)

See `spec.md` for full out-of-scope list.

## Open Questions

**None.** All pre-development decisions made. Ready to build.

## Next Action

Start Week 1: Scaffold monorepo, set up Supabase migrations, install @hono/zod-openapi, define core Zod schemas, build property CRUD, implement iCal parser.
