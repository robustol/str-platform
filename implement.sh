#!/bin/bash
set -e

echo "🚀 Creating STR Platform monorepo scaffold..."
echo ""

# ============================================================================
# ROOT FILES
# ============================================================================

echo "📦 Creating root workspace files..."

cat > pnpm-workspace.yaml << 'EOF'
packages:
  - "frontend"
  - "worker-api"
  - "worker-jobs"
  - "shared"
EOF

cat > .npmrc << 'EOF'
shamefully-hoist=false
strict-peer-dependencies=false
EOF

cat > package.json << 'EOF'
{
  "name": "str-platform",
  "private": true,
  "scripts": {
    "dev:api": "pnpm --filter @str/worker-api dev",
    "dev:jobs": "pnpm --filter @str/worker-jobs dev",
    "dev:frontend": "pnpm --filter @str/frontend dev",
    "build": "pnpm -r build",
    "build:frontend": "pnpm --filter @str/frontend build",
    "test": "pnpm -r test",
    "typecheck": "pnpm -r typecheck",
    "deploy:api": "pnpm --filter @str/worker-api deploy",
    "deploy:jobs": "pnpm --filter @str/worker-jobs deploy",
    "deploy:frontend": "pnpm --filter @str/frontend deploy"
  },
  "engines": {
    "node": ">=20",
    "pnpm": ">=9"
  }
}
EOF

cat > tsconfig.base.json << 'EOF'
{
  "compilerOptions": {
    "strict": true,
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
EOF

cat > .gitignore << 'EOF'
node_modules/
dist/
.wrangler/
.dev.vars
*.local
.DS_Store
EOF

echo "✅ Root files created (5/5)"

# ============================================================================
# SHARED PACKAGE
# ============================================================================

echo "📦 Creating shared/ package..."

mkdir -p shared/src/types

cat > shared/package.json << 'EOF'
{
  "name": "@str/shared",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "exports": {
    ".": "./src/index.ts"
  },
  "scripts": {
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.7.0"
  }
}
EOF

cat > shared/tsconfig.json << 'EOF'
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*.ts"]
}
EOF

cat > shared/src/index.ts << 'EOF'
export * from "./types/env.js";
export * from "./constants.js";
EOF

cat > shared/src/types/env.ts << 'EOF'
/**
 * Cloudflare Worker environment bindings.
 * Shared across worker-api and worker-jobs.
 * Each worker's wrangler.toml must define these.
 */
export interface CloudflareEnv {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  PRICELABS_API_KEY: string;
  ENVIRONMENT: "development" | "staging" | "production";
}

/**
 * Hono app type with Cloudflare bindings.
 * Use this as the generic parameter for OpenAPIHono<AppEnv>.
 */
export type AppEnv = {
  Bindings: CloudflareEnv;
};
EOF

cat > shared/src/constants.ts << 'EOF'
export const APP_NAME = "str-platform";

export const API_VERSION = "v1" as const;

/**
 * Health check response shape — used by both workers.
 */
export const HEALTH_STATUS = {
  OK: "ok",
  DEGRADED: "degraded",
  DOWN: "down",
} as const;
EOF

echo "✅ shared/ created (5/5 files)"

# ============================================================================
# WORKER-API PACKAGE
# ============================================================================

echo "📦 Creating worker-api/ package..."

mkdir -p worker-api/src/routes

cat > worker-api/package.json << 'EOF'
{
  "name": "@str/worker-api",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler dev src/index.ts",
    "build": "wrangler deploy --dry-run --outdir=dist",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@hono/zod-openapi": "^0.18.0",
    "hono": "^4.6.0",
    "@str/shared": "workspace:*"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20241205.0",
    "typescript": "^5.7.0",
    "vitest": "^2.1.0",
    "wrangler": "^3.91.0",
    "zod": "^3.24.0"
  }
}
EOF

cat > worker-api/tsconfig.json << 'EOF'
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "types": ["@cloudflare/workers-types"],
    "jsx": "react-jsx",
    "jsxImportSource": "hono/jsx"
  },
  "include": ["src/**/*.ts"],
  "references": [
    { "path": "../shared" }
  ]
}
EOF

cat > worker-api/wrangler.toml << 'EOF'
name = "str-api"
main = "src/index.ts"
compatibility_date = "2024-12-01"
compatibility_flags = ["nodejs_compat"]

[vars]
ENVIRONMENT = "development"

# Secrets (set via `wrangler secret put`):
# SUPABASE_URL
# SUPABASE_ANON_KEY
# SUPABASE_SERVICE_ROLE_KEY
# PRICELABS_API_KEY
EOF

cat > worker-api/vitest.config.ts << 'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
  },
});
EOF

cat > worker-api/src/app.ts << 'EOF'
import { OpenAPIHono } from "@hono/zod-openapi";
import type { AppEnv } from "@str/shared";
import { healthRoute } from "./routes/health.js";

