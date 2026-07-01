// demo-session — mints a short-lived magiclink OTP for the pre-seeded
// App Store reviewer demo account.
//
// SECURITY INVARIANT
//   The target account is read ONLY from DEMO_REVIEW_EMAIL. The caller can
//   submit a code, never an email, so this function cannot mint a session for
//   an arbitrary user.
//
// DEPLOY: supabase functions deploy demo-session --no-verify-jwt
//   Secrets required:
//     supabase secrets set DEMO_REVIEW_CODE=... DEMO_REVIEW_EMAIL=...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const expectedCode = Deno.env.get("DEMO_REVIEW_CODE");
    const demoEmail = Deno.env.get("DEMO_REVIEW_EMAIL");
    if (!supabaseUrl || !serviceRoleKey || !expectedCode || !demoEmail) {
      console.error("[demo-session] missing function env config");
      return jsonResponse({ error: "server_misconfigured" }, 500);
    }

    const body = await readJsonBody(req);
    const code = typeof body?.code === "string" ? body.code : "";
    if (!code || code !== expectedCode) {
      return jsonResponse({ error: "invalid_code" }, 401);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data, error } = await supabaseAdmin.auth.admin.generateLink({
      type: "magiclink",
      email: demoEmail,
    });
    if (error) {
      console.error("[demo-session] generateLink failed", error);
      return jsonResponse({ error: "mint_failed" }, 500);
    }

    const otp = data?.properties?.email_otp;
    if (!otp) {
      console.error("[demo-session] generateLink returned no email_otp");
      return jsonResponse({ error: "mint_failed" }, 500);
    }

    return jsonResponse({ email: demoEmail, otp }, 200);
  } catch (e) {
    console.error("[demo-session] unexpected error", e);
    return jsonResponse({ error: "unexpected" }, 500);
  }
});

async function readJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    if (body && typeof body === "object") {
      return body as Record<string, unknown>;
    }
    return {};
  } catch (_) {
    return {};
  }
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
