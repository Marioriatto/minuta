// Edge Function `push`: envía por Firebase Cloud Messaging una alerta nueva.
//
//   POST /functions/v1/push   { "alert_id": 123 }
//
// La llama el trigger `alerts_notify_push` (pg_net) al insertarse una alerta
// warning/critical. Se despliega SIN verificación de JWT: no hace falta secreto
// porque el envío es idempotente (`alerts.pushed_at`): llamarla de nuevo, o
// desde fuera, como mucho adelanta un envío que ya estaba pendiente.
//
// Secreto necesario (Supabase → Edge Functions → Secrets):
//   FCM_SERVICE_ACCOUNT = JSON completo de la cuenta de servicio de Firebase.
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface Alert {
  id: number;
  owner_id: string;
  type: string;
  severity: string;
  payload: Record<string, unknown>;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

// ---------- Textos (es-CR). Deben coincidir con el tono de la app.
function num(v: unknown): string {
  return typeof v === "number" ? v.toFixed(1).replace(".", ",") : "—";
}

function message(alert: Alert): { title: string; body: string } {
  const p = alert.payload ?? {};
  switch (alert.type) {
    case "absence_detected":
      return { title: "Bebé fuera del colchón", body: "Se dejó de detectar el peso del bebé." };
    case "temperature_high":
      return { title: "Temperatura alta en la cuna", body: `${num(p.value)} °C (máximo ${num(p.max)} °C).` };
    case "temperature_low":
      return { title: "Temperatura baja en la cuna", body: `${num(p.value)} °C (mínimo ${num(p.min)} °C).` };
    case "humidity_high":
      return { title: "Humedad alta en la cuna", body: `${num(p.value)} % (máximo ${num(p.max)} %).` };
    case "humidity_low":
      return { title: "Humedad baja en la cuna", body: `${num(p.value)} % (mínimo ${num(p.min)} %).` };
    default:
      return { title: "Alerta de Colchón Minuta", body: "Abre la app para ver el detalle." };
  }
}

// ---------- OAuth2 de la cuenta de servicio (JWT RS256 firmado con Web Crypto).
let cachedToken: { value: string; expiresAt: number } | null = null;

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importKey(pem: string): Promise<CryptoKey> {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    await importKey(sa.private_key),
    new TextEncoder().encode(unsigned),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`oauth_failed_${res.status}`);
  const data = await res.json() as { access_token: string; expires_in: number };
  cachedToken = { value: data.access_token, expiresAt: now + data.expires_in };
  return data.access_token;
}

// ---------- Envío a un token. Devuelve "ok", "invalid" (borrar) o "error".
async function sendTo(
  sa: ServiceAccount,
  bearer: string,
  token: string,
  alert: Alert,
): Promise<"ok" | "invalid" | "error"> {
  const { title, body } = message(alert);
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: { authorization: `Bearer ${bearer}`, "content-type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: { alert_id: String(alert.id), type: alert.type, severity: alert.severity },
          android: {
            priority: "high",
            notification: { channel_id: "alerts", tag: `alert-${alert.id}` },
          },
          apns: { headers: { "apns-priority": "10" } },
        },
      }),
    },
  );
  if (res.ok) return "ok";
  const text = await res.text();
  // Token caducado o de otra app: se borra para no reintentar.
  // (INVALID_ARGUMENT no se usa: también aparece si el mensaje está mal armado.)
  if (res.status === 404 || text.includes("UNREGISTERED")) {
    return "invalid";
  }
  console.error("fcm_error", res.status, text.slice(0, 300));
  return "error";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  let alertId: number;
  try {
    const body = await req.json() as { alert_id?: unknown };
    alertId = Number(body.alert_id);
    if (!Number.isSafeInteger(alertId) || alertId <= 0) throw new Error();
  } catch {
    return json(422, { error: "invalid_alert_id" });
  }

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) return json(503, { error: "fcm_not_configured" });
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(raw);
  } catch {
    return json(503, { error: "fcm_misconfigured" });
  }

  // Reclama la alerta: solo la primera llamada la obtiene (idempotencia).
  const { data: claimed, error } = await supabase
    .from("alerts")
    .update({ pushed_at: new Date().toISOString() })
    .eq("id", alertId)
    .is("pushed_at", null)
    .in("severity", ["warning", "critical"])
    .select("id, owner_id, type, severity, payload")
    .maybeSingle();
  if (error) {
    console.error("db_error", error.code, error.message);
    return json(500, { error: "internal" });
  }
  if (!claimed) return json(200, { sent: 0, skipped: "already_pushed_or_not_found" });
  const alert = claimed as Alert;

  const { data: tokens } = await supabase
    .from("push_tokens")
    .select("token")
    .eq("owner_id", alert.owner_id);
  if (!tokens?.length) return json(200, { sent: 0, skipped: "no_tokens" });

  const bearer = await accessToken(sa);
  let sent = 0;
  const invalid: string[] = [];
  for (const { token } of tokens) {
    const result = await sendTo(sa, bearer, token, alert);
    if (result === "ok") sent++;
    if (result === "invalid") invalid.push(token);
  }
  if (invalid.length) await supabase.from("push_tokens").delete().in("token", invalid);

  return json(200, { sent, removed: invalid.length });
});
