// Ambient TypeScript declarations for Supabase Edge Functions (Deno runtime)
// so IDE TypeScript diagnostics resolve Deno globals and URL imports cleanly.

declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
  };
}

declare module "https://deno.land/std@0.168.0/http/server.ts" {
  export function serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
}

declare module "https://esm.sh/@supabase/supabase-js@2" {
  export interface SupabaseClient {
    auth: {
      getUser(): Promise<{
        data: { user: { id: string; email?: string } | null };
        error: unknown;
      }>;
    };
  }

  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: Record<string, unknown>,
  ): SupabaseClient;
}
