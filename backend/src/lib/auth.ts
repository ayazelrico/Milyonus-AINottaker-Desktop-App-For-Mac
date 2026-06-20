import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import { requiredEnv } from "@/lib/env";

export class AuthError extends Error {
  constructor(message = "Unauthorized") {
    super(message);
    this.name = "AuthError";
  }
}

export type AuthContext = {
  token: string;
  user: User;
  supabase: SupabaseClient;
};

function bearerToken(request: Request): string {
  const header = request.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);

  if (!match?.[1]) {
    throw new AuthError();
  }

  return match[1];
}

function createUserClient(token: string) {
  return createClient(requiredEnv("SUPABASE_URL"), requiredEnv("SUPABASE_ANON_KEY"), {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false
    },
    global: {
      headers: {
        Authorization: `Bearer ${token}`
      }
    }
  });
}

export async function requireUser(request: Request): Promise<AuthContext> {
  const token = bearerToken(request);
  const supabase = createUserClient(token);
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    throw new AuthError();
  }

  return {
    token,
    user: data.user,
    supabase
  };
}

