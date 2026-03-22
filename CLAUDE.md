# STR Platform

Short-term rental operations platform. Automates cleaning task creation from
booking data and dispatches tasks to cleaners via WhatsApp. Host uses a web
dashboard. Cleaners never leave WhatsApp.

## Tech Stack
- Frontend: Vite + React SPA — Cloudflare Pages
- API: Cloudflare Worker (worker-api)
- Background jobs: Cloudflare Worker (worker-jobs)
- Database/auth: Supabase (Postgres, Auth, Realtime)
- Messaging: Twilio WhatsApp Business API
- Email: Resend
- CI/CD: GitHub Actions

## Core loop
Booking syncs → Task auto-created → Cleaner notified on WhatsApp →
Cleaner completes task → Host sees status update

## Markets
Phase 1: Finland, Estonia
Phase 2: SEA (Philippines, Thailand)

## Status
Pre-development. Spec complete at spec.md.

## Session rules
At the end of every Claude Code session:
1. Update context/current-state.md
2. Save session summary to context/sessions/YYYY-MM-DD-[description].md
3. Commit and push
