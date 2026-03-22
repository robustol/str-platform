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
