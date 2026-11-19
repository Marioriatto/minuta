-- =============================================================================
-- Notificaciones push de alertas (RF-03, APP-001, APP-008, APP-009, RNF-01).
--   * register_push_token / unregister_push_token: la app guarda su token FCM.
--   * mark_alerts_read: marcar alertas como leídas (la app no tiene UPDATE).
--   * Al insertarse una alerta warning/critical, pg_net llama a la Edge
--     Function `push`, que envía por FCM. `pushed_at` hace el envío
--     idempotente: cada alerta se envía como mucho una vez, así el endpoint
--     no necesita secreto (llamarlo solo adelanta un envío pendiente).
-- =============================================================================

create extension if not exists pg_net with schema extensions;

alter table public.alerts add column if not exists pushed_at timestamptz;

-- URL de la función de envío (por proyecto; se cambia sin tocar el código).
insert into public.app_config (key, value, description)
values ('push_function_url',
        to_jsonb('https://npeohlyntlautxgqtnds.supabase.co/functions/v1/push'::text),
        'Edge Function que envía las alertas por FCM')
on conflict (key) do update set value = excluded.value;

-- Guarda (o reasigna) el token FCM del teléfono para el usuario actual.
create or replace function public.register_push_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_platform not in ('android', 'ios')
     or p_token is null or char_length(p_token) not between 20 and 4096 then
    raise exception 'invalid_push_token' using errcode = '22023';
  end if;
  -- El mismo teléfono puede cambiar de cuenta: el token pasa al usuario actual.
  insert into public.push_tokens (owner_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (token) do update
    set owner_id = excluded.owner_id,
        platform = excluded.platform,
        last_seen_at = now();
end $$;

-- Borra el token al cerrar sesión (solo si es del usuario actual).
create or replace function public.unregister_push_token(p_token text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  delete from public.push_tokens where token = p_token and owner_id = auth.uid();
end $$;

-- Marca como leídas las alertas indicadas, o todas si p_ids es null.
create or replace function public.mark_alerts_read(p_ids bigint[] default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_rows integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  update public.alerts a
     set read_at = now()
   where a.owner_id = auth.uid()
     and a.read_at is null
     and (p_ids is null or a.id = any (p_ids));
  get diagnostics v_rows = row_count;
  return v_rows;
end $$;

-- Dispara el envío push de alertas importantes (no bloquea la inserción).
create or replace function public.notify_alert_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
begin
  if new.severity not in ('warning', 'critical') then
    return new;
  end if;
  select value #>> '{}' into v_url from public.app_config where key = 'push_function_url';
  if v_url is null then
    return new;
  end if;
  perform net.http_post(
    url     := v_url,
    body    := jsonb_build_object('alert_id', new.id),
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return new;
exception when others then
  -- Un fallo del push nunca debe impedir que se guarde la alerta.
  raise warning 'notify_alert_push: %', sqlerrm;
  return new;
end $$;

drop trigger if exists alerts_notify_push on public.alerts;
create trigger alerts_notify_push
  after insert on public.alerts
  for each row execute function public.notify_alert_push();

revoke all on function public.register_push_token(text, text) from public, anon;
revoke all on function public.unregister_push_token(text) from public, anon;
revoke all on function public.mark_alerts_read(bigint[]) from public, anon;
revoke all on function public.notify_alert_push() from public, anon, authenticated;
grant execute on function public.register_push_token(text, text) to authenticated, service_role;
grant execute on function public.unregister_push_token(text) to authenticated, service_role;
grant execute on function public.mark_alerts_read(bigint[]) to authenticated, service_role;
