import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return reply(405, { error: "Method not allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return reply(503, {
      error: "Server-side Supabase environment is incomplete",
    });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return reply(401, { error: "Authentication required" });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return reply(401, { error: "Authentication required" });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const [ownerResult, profileResult] = await Promise.all([
    admin.from("app_owner").select("owner_user_id").eq("singleton", true)
      .maybeSingle(),
    admin.from("profiles").select("role,active").eq("id", user.id)
      .maybeSingle(),
  ]);
  if (ownerResult.error || profileResult.error) {
    return reply(503, { error: "Unable to verify account-management access" });
  }
  if (
    ownerResult.data?.owner_user_id !== user.id ||
    profileResult.data?.role !== "manager" ||
    profileResult.data?.active !== true
  ) {
    return reply(403, { error: "Application owner access required" });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return reply(400, { error: "Invalid request body" });
  }
  const email = typeof body === "object" && body !== null && "email" in body &&
      typeof body.email === "string"
    ? body.email.trim().toLowerCase()
    : "";
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return reply(400, { error: "A valid email address is required" });
  }

  const { error: inviteError } = await admin.auth.admin.inviteUserByEmail(
    email,
  );
  if (inviteError) {
    return reply(400, {
      error:
        "Unable to send invite; check the email and Supabase email settings",
    });
  }
  return reply(200, { invited: true });
});
