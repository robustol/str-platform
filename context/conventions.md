# Coding Conventions — STR Platform

**Last updated:** 2026-03-22

## File Naming

- **Files:** `kebab-case.ts`
- **React Components:** `PascalCase.tsx`
- **Tests:** `kebab-case.test.ts` (same name as file being tested)
- **Folders:** `kebab-case/`

Examples:
- `worker-api/src/routes/tasks.ts`
- `frontend/src/components/TaskCard.tsx`
- `worker-jobs/src/lib/ical-parser.test.ts`

## TypeScript Rules

### Strict Mode
- `strict: true` in all `tsconfig.json` files
- No `any` types — use `unknown` if type is truly unknown
- All functions must have explicit return types
- All environment variables must be typed via Hono `Env` type bindings

### Type Imports
```typescript
import type { Task, Property } from "../types/index.js";
```
Use `type` imports where possible to reduce bundle size.

### Response Typing
All API responses must use Zod schemas:
```typescript
const TaskResponseSchema = z.object({
  id: z.string().uuid(),
  status: z.enum(["pending", "sent", "accepted"]),
});

type TaskResponse = z.infer<typeof TaskResponseSchema>;
```

## Code Style

### Naming Conventions
- **Functions:** `camelCase`
- **Components:** `PascalCase`
- **Constants:** `SCREAMING_SNAKE_CASE`
- **Private functions:** prefix with `_` (e.g., `_parseDate`)

### File Length
- Maximum 200 lines per file
- If longer, split into multiple files
- Extract reusable logic into `/lib` or `/utils`

### Imports
```typescript
// External dependencies first
import { Hono } from "hono";
import { z } from "zod";

// Internal imports second
import type { Task } from "../types/index.js";
import { createTask } from "../lib/tasks.js";

// Environment/config last
import type { Env } from "./env.js";
```

### No Commented Code
- Never commit commented-out code
- Use git history for old code
- Add TODO comments only if linked to a GitHub issue

## Error Handling

### All Async Functions Must Have Try/Catch
```typescript
async function fetchTasks(userId: string): Promise<Task[]> {
  try {
    const tasks = await db.query.tasks.findMany({
      where: eq(tasks.user_id, userId),
    });
    return tasks;
  } catch (error) {
    console.error("Failed to fetch tasks:", error);
    throw new Error("Database query failed");
  }
}
```

### Never Return Raw Errors to Clients
```typescript
// ❌ BAD
app.get("/tasks", async (c) => {
  try {
    const tasks = await fetchTasks(c.get("userId"));
    return c.json(tasks);
  } catch (error) {
    return c.json({ error: error.message }, 500);
  }
});

// ✅ GOOD
app.get("/tasks", async (c) => {
  try {
    const tasks = await fetchTasks(c.get("userId"));
    return c.json(tasks);
  } catch (error) {
    console.error("Error fetching tasks:", error);
    return c.json({ error: "Failed to fetch tasks" }, 500);
  }
});
```

### Supabase Error Handling
Always check for Supabase errors explicitly:
```typescript
const { data, error } = await supabase.from("tasks").select("*");
if (error) {
  console.error("Supabase error:", error);
  throw new Error("Failed to fetch tasks from database");
}
return data;
```

### iCal Polling Errors
Never crash the worker on iCal errors:
```typescript
for (const property of properties) {
  try {
    await pollIcalFeed(property.ical_url);
  } catch (error) {
    console.error(`iCal polling failed for property ${property.id}:`, error);
    // Continue to next property — don't crash the job
  }
}
```

## WhatsApp Message Handling

### Webhook Response Time
Twilio webhooks must respond within 5 seconds:
```typescript
app.post("/webhook/whatsapp", async (c) => {
  const body = await c.req.json();

  // Respond immediately
  c.executionCtx.waitUntil(
    processWhatsAppMessage(body) // Process async after response
  );

  return c.text("OK", 200);
});
```

### Keyword Parsing
Case-insensitive, trim whitespace:
```typescript
const message = body.Body.trim().toUpperCase();

if (message === "ACCEPT" || message === "OK" || message === "YES") {
  await acceptTask(taskId);
}
```

### Webhook Signature Verification
Always verify Twilio signatures before processing:
```typescript
import { validateRequest } from "twilio";

const isValid = validateRequest(
  c.env.TWILIO_AUTH_TOKEN,
  twilioSignature,
  url,
  params
);

if (!isValid) {
  return c.text("Unauthorized", 401);
}
```

