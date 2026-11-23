// Supabase Edge Function: aquabot-chat
// Proxies Gemini API calls using server-side GEMINI_API_KEY secret.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GEMINI_MODELS = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"];

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const geminiApiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
    if (!geminiApiKey) {
      return jsonResponse({ error: "GEMINI_API_KEY secret is not configured" }, 503);
    }

    const payload = await req.json();
    const systemInstruction = String(payload.systemInstruction ?? "");
    const contents = payload.contents ?? [];

    for (const model of GEMINI_MODELS) {
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(
          geminiApiKey
        )}`;
        const res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            system_instruction: { parts: [{ text: systemInstruction }] },
            contents,
            generationConfig: {
              temperature: 0.35,
              maxOutputTokens: 700,
            },
          }),
        });

        if (res.ok) {
          const data = await res.json();
          const text =
            data?.candidates?.[0]?.content?.[0]?.text ??
            data?.candidates?.[0]?.content?.parts?.[0]?.text ??
            "";
          const reply = String(text).trim();
          if (reply) {
            return jsonResponse({ reply, model });
          }
        }
      } catch (_) {
        // Try next fallback model
      }
    }

    return jsonResponse({ error: "All Gemini models failed" }, 502);
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});
