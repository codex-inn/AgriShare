import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

async function hashIp(ip: string): Promise<string> {
  const bytes = new TextEncoder().encode(ip || "unknown");
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return response(405, { error: "Method not allowed." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    console.error("Username signup function is missing its server-side Supabase configuration.");
    return response(500, { error: "Account creation is not configured yet. Please contact the project administrator." });
  }

  let body: { username?: unknown; password?: unknown };
  try {
    body = await req.json();
  } catch {
    return response(400, { error: "Invalid request." });
  }

  const username = typeof body.username === "string" ? body.username.trim().toLowerCase() : "";
  const password = typeof body.password === "string" ? body.password : "";
  if (!/^[a-z0-9._-]{3,24}$/.test(username)) {
    return response(400, { error: "Username must be 3–24 characters using letters, numbers, dots, underscores or hyphens." });
  }
  if (password.length < 8 || password.length > 128) {
    return response(400, { error: "Password must be between 8 and 128 characters." });
  }

  const forwarded = req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-real-ip") ||
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unknown";
  const ipHash = await hashIp(forwarded);
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const [ipAttempts, usernameAttempts] = await Promise.all([
    admin.from("username_signup_attempts").select("id", { count: "exact", head: true })
      .eq("ip_hash", ipHash).gte("created_at", since),
    admin.from("username_signup_attempts").select("id", { count: "exact", head: true })
      .eq("username", username).gte("created_at", since),
  ]);
  if (ipAttempts.error || usernameAttempts.error) {
    console.error("Signup rate-limit table is missing or unavailable.");
    return response(503, { error: "Account creation is not configured yet. The administrator must apply the username-auth SQL setup." });
  }
  if ((ipAttempts.count ?? 0) >= 8 || (usernameAttempts.count ?? 0) >= 3) {
    return response(429, { error: "Too many account creation attempts. Please wait an hour before trying again." });
  }

  const { error: logError } = await admin.from("username_signup_attempts").insert({
    username,
    ip_hash: ipHash,
  });
  if (logError) {
    console.error("Could not record signup attempt.");
    return response(503, { error: "Account creation is temporarily unavailable. Please try again later." });
  }

  const syntheticEmail = `${username}@agrishare.local`;
  const { data, error } = await admin.auth.admin.createUser({
    email: syntheticEmail,
    password,
    email_confirm: true,
    user_metadata: { username, auth_method: "username_password" },
  });
  if (error || !data.user) {
    if (error && /already|registered|exists/i.test(error.message)) {
      return response(409, { error: "That username is already registered. Sign in with it, or choose another username." });
    }
    console.error("Supabase could not create the username account.");
    return response(400, { error: "Could not create this account. Check the username and try again." });
  }

  return response(201, { ok: true, username: data.user.user_metadata?.username ?? username });
});
