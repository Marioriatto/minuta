-- RF-12 / APP-010: iniciar y detener el periodo de detección desde la app.
--
-- La tabla `detection_periods` ya existe (migración inicial) con RLS de solo
-- lectura para `authenticated`, el trigger `detection_overlap` (sin solapes por
-- colchón) y `detection_enforce_refs` (dueño del colchón y del bebé).
-- `device_poll` ya entrega el periodo vigente al puente, comparando `ends_at`
-- con now(): por eso la duración opcional no necesita pg_cron.
--
-- Errores de negocio (los mapea la app en failure_mapper.dart):
--   not_authenticated, mattress_not_linked, baby_not_found, invalid_duration,
--   detection_already_active, no_active_detection.

create or replace function public.start_detection(
  p_device_id uuid,
  p_baby_id   uuid,
  p_minutes   integer default null
)
returns public.detection_periods
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.detection_periods;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.devices d
     where d.id = p_device_id and d.owner_id = v_uid and d.kind = 'mattress'
  ) then
    raise exception 'mattress_not_linked' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.babies b
     where b.id = p_baby_id and b.owner_id = v_uid and b.archived_at is null
  ) then
    raise exception 'baby_not_found' using errcode = 'P0002';
  end if;

  -- Hasta 24 h; null = sin límite (se detiene a mano).
  if p_minutes is not null and (p_minutes < 1 or p_minutes > 1440) then
    raise exception 'invalid_duration' using errcode = '22023';
  end if;

  -- Un solo periodo vigente por cuenta: fill_device_context asocia cada
  -- lectura al bebé del periodo vigente y no debe haber ambigüedad.
  if exists (
    select 1 from public.detection_periods dp
     where dp.owner_id = v_uid
       and dp.starts_at <= now()
       and (dp.ends_at is null or dp.ends_at > now())
  ) then
    raise exception 'detection_already_active' using errcode = 'P0001';
  end if;

  insert into public.detection_periods (owner_id, baby_id, device_id, starts_at, ends_at)
  values (
    v_uid, p_baby_id, p_device_id, now(),
    case when p_minutes is null then null
         else now() + make_interval(mins => p_minutes) end
  )
  returning * into v_row;

  insert into public.events (owner_id, baby_id, device_id, type, description, payload, occurred_at)
  values (
    v_uid, p_baby_id, p_device_id, 'detection_started',
    'Inicio de un periodo de detección',
    jsonb_build_object('period_id', v_row.id, 'minutes', p_minutes),
    v_row.starts_at
  );

  return v_row;
end $$;

create or replace function public.stop_detection()
returns public.detection_periods
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.detection_periods;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  update public.detection_periods dp
     -- ends_at > starts_at lo exige un CHECK de la tabla.
     set ends_at = greatest(now(), dp.starts_at + interval '1 second')
   where dp.id = (
     select p.id from public.detection_periods p
      where p.owner_id = v_uid
        and p.starts_at <= now()
        and (p.ends_at is null or p.ends_at > now())
      order by p.starts_at desc
      limit 1
   )
  returning dp.* into v_row;

  if not found then
    raise exception 'no_active_detection' using errcode = 'P0002';
  end if;

  insert into public.events (owner_id, baby_id, device_id, type, description, payload, occurred_at)
  values (
    v_uid, v_row.baby_id, v_row.device_id, 'detection_ended',
    'Fin de un periodo de detección',
    jsonb_build_object('period_id', v_row.id),
    v_row.ends_at
  );

  return v_row;
end $$;

revoke all on function public.start_detection(uuid, uuid, integer) from public, anon;
revoke all on function public.stop_detection() from public, anon;
grant execute on function public.start_detection(uuid, uuid, integer) to authenticated;
grant execute on function public.stop_detection() to authenticated;
