import { Hono } from "hono";
import type { AppEnv } from "@str/shared";
import { healthRoute } from "./routes/health.js";

export function createApp() {
  const app = new Hono<AppEnv>();

  app.route("/", healthRoute);

  return app;
}
