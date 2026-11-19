// Edge Function `device`: puerta de entrada de los módulos (o del puente de PC).
//
//   POST /functions/v1/device/ingest   lecturas, eventos y estado
//   GET|POST /functions/v1/device/poll configuración, detección y comandos
//   POST /functions/v1/device/ack      confirma un comando
//
// Autenticación: `Authorization: Bearer <device_token>` (el token que entrega
// provision_device). Se despliega SIN verificación de JWT (ver config.toml),
// porque el módulo no es un usuario de Supabase. La clave de servicio vive solo
// en las variables de entorno de la función y nunca sale de ella.
import { createClient } from "npm:@supabase/supabase-js@2";

const MAX_BODY_BYTES = 256 * 1024;
const TOKEN_SHAPE = /^[a-f0-9]{64}$/;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

/** Traduce los errores de las funciones SQL a códigos HTTP estables. */
function dbError(error: { message?: string; code?: string }): Response {
  const msg = error.message ?? "";
  if (msg.includes("device_not_claimed")) return json(409, { error: "device_not_claimed" });
  if (msg.includes("payload_too_large")) return json(413, { error: "payload_too_large" });
  if (msg.includes("invalid_status")) return json(422, { error: "invalid_status" });
  console.error("db_error", error.code, msg);
  return json(500, { error: "internal" });
}

async function readJson(req: Request): Promise<Record<string, unknown> | Response> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) return json(413, { error: "payload_too_large" });
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) return json(413, { error: "payload_too_large" });
  if (text.trim() === "") return {};
  try {
    const parsed = JSON.parse(text);
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json(422, { error: "body_must_be_object" });
    }
    return parsed as Record<string, unknown>;
  } catch {
    return json(422, { error: "invalid_json" });
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const route = new URL(req.url).pathname.replace(/\/+$/, "").split("/").pop();

  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (!TOKEN_SHAPE.test(token)) return json(401, { error: "unauthorized" });

  const { data: deviceId, error: authError } = await supabase.rpc(
    "authenticate_device",
    { p_token: token },
  );
  if (authError) return dbError(authError);
  if (!deviceId) return json(401, { error: "unauthorized" });

  switch (route) {
    case "ingest": {
      if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
      const body = await readJson(req);
      if (body instanceof Response) return body;
      const { data, error } = await supabase.rpc("device_ingest", {
        p_device_id: deviceId,
        p_payload: body,
      });
      return error ? dbError(error) : json(200, data);
    }
    case "poll": {
      if (req.method !== "GET" && req.method !== "POST") {
        return json(405, { error: "method_not_allowed" });
      }
      const { data, error } = await supabase.rpc("device_poll", { p_device_id: deviceId });
      return error ? dbError(error) : json(200, data);
    }
    case "ack": {
      if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
      const body = await readJson(req);
      if (body instanceof Response) return body;
      const commandId = Number(body.command_id);
      if (!Number.isSafeInteger(commandId) || commandId <= 0) {
        return json(422, { error: "invalid_command_id" });
      }
      const { error } = await supabase.rpc("device_ack_command", {
        p_device_id: deviceId,
        p_command_id: commandId,
        p_status: body.status,
        p_result: body.result ?? null,
      });
      return error ? dbError(error) : json(200, { ok: true });
    }
    default:
      return json(404, { error: "not_found" });
  }
});
