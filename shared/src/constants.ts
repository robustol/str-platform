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