export function createApp() {
  const app = new OpenAPIHono<AppEnv>();

  // --- Routes ---
  app.route("/", healthRoute);

  // --- OpenAPI JSON spec ---
  app.doc("/doc", {
    openapi: "3.1.0",
    info: {
      title: "STR Platform API",
      version: "0.0.1",
    },
  });

  return app;
}
EOF

cat > worker-api/src/index.ts << 'EOF'
import { createApp } from "./app.js";

const app = createApp();

export default app;
EOF

cat > worker-api/src/routes/health.ts << 'EOF'
import { OpenAPIHono, createRoute, z } from "@hono/zod-openapi";
import type { AppEnv } from "@str/shared";
import { HEALTH_STATUS } from "@str/shared";

const healthResponseSchema = z.object({
  status: z.enum([HEALTH_STATUS.OK, HEALTH_STATUS.DEGRADED, HEALTH_STATUS.DOWN]),
  service: z.string(),
  timestamp: z.string().datetime(),
});

const route = createRoute({
  method: "get",
  path: "/health",
  tags: ["System"],
  summary: "Health check",
  responses: {
    200: {
      content: {
        "application/json": {
          schema: healthResponseSchema,
        },
      },
      description: "Service is healthy",
    },
  },
});

export const healthRoute = new OpenAPIHono<AppEnv>().openapi(route, (c) => {
  return c.json(
    {
      status: HEALTH_STATUS.OK,
      service: "str-api",
      timestamp: new Date().toISOString(),
    },
    200
  );
});
EOF

cat > worker-api/src/routes/health.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { createApp } from "../app.js";

describe("GET /health", () => {
  const app = createApp();

  it("returns 200 with ok status", async () => {
    const res = await app.request("/health");
    expect(res.status).toBe(200);

    const body = (await res.json()) as { status: string; service: string; timestamp: string };
    expect(body.status).toBe("ok");
    expect(body.service).toBe("str-api");
    expect(body.timestamp).toBeDefined();
  });
});

describe("GET /doc", () => {
  const app = createApp();

  it("returns OpenAPI spec", async () => {
    const res = await app.request("/doc");
    expect(res.status).toBe(200);

    const body = (await res.json()) as { openapi: string; paths: Record<string, unknown> };
    expect(body.openapi).toBe("3.1.0");
    expect(body.paths["/health"]).toBeDefined();
  });
});
EOF

echo "✅ worker-api/ created (8/8 files)"

# ============================================================================
# WORKER-JOBS PACKAGE
# ============================================================================

echo "📦 Creating worker-jobs/ package..."

mkdir -p worker-jobs/src/routes

cat > worker-jobs/package.json << 'EOF'
{
  "name": "@str/worker-jobs",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler dev src/index.ts",
    "build": "wrangler deploy --dry-run --outdir=dist",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "hono": "^4.6.0",
    "@str/shared": "workspace:*"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20241205.0",
    "typescript": "^5.7.0",
    "vitest": "^2.1.0",
    "wrangler": "^3.91.0"
  }
}
EOF

cat > worker-jobs/tsconfig.json << 'EOF'
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "types": ["@cloudflare/workers-types"]
  },
  "include": ["src/**/*.ts"],
  "references": [
    { "path": "../shared" }
  ]
}
EOF

cat > worker-jobs/wrangler.toml << 'EOF'
name = "str-jobs"
main = "src/index.ts"
compatibility_date = "2024-12-01"
compatibility_flags = ["nodejs_compat"]

[triggers]
crons = ["*/30 * * * *"]

[vars]
ENVIRONMENT = "development"

# Secrets (set via `wrangler secret put`):
# SUPABASE_URL
# SUPABASE_ANON_KEY
# SUPABASE_SERVICE_ROLE_KEY
# PRICELABS_API_KEY
EOF

cat > worker-jobs/vitest.config.ts << 'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
  },
});
EOF

cat > worker-jobs/src/app.ts << 'EOF'
import { Hono } from "hono";
import type { AppEnv } from "@str/shared";
import { healthRoute } from "./routes/health.js";

export function createApp() {
  const app = new Hono<AppEnv>();

  app.route("/", healthRoute);

  return app;
}
EOF

cat > worker-jobs/src/scheduled.ts << 'EOF'
import type { CloudflareEnv } from "@str/shared";

/**
 * Cloudflare Cron Trigger handler.
 * Dispatches to specific job functions based on cron schedule.
 */
export async function handleScheduled(
  _controller: ScheduledController,
  _env: CloudflareEnv,
  ctx: ExecutionContext
): Promise<void> {
  // Placeholder — actual job dispatch logic comes in future tasks.
  // ctx.waitUntil() ensures the worker stays alive until async work completes.
  ctx.waitUntil(
    Promise.resolve(
      console.log(`[str-jobs] Scheduled event fired at ${new Date().toISOString()}`)
    )
  );
}
EOF

