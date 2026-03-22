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
