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
