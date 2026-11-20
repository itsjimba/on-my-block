import { createClient } from "npm:@supabase/supabase-js@2";

const baseCorsHeaders = {
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("origin");
  const allowed = (Deno.env.get("APP_ORIGINS") ?? "").split(",").map(value => value.trim()).filter(Boolean);
  return origin && allowed.includes(origin) ? { ...baseCorsHeaders, "Access-Control-Allow-Origin": origin, Vary: "Origin" } : { ...baseCorsHeaders };
}

function respond(body: Record<string, unknown>, status: number, request: Request): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders(request), "Content-Type": "application/json" } });
}

function selfHostedKey(name: "SUPABASE_SECRET_KEYS" | "SUPABASE_PUBLISHABLE_KEYS"): string {
  try {
    const values = JSON.parse(Deno.env.get(name) ?? "{}");
    return typeof values.default === "string" ? values.default : "";
  } catch {
    return "";
  }
}

Deno.serve(async request => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(request) });
  if (request.method !== "POST") return respond({ error: "Method not allowed." }, 405, request);

  let payload: Record<string, unknown>;
  try {
    const raw = await request.text();
    if (raw.length > 4096) return respond({ error: "Signup request is too large." }, 413, request);
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") throw new Error("invalid");
    payload = parsed as Record<string, unknown>;
  } catch {
    return respond({ error: "Invalid signup request." }, 400, request);
  }

  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
  const password = typeof payload.password === "string" ? payload.password : "";
  const displayName = typeof payload.displayName === "string" ? payload.displayName.trim() : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 8 || password.length > 128 || displayName.length < 1 || displayName.length > 40) {
    return respond({ error: "Enter a valid email, an 8–128 character password, and a name." }, 400, request);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || selfHostedKey("SUPABASE_SECRET_KEYS");
  if (!supabaseUrl || !serviceRoleKey) return respond({ error: "Signup is not configured on the server." }, 500, request);

  const adminClient = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data, error } = await adminClient.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { display_name: displayName } });
  if (error) {
    if (error.message.toLowerCase().includes("already") || error.status === 422) return respond({ error: "An account with that email already exists." }, 409, request);
    console.error("Account creation failed:", error.message);
    return respond({ error: "Could not create your account right now." }, 500, request);
  }
  return respond({ userId: data.user?.id }, 201, request);
});
