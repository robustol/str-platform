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
