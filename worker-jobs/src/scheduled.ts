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
