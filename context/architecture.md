# Architecture — STR Platform

**Last updated:** 2026-03-22

## Tech Stack

### Core Infrastructure
- **Frontend:** Vite + React SPA deployed on Cloudflare Pages
- **Backend API:** Cloudflare Workers with Hono framework
- **Background Jobs:** Cloudflare Workers with Cron Triggers (30min iCal polling)
- **Database:** Supabase (Postgres) via Drizzle ORM
- **Auth:** Supabase Auth (JWT verification in worker-api)
- **API Validation:** Zod via @hono/zod-openapi
- **API Documentation:** OpenAPI auto-generated from Zod schemas

### External Services
- **Messaging:** Twilio WhatsApp Business API
- **Email:** Resend
- **CI/CD:** GitHub Actions

## Monorepo Structure

```
str-platform/
├── frontend/         # Vite + React SPA — Cloudflare Pages
├── worker-api/       # Hono app — REST API + Twilio webhook handler
├── worker-jobs/      # Cloudflare Cron — iCal polling, escalations
└── shared/           # Shared types, utils, constants (referenced by all packages)
```

**No shared database code.** Each worker imports Drizzle schema independently.

## Approved Dependencies

### worker-api / worker-jobs
- `hono` — routing and middleware
- `@hono/zod-openapi` — API validation and OpenAPI generation
- `zod` — schema validation
- `drizzle-orm` — database queries
- `@supabase/supabase-js` — auth and realtime
- `twilio` — WhatsApp messaging (worker-api only)

### frontend
- `react` + `react-dom`
- `@supabase/supabase-js` — auth client
- `react-router-dom` — client-side routing
- `zod` — form validation

**All other dependencies require explicit approval before adding.**

## Cloudflare Worker Constraints

### Environment
- Edge-only runtime (V8 isolates, not Node.js)
- No Node.js built-ins: `fs`, `path`, `crypto` (use Web Crypto API)
- No `require()` — ESM imports only
- No `process.env` — use Hono `env` from context
- Stateless between requests — no module-level state

### Performance
- All external fetch calls must have explicit timeouts
- Twilio webhooks must respond within 5 seconds
- Use `ctx.executionCtx.waitUntil()` for async work after response

## Supabase RLS Requirements

### Policy Design
- Every table must have RLS enabled
- Every query must use the authenticated Supabase client (never admin client in user-facing endpoints)
- Row-level policies enforce `user_id` checks — hosts see only their own data

### Standard Policies Per Table
- `users`: user sees only their own row
- `properties`: user sees only properties where `user_id = auth.uid()`
- `cleaners`: user sees only cleaners where `user_id = auth.uid()`
- `tasks`: user sees only tasks for properties they own
- `bookings`: user sees only bookings for properties they own
- `whatsapp_sessions`: internal table, no direct client access

**Never bypass RLS.** If a query needs admin access, flag it as a security decision.

## Zod and OpenAPI Requirement

### All API Endpoints
- Every endpoint must use `@hono/zod-openapi` route definition (never plain Hono `.get()` or `.post()`)
- All request bodies, query params, and path params must have Zod schemas
- All response shapes must be defined as Zod schemas
- OpenAPI spec auto-generates — no manual documentation needed

### Example Pattern
```typescript
import { createRoute, OpenAPIHono } from "@hono/zod-openapi";
import { z } from "zod";

const app = new OpenAPIHono();

const TaskSchema = z.object({
  id: z.string().uuid(),
  property_id: z.string().uuid(),
  status: z.enum(["pending", "sent", "accepted", "in_progress", "completed"]),
  scheduled_date: z.string().date(),
});

const route = createRoute({
  method: "get",
  path: "/tasks",
  responses: {
    200: {
      content: { "application/json": { schema: z.array(TaskSchema) } },
      description: "List of tasks",
    },
  },
});

app.openapi(route, async (c) => {
  // implementation
});
```

## Data Model (5 Core Tables)

1. **users** — Supabase Auth users (hosts only in MVP)
2. **properties** — Host-owned properties with iCal URLs, checklists, default cleaner
3. **cleaners** — WhatsApp-enabled cleaners (no login, no accounts)
4. **tasks** — Cleaning tasks (auto-created from iCal or manual)
5. **bookings** — Parsed from iCal feeds, used to generate tasks
6. **whatsapp_sessions** — Tracks conversation state per cleaner per task

See `spec.md` for full schema details.

## Key Architectural Decisions

### Why Cloudflare Workers?
- Edge compute = low latency globally
- Native cron support (no third-party scheduler needed)
- Integrated with Pages (frontend) and KV/Durable Objects if needed later
- Cost-effective at scale ($5/month for 10M requests)

### Why Supabase?
- Postgres with RLS = secure multi-tenancy out of the box
- Auth included (no separate service)
- Realtime subscriptions for live dashboard updates
- Generous free tier, scales to 500 properties without cost concerns

### Why Twilio WhatsApp API?
- Simpler setup than Meta Cloud API
- Better documentation and support
- Allows pre-approved message templates (required for business use)

### Why Zod + OpenAPI?
- Single source of truth for API contracts
- Type safety across frontend and backend
- Auto-generated API docs for future integrations
- Catches validation errors before they reach business logic

### Why No Shared Database Code?
- Workers are deployed independently
- Shared code = tighter coupling = slower iteration
- Each worker imports Drizzle schema directly
- Shared types live in `/shared` but no shared query logic

## Security Considerations

- **Door codes and WiFi passwords:** Encrypted at rest in Supabase (use Supabase Vault if available, otherwise encrypt before insert)
- **Twilio webhook verification:** Always verify signatures before processing messages
- **JWT validation:** Every API request validates Supabase JWT, never trust client-provided user IDs
- **RLS policies:** Enforce at database level, not just application level
- **Error messages:** Never expose internal errors to clients (sanitize all error responses)

## Performance Targets

- **Dashboard load:** < 2 seconds
- **iCal polling:** Complete within 30 seconds per feed
- **WhatsApp webhook response:** < 5 seconds (use `waitUntil()` for processing)
- **API response time:** p95 < 500ms

## Scalability Targets

- **MVP:** 50 properties (5 hosts × 10 properties)
- **Phase 2:** 200 properties
- **Phase 3:** 500 properties
- **No premature optimization beyond 500 properties**

## Deployment Strategy

- **Frontend:** Cloudflare Pages (auto-deploy on push to main)
- **worker-api:** Wrangler CLI deploy (GitHub Actions on push to main)
- **worker-jobs:** Wrangler CLI deploy (GitHub Actions on push to main)
- **Database migrations:** Drizzle Kit (manual run, not automated in CI)
- **Environment secrets:** Cloudflare secrets for API keys, Supabase anon key in wrangler.toml

## Future Considerations (Post-MVP)

- **Durable Objects:** If we need stateful WebSocket connections for real-time cleaner tracking
- **Workers KV:** For caching iCal feed responses (reduce polling cost)
- **Cloudflare Images:** For cleaner-uploaded issue photos (currently using Supabase storage)
- **Rate limiting:** Cloudflare Rate Limiting API if we see abuse
