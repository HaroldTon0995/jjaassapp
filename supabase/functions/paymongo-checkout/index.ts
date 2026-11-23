// Supabase Edge Function: paymongo-checkout
// Holds PAYMONGO_SECRET_KEY securely in Supabase Secrets.
// Handles both initiating GCash Checkout/Link sessions and polling payment status.

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify caller has a valid Supabase JWT
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

    const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY") ?? "";
    if (!secretKey) {
      return jsonResponse({ error: "PAYMONGO_SECRET_KEY secret is not configured" }, 500);
    }

    const payload = await req.json();
    const action = payload.action as string;

    if (action === "initiate") {
      const orderId = String(payload.orderId ?? "");
      const amount = Number(payload.amount ?? 0);
      const role = String(payload.role ?? "customer");
      const successUrl = String(payload.successUrl ?? "");
      const cancelUrl = String(payload.cancelUrl ?? "");

      if (!orderId || amount <= 0) {
        return jsonResponse({ error: "Invalid orderId or amount" }, 400);
      }

      const amountInCentavos = Math.round(amount * 100);

      // 1. Try Checkout Sessions API
      const csRes = await fetch("https://api.paymongo.com/v1/checkout_sessions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          Authorization: getAuthHeader(secretKey),
        },
        body: JSON.stringify({
          data: {
            attributes: {
              send_email_receipt: false,
              show_description: true,
              show_line_items: true,
              description: `JJAASS Water Order #${orderId}`,
              line_items: [
                {
                  currency: "PHP",
                  amount: amountInCentavos,
                  name: `JJAASS Water Order #${orderId}`,
                  quantity: 1,
                },
              ],
              payment_method_types: ["gcash"],
              success_url: successUrl,
              cancel_url: cancelUrl,
            },
          },
        }),
      });

      if (csRes.ok) {
        const csJson = await csRes.json();
        const sessionId = csJson?.data?.id ?? "";
        const checkoutUrl = csJson?.data?.attributes?.checkout_url ?? "";
        const status = csJson?.data?.attributes?.status ?? "active";
        if (checkoutUrl) {
          return jsonResponse({
            order_id: orderId,
            payment_intent_id: sessionId,
            redirect_url: checkoutUrl,
            status,
          });
        }
      }

      // 2. Fallback: Payment Links API
      const linkRes = await fetch("https://api.paymongo.com/v1/links", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          Authorization: getAuthHeader(secretKey),
        },
        body: JSON.stringify({
          data: {
            attributes: {
              amount: amountInCentavos,
              description: `JJAASS Water Order #${orderId}`,
              remarks: `Order #${orderId} (${role})`,
            },
          },
        }),
      });

      if (linkRes.ok) {
        const linkJson = await linkRes.json();
        const linkId = linkJson?.data?.id ?? "";
        const checkoutUrl = linkJson?.data?.attributes?.checkout_url ?? "";
        const status = linkJson?.data?.attributes?.status ?? "unpaid";
        if (checkoutUrl) {
          return jsonResponse({
            order_id: orderId,
            payment_intent_id: linkId,
            redirect_url: checkoutUrl,
            status,
          });
        }
      }

      return jsonResponse({ error: "PayMongo session creation failed" }, 502);
    }

    if (action === "check_status") {
      const identifier = String(payload.identifier ?? "");
      if (!identifier) {
        return jsonResponse({ paid: false });
      }

      if (identifier.startsWith("cs_")) {
        const res = await fetch(
          `https://api.paymongo.com/v1/checkout_sessions/${encodeURIComponent(identifier)}`,
          {
            headers: {
              Accept: "application/json",
              Authorization: getAuthHeader(secretKey),
            },
          }
        );
        if (res.ok) {
          const json = await res.json();
          const attrs = json?.data?.attributes;
          const piStatus = attrs?.payment_intent?.attributes?.status;
          const payments = (attrs?.payments ?? []) as Array<{ attributes?: { status?: string } }>;
          const paid =
            piStatus === "succeeded" ||
            payments.some((p) => p?.attributes?.status === "paid");
          return jsonResponse({ paid });
        }
        return jsonResponse({ paid: false });
      }

      if (identifier.startsWith("link_")) {
        const res = await fetch(
          `https://api.paymongo.com/v1/links/${encodeURIComponent(identifier)}`,
          {
            headers: {
              Accept: "application/json",
              Authorization: getAuthHeader(secretKey),
            },
          }
        );
        if (res.ok) {
          const json = await res.json();
          const paid = json?.data?.attributes?.status === "paid";
          return jsonResponse({ paid });
        }
        return jsonResponse({ paid: false });
      }

      if (identifier.startsWith("src_")) {
        const res = await fetch(
          `https://api.paymongo.com/v1/sources/${encodeURIComponent(identifier)}`,
          {
            headers: {
              Accept: "application/json",
              Authorization: getAuthHeader(secretKey),
            },
          }
        );
        if (res.ok) {
          const json = await res.json();
          const status = json?.data?.attributes?.status;
          if (status === "charged") {
            return jsonResponse({ paid: true });
          }
          if (status === "chargeable") {
            const amount = json?.data?.attributes?.amount;
            const currency = json?.data?.attributes?.currency;
            const payRes = await fetch("https://api.paymongo.com/v1/payments", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Accept: "application/json",
                Authorization: getAuthHeader(secretKey),
              },
              body: JSON.stringify({
                data: {
                  attributes: {
                    amount,
                    currency,
                    source: { id: identifier, type: "source" },
                  },
                },
              }),
            });
            if (payRes.ok) {
              const payJson = await payRes.json();
              const payStatus = payJson?.data?.attributes?.status;
              return jsonResponse({
                paid: payStatus === "succeeded" || payStatus === "paid",
              });
            }
          }
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