cat > worker-jobs/src/index.ts << 'EOF'
import { createApp } from "./app.js";
import { handleScheduled } from "./scheduled.js";

const app = createApp();

export default {
  fetch: app.fetch,
  scheduled: handleScheduled,
};
EOF

cat > worker-jobs/src/routes/health.ts << 'EOF'
import { Hono } from "hono";
import type { AppEnv } from "@str/shared";
import { HEALTH_STATUS } from "@str/shared";

export const healthRoute = new Hono<AppEnv>().get("/health", (c) => {
  return c.json({
    status: HEALTH_STATUS.OK,
    service: "str-jobs",
    timestamp: new Date().toISOString(),
  });
});
EOF

cat > worker-jobs/src/routes/health.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { createApp } from "../app.js";

describe("GET /health", () => {
  const app = createApp();

  it("returns 200 with ok status", async () => {
    const res = await app.request("/health");
    expect(res.status).toBe(200);

    const body = (await res.json()) as { status: string; service: string; timestamp: string };
    expect(body.status).toBe("ok");
    expect(body.service).toBe("str-jobs");
    expect(body.timestamp).toBeDefined();
  });
});
EOF

echo "✅ worker-jobs/ created (9/9 files)"

# ============================================================================
# FRONTEND PACKAGE
# ============================================================================

echo "📦 Creating frontend/ package..."

mkdir -p frontend/src

cat > frontend/package.json << 'EOF'
{
  "name": "@str/frontend",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "preview": "vite preview",
    "deploy": "pnpm build && wrangler pages deploy dist",
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "@str/shared": "workspace:*"
  },
  "devDependencies": {
    "@testing-library/react": "^16.1.0",
    "@testing-library/jest-dom": "^6.6.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "jsdom": "^25.0.0",
    "typescript": "^5.7.0",
    "vite": "^6.0.0",
    "vitest": "^2.1.0",
    "wrangler": "^3.91.0"
  }
}
EOF

cat > frontend/tsconfig.json << 'EOF'
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "jsx": "react-jsx",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "types": [],
    "declaration": false,
    "declarationMap": false
  },
  "include": ["src/**/*.ts", "src/**/*.tsx"],
  "references": [
    { "path": "./tsconfig.node.json" },
    { "path": "../shared" }
  ]
}
EOF

cat > frontend/tsconfig.node.json << 'EOF'
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "./dist",
    "lib": ["ES2022"],
    "types": ["node"],
    "declaration": false,
    "declarationMap": false
  },
  "include": ["vite.config.ts", "vitest.config.ts"]
}
EOF

cat > frontend/vite.config.ts << 'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "dist",
    sourcemap: true,
  },
});
EOF

cat > frontend/vitest.config.ts << 'EOF'
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/setupTests.ts"],
    css: false,
  },
});
EOF

cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>STR Platform</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

cat > frontend/src/vite-env.d.ts << 'EOF'
/// <reference types="vite/client" />
EOF

cat > frontend/src/setupTests.ts << 'EOF'
import "@testing-library/jest-dom";
EOF

cat > frontend/src/main.tsx << 'EOF'
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App.js";

const rootEl = document.getElementById("root");
if (!rootEl) throw new Error("Root element not found");

createRoot(rootEl).render(
  <StrictMode>
    <App />
  </StrictMode>
);
EOF

cat > frontend/src/App.tsx << 'EOF'
import { APP_NAME } from "@str/shared";

export function App() {
  return (
    <div>
      <h1>STR Platform</h1>
      <p>App: {APP_NAME}</p>
    </div>
  );
}
EOF

cat > frontend/src/App.test.tsx << 'EOF'
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { App } from "./App.js";

describe("App", () => {
  it("renders the heading", () => {
    render(<App />);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "STR Platform"
    );
  });

  it("displays the app name from shared constants", () => {
    render(<App />);
    expect(screen.getByText(/str-platform/i)).toBeDefined();
  });
});
EOF

echo "✅ frontend/ created (10/10 files)"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "✨ All 37 files created successfully!"
echo ""
echo "📊 File count breakdown:"
echo "   • Root: 5 files"
echo "   • shared/: 5 files"
echo "   • worker-api/: 8 files"
echo "   • worker-jobs/: 9 files"
echo "   • frontend/: 10 files"
echo "   ────────────────────"
echo "   Total: 37 files"
echo ""
echo "🔍 Next steps:"
echo "   1. pnpm install       # Install all dependencies"
echo "   2. pnpm typecheck     # Verify TypeScript compiles"
echo "   3. pnpm test          # Run all tests"
echo "   4. pnpm build         # Build all packages"
echo ""
echo "🚀 Development commands:"
echo "   • pnpm dev:api        # Start worker-api dev server"
echo "   • pnpm dev:jobs       # Start worker-jobs dev server"
echo "   • pnpm dev:frontend   # Start frontend dev server"
echo ""
