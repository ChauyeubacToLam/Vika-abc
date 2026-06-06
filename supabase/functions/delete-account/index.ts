// delete-account — permanently deletes the authenticated caller's account.
//
// SECURITY INVARIANT
//   The user id is derived ONLY from the verified JWT in the Authorization
//   header — never from the request body. This function can therefore delete
//   the caller's own account and nothing else. Get this wrong and any user
//   could delete any account.
//
// WHAT IT DELETES
//   1. The caller's avatar object(s) in the `avatars` storage bucket.
//      UserProfileService.saveCurrentProfile uploads to
//      `<userId>/avatar_<millis>.<ext>`, so we list everything under the
//      user's `<userId>/` folder and remove it.
//   2. The auth.users row via auth.admin.deleteUser(userId). The already-
//      applied FK-cascade migration deletes the rest of the user subtree
//      (profiles, workout_sessions, exercise_sessions, …) automatically.
//
// Returns { ok: true } on success, or { error: <code> } with a non-2xx status.
//
// DEPLOY (Nam): supabase functions deploy delete-account
//   This does NOT auto-deploy. SUPABASE_SERVICE_ROLE_KEY is read from the
//   function environment and is never shipped to the client.
//
// TODO(siwa): when Sign in with Apple ships, revoke the Apple refresh token
// via Apple's REST revoke endpoint here. Apple requires token revocation on
// account deletion (App Store Guideline 5.1.1(v)).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const AVATAR_BUCKET = "avatars";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify the caller's JWT and derive the user id FROM IT.
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return jsonResponse({ error: "missing_authorization" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      console.error("[delete-account] missing function env config");
      return jsonResponse({ error: "server_misconfigured" }, 500);
    }

    // Service-role client — full privileges, lives only inside the function.
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // The user id comes from the verified token, NOT from req.body.
    const { data: userData, error: userError } = await supabaseAdmin.auth
      .getUser(token);
    if (userError || !userData?.user) {
      return jsonResponse({ error: "invalid_token" }, 401);
    }
    const userId = userData.user.id;

    // 1. Remove the caller's avatar object(s). Best-effort: a storage hiccup
    //    must not block the account deletion itself.
    try {
      const { data: objects, error: listError } = await supabaseAdmin.storage
        .from(AVATAR_BUCKET)
        .list(userId, { limit: 1000 });
      if (listError) {
        console.error("[delete-account] avatar list failed", listError);
      } else if (objects && objects.length > 0) {
        const paths = objects.map((o) => `${userId}/${o.name}`);
        const { error: removeError } = await supabaseAdmin.storage
          .from(AVATAR_BUCKET)
          .remove(paths);
        if (removeError) {
          console.error("[delete-account] avatar remove failed", removeError);
        }
      }
    } catch (e) {
      console.error("[delete-account] avatar cleanup threw", e);
    }

    // 2. Delete the auth user — FK cascade handles the rest of the subtree.
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
      userId,
    );
    if (deleteError) {
      console.error("[delete-account] deleteUser failed", deleteError);
      return jsonResponse({ error: "delete_failed" }, 500);
    }

    return jsonResponse({ ok: true }, 200);
  } catch (e) {
    console.error("[delete-account] unexpected error", e);
    return jsonResponse({ error: "unexpected" }, 500);
  }
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
