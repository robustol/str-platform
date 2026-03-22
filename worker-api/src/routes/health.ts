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
