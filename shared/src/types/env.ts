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
