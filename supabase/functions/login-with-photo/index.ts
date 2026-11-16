import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const baseCorsHeaders = {
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("origin");
  const allowedOrigins = (Deno.env.get("APP_ORIGINS") ?? "").split(",").map(value => value.trim()).filter(Boolean);
  return origin && allowedOrigins.includes(origin)
    ? { ...baseCorsHeaders, "Access-Control-Allow-Origin": origin, Vary: "Origin" }
    : { ...baseCorsHeaders };
}

function respond(body: Record<string, unknown>, status: number, request: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(request) });
  }
  if (request.method !== "POST") {
    return respond({ error: "Method not allowed." }, 405, request);
  }

  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > 4096) {
    return respond({ error: "Invalid login request." }, 413, request);
  }

  let payload: unknown;
  try {
    const body = await request.text();
    if (body.length > 4096) {
      return respond({ error: "Invalid login request." }, 413, request);
    }
    payload = JSON.parse(body);
  } catch {
    return respond({ error: "Invalid login request." }, 400, request);
  }

  if (!payload || typeof payload !== "object") {
    return respond({ error: "Invalid login request." }, 400, request);
  }

  const { profileId, password } = payload as Record<string, unknown>;
  if (
    typeof profileId !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(profileId) ||
    typeof password !== "string" ||
    password.length === 0 ||
    password.length > 1024
  ) {
    return respond({ error: "Invalid photo or password." }, 400, request);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Photo login requires SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY.");
    return respond({ error: "Photo login is not configured on the server." }, 500, request);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const { data: userData, error: lookupError } = await adminClient.auth.admin.getUserById(profileId);
    if (lookupError) {
      console.error("Photo login account lookup failed:", lookupError.message);
      return respond({ error: "Could not verify this login right now." }, 500, request);
    }
    if (!userData.user?.email) {
      return respond({ error: "Invalid photo or password." }, 401, request);
    }

    const { data: allowed, error: limitError } = await adminClient.rpc("allow_photo_login_attempt", {
      p_profile_id: profileId,
    });
    if (limitError) {
      console.error("Photo login rate limit check failed:", limitError.message);
      return respond({ error: "Could not verify this login right now." }, 500, request);
    }
    if (allowed !== true) {
      return respond({ error: "Too many login attempts. Please try again in 15 minutes." }, 429, request);
    }

    const { data: signInData, error: signInError } = await authClient.auth.signInWithPassword({
      email: userData.user.email,
      password,
    });
    if (signInError || !signInData.session) {
      return respond({ error: "Invalid photo or password, or the account has not been verified." }, 401, request);
    }

    const { error: resetError } = await adminClient.rpc("reset_photo_login_attempts", {
      p_profile_id: profileId,
    });
    if (resetError) {
      console.error("Photo login attempt reset failed:", resetError.message);
      return respond({ error: "Could not complete this login right now." }, 500, request);
    }

    return respond({
      access_token: signInData.session.access_token,
      refresh_token: signInData.session.refresh_token,
    }, 200, request);
  } catch (error) {
    console.error("Photo login failed unexpectedly:", error);
    return respond({ error: "Could not verify this login right now." }, 500, request);
  }
});