### Message Sending
Never send outbound messages synchronously inside webhook handler:
```typescript
// ❌ BAD
app.post("/webhook/whatsapp", async (c) => {
  await sendWhatsAppMessage(phoneNumber, "Task accepted");
  return c.text("OK", 200);
});

// ✅ GOOD
app.post("/webhook/whatsapp", async (c) => {
  c.executionCtx.waitUntil(
    sendWhatsAppMessage(phoneNumber, "Task accepted")
  );
  return c.text("OK", 200);
});
```

## Cloudflare Worker-Specific Rules

### No Node.js Built-ins
```typescript
// ❌ BAD
import fs from "fs";
import path from "path";
import crypto from "crypto";

// ✅ GOOD
// Use Web APIs instead
const hash = await crypto.subtle.digest("SHA-256", data);
```

### No process.env
```typescript
// ❌ BAD
const apiKey = process.env.TWILIO_API_KEY;

// ✅ GOOD
app.get("/tasks", async (c) => {
  const apiKey = c.env.TWILIO_API_KEY;
});
```

### No Module-Level State
```typescript
// ❌ BAD
let requestCount = 0; // Shared across requests in same isolate

app.get("/", (c) => {
  requestCount++;
  return c.text(`Request ${requestCount}`);
});

// ✅ GOOD
// Store state in database or pass via context
app.get("/", async (c) => {
  const count = await db.query.requests.count();
  return c.text(`Request ${count}`);
});
```

### Explicit Timeouts for External Calls
```typescript
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout

try {
  const response = await fetch(url, { signal: controller.signal });
  clearTimeout(timeoutId);
  return response;
} catch (error) {
  if (error.name === "AbortError") {
    throw new Error("Request timed out");
  }
  throw error;
}
```

## Database Conventions

### Drizzle Queries Only
Never use raw SQL strings:
```typescript
// ❌ BAD
const tasks = await db.execute(sql`SELECT * FROM tasks WHERE user_id = ${userId}`);

// ✅ GOOD
import { eq } from "drizzle-orm";
const tasks = await db.query.tasks.findMany({
  where: eq(tasks.user_id, userId),
});
```

### Always Use Authenticated Client
```typescript
// ❌ BAD (admin client bypasses RLS)
const supabase = createClient(url, serviceRoleKey);

// ✅ GOOD (respects RLS)
const supabase = createClient(url, anonKey, {
  global: { headers: { Authorization: `Bearer ${jwt}` } },
});
```

## Testing Conventions

### File Placement
- Tests live next to the file they test
- Use `.test.ts` suffix
- Example: `tasks.ts` → `tasks.test.ts`

### Test Structure
```typescript
import { describe, it, expect } from "vitest";
import { parseIcalFeed } from "./ical-parser.js";

describe("parseIcalFeed", () => {
  it("parses valid iCal feed", () => {
    const ical = `BEGIN:VCALENDAR...`;
    const result = parseIcalFeed(ical);
    expect(result).toHaveLength(1);
    expect(result[0].summary).toBe("Booking");
  });

  it("throws on invalid iCal format", () => {
    expect(() => parseIcalFeed("invalid")).toThrow();
  });
});
```

### Test Coverage
- All business logic must have tests
- Route handlers do not need tests (test via integration tests instead)
- Edge cases must be tested explicitly

## Git Commit Conventions

### Commit Message Format
```
type: Short summary (50 chars max)

Longer description if needed. Explain why, not what.
```

### Types
- `feat:` — New feature
- `fix:` — Bug fix
- `refactor:` — Code restructuring without behavior change
- `test:` — Add or update tests
- `docs:` — Documentation only
- `chore:` — Tooling, dependencies, config

### Examples
```
feat: Add WhatsApp ACCEPT keyword handler

Parses ACCEPT, OK, YES variations and updates task status to accepted.
Sends confirmation message to cleaner via Twilio.

fix: Handle same-day turnovers with < 3 hour gap

Now flags on dashboard with warning badge when time_window < 3 hours.
```

## Code Review Checklist

Before submitting code for review:
- [ ] TypeScript compiles with no errors
- [ ] All tests pass (`vitest run`)
- [ ] No `any` types used
- [ ] All async functions have try/catch
- [ ] No raw error messages returned to clients
- [ ] All Supabase queries use authenticated client
- [ ] Twilio webhooks respond within 5 seconds
- [ ] No Node.js built-ins used in Workers
- [ ] No commented-out code
- [ ] File length < 200 lines
