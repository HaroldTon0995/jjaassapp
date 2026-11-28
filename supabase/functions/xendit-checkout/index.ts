// Supabase Edge Function: xendit-checkout
// Holds XENDIT_SECRET_KEY securely in Supabase Secrets.
// Uses Xendit E-Wallets API (PH_GCASH) directly, with Xendit Invoices API (GCASH) as fallback.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

function getAuthHeader(secretKey: string): string {
  return "Basic " + btoa(`${secretKey}:`);
}

serve(async (req: Request) => {
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

    const secretKey = Deno.env.get("XENDIT_SECRET_KEY") ?? "";
    if (!secretKey) {
      return jsonResponse({ error: "XENDIT_SECRET_KEY secret is not configured" }, 500);
    }

    const payload = await req.json();
    const action = String(payload.action ?? "");

    if (action === "initiate") {
      const orderId = String(payload.orderId ?? "");
      const amount = Number(payload.amount ?? 0);
      const role = String(payload.role ?? "customer");
      const successUrl = String(payload.successUrl ?? "");
      const cancelUrl = String(payload.cancelUrl ?? "");

      if (!orderId || amount <= 0) {
        return jsonResponse({ error: "Invalid orderId or amount" }, 400);
      }

      const phpAmount = Number(amount.toFixed(2));

      // 1. Primary: Xendit E-Wallets Charges API (PH_GCASH)
      try {
        const ewalletRes = await fetch("https://api.xendit.co/ewallets/charges", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: getAuthHeader(secretKey),
          },
          body: JSON.stringify({
            reference_id: `${orderId}_${Date.now()}`,
            currency: "PHP",
            amount: phpAmount,
            checkout_method: "ONE_TIME_PAYMENT",
            channel_code: "PH_GCASH",
            channel_properties: {
              success_redirect_url: successUrl,
              failure_redirect_url: cancelUrl,
            },
            metadata: {
              order_id: orderId,
              role,
            },
          }),
        });

        if (ewalletRes.ok) {
          const ewJson = await ewalletRes.json();
          const chargeId = String(ewJson?.id ?? "");
          const actions = (ewJson?.actions ?? {}) as Record<string, unknown>;
          const checkoutUrl = String(
            actions.mobile_web_checkout_url ??
              actions.desktop_web_checkout_url ??
              actions.mobile_deeplink_checkout_url ??
              ""
          );
          const status = String(ewJson?.status ?? "PENDING");
          if (chargeId && checkoutUrl) {
            return jsonResponse({
              order_id: orderId,
              payment_intent_id: `ewc:${chargeId}`,
              redirect_url: checkoutUrl,
              status,
            });
          }
        }
      } catch (_) {
        // Fall through to Xendit Invoices API
      }

      // 2. Fallback: Xendit Invoices API (GCASH)
      const invRes = await fetch("https://api.xendit.co/v2/invoices", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: getAuthHeader(secretKey),
        },
        body: JSON.stringify({
          external_id: `${orderId}_${Date.now()}`,
          amount: phpAmount,
          currency: "PHP",
          description: `JJAASS Water Order #${orderId}`,
          payment_methods: ["GCASH"],
          success_redirect_url: successUrl,
          failure_redirect_url: cancelUrl,
          metadata: {
            order_id: orderId,
            role,
          },
        }),
      });

      if (invRes.ok) {
        const invJson = await invRes.json();
        const invoiceId = String(invJson?.id ?? "");
        const invoiceUrl = String(invJson?.invoice_url ?? "");
        const status = String(invJson?.status ?? "PENDING");
        if (invoiceId && invoiceUrl) {
          return jsonResponse({
            order_id: orderId,
            payment_intent_id: `inv:${invoiceId}`,
            redirect_url: invoiceUrl,
            status,
          });
        }
      }

      return jsonResponse({ error: "Xendit GCash session creation failed" }, 502);
    }

    if (action === "check_status") {
      const identifier = String(payload.identifier ?? "");
      if (!identifier) {
        return jsonResponse({ paid: false });
      }

      if (identifier.startsWith("ewc:")) {
        const chargeId = identifier.slice(4);
        const res = await fetch(
          `https://api.xendit.co/ewallets/charges/${encodeURIComponent(chargeId)}`,
          {
            headers: {
              Authorization: getAuthHeader(secretKey),
            },
          }
        );
        if (res.ok) {
          const json = await res.json();
          const paid = String(json?.status ?? "").toUpperCase() === "SUCCEEDED";
          return jsonResponse({ paid });
        }
        return jsonResponse({ paid: false });
      }

      if (identifier.startsWith("inv:")) {
        const invoiceId = identifier.slice(4);
        const res = await fetch(
          `https://api.xendit.co/v2/invoices/${encodeURIComponent(invoiceId)}`,
          {
            headers: {
              Authorization: getAuthHeader(secretKey),
            },
          }
        );
        if (res.ok) {
          const json = await res.json();
          const status = String(json?.status ?? "").toUpperCase();
          const paid = status === "PAID" || status === "SETTLED";
          return jsonResponse({ paid });
        }
        return jsonResponse({ paid: false });
      }

      return jsonResponse({ paid: false });
    }

    return jsonResponse({ error: "Unknown action" }, 400);
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});
