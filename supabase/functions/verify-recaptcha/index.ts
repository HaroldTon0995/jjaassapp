// Supabase Edge Function: verify-recaptcha
// Holds RECAPTCHA_SECRET_KEY securely in Supabase Secrets.
// Verifies Google reCAPTCHA v2 tokens before login.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const secretKey = Deno.env.get("RECAPTCHA_SECRET_KEY") ?? "";
    if (!secretKey) {
      return jsonResponse(
        { success: false, error: "RECAPTCHA_SECRET_KEY secret is not configured" },
        500,
      );
    }

    const payload = await req.json();
    const token = String(payload?.token ?? "").trim();
    if (!token) {
      return jsonResponse(
        { success: false, error: "Missing reCAPTCHA token" },
        400,
      );
    }

    const formBody = new URLSearchParams({
      secret: secretKey,
      response: token,
    });

    const verifyRes = await fetch(
      "https://www.google.com/recaptcha/api/siteverify",
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: formBody.toString(),
      },
    );

    if (!verifyRes.ok) {
      return jsonResponse(
        { success: false, error: "Failed to reach Google reCAPTCHA service" },
        502,
      );
    }

    const result = await verifyRes.json();
    if (result?.success === true) {
      return jsonResponse({ success: true });
    }

    return jsonResponse(
      {
        success: false,
        error: "reCAPTCHA verification failed",
        codes: result?.["error-codes"] ?? [],
      },
      400,
    );
  } catch (err) {
    return jsonResponse({ success: false, error: String(err) }, 500);
  }
});
