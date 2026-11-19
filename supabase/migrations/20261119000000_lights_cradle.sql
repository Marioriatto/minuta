-- =============================================================================
-- Luces y cuna: funciones de la app con validación en el servidor.
--   RF-20 brillo, RF-21 velocidad, RF-22 temporizador (CUNA-001, CUNA-003)
--   RF-18 umbrales de temperatura y humedad (APP-009)
-- El temporizador se calcula con la hora del servidor (ends_at), no con la del teléfono.
-- =============================================================================

-- Valores de fábrica (RF-07, APP-014). Solo afectan a módulos que se vinculen desde ahora.
update public.device_kinds
   set default_config = '{"on":false,"brightness":50,"speed":50,"timer_minutes":null,"ends_at":null}'::jsonb
 where code = 'lights';

-- Encender/apagar luces y fijar brillo, velocidad y temporizador (RF-20, RF-21, RF-22).
create or replace function public.set_lights(
  p_device_id uuid,
  p_on        boolean,
  p_brightness integer,
  p_speed     integer,
  p_minutes   integer default null)
returns public.devices language plpgsql security definer set search_path = '' as $$
declare
  v_row public.devices;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_on is null or p_brightness is null or p_speed is null
     or p_brightness not between 0 and 100 or p_speed not between 0 and 100 then
    raise exception 'invalid_lights_values' using errcode = '22023';
  end if;
  if p_minutes is not null and p_minutes not between 1 and 720 then
    raise exception 'invalid_timer' using errcode = '22023';
  end if;

  update public.devices d
     set config = d.config || jsonb_build_object(
           'on', p_on,
           'brightness', p_brightness,
           'speed', p_speed,
           'timer_minutes', case when p_on then p_minutes end,
           'ends_at', case when p_on and p_minutes is not null
                           then to_jsonb(now() + make_interval(mins => p_minutes)) end)
   where d.id = p_device_id and d.owner_id = auth.uid() and d.kind = 'lights'
  returning d.* into v_row;

  if not found then
    raise exception 'device_not_found' using errcode = 'P0002';
  end if;

  insert into public.events (device_id, type, description, payload)
  values (p_device_id, 'lights_changed', null,
          jsonb_build_object('on', p_on, 'brightness', p_brightness,
                             'speed', p_speed, 'minutes', p_minutes));
  return v_row;
end $$;

-- Umbrales de alerta de la cuna (RF-18). Cualquier límite puede ser null (sin límite).
create or replace function public.set_thresholds(
  p_device_id uuid,
  p_temp_min  numeric, p_temp_max numeric,
  p_hum_min   numeric, p_hum_max  numeric)
returns public.devices language plpgsql security definer set search_path = '' as $$
declare
  v_row public.devices;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if (p_temp_min is not null and p_temp_min not between -20 and 60)
     or (p_temp_max is not null and p_temp_max not between -20 and 60)
     or (p_temp_min is not null and p_temp_max is not null and p_temp_min >= p_temp_max)
     or (p_hum_min is not null and p_hum_min not between 0 and 100)
     or (p_hum_max is not null and p_hum_max not between 0 and 100)
     or (p_hum_min is not null and p_hum_max is not null and p_hum_min >= p_hum_max) then
    raise exception 'invalid_thresholds' using errcode = '22023';
  end if;

  update public.devices d
     set config = jsonb_set(d.config, '{thresholds}', jsonb_build_object(
           'temperature', jsonb_strip_nulls(jsonb_build_object('min', p_temp_min, 'max', p_temp_max)),
           'humidity',    jsonb_strip_nulls(jsonb_build_object('min', p_hum_min,  'max', p_hum_max))),
           true)
   where d.id = p_device_id and d.owner_id = auth.uid() and d.kind = 'cradle'
  returning d.* into v_row;

  if not found then
    raise exception 'device_not_found' using errcode = 'P0002';
  end if;
  return v_row;
end $$;

-- Apaga en la base las luces cuyo temporizador ya venció (la app lo ve por Realtime).
create or replace function public.expire_lights_timers()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_rows integer;
begin
  update public.devices
     set config = config || '{"on":false,"ends_at":null}'::jsonb
   where kind = 'lights'
     and config ->> 'on' = 'true'
     and nullif(config ->> 'ends_at', '') is not null
     and (config ->> 'ends_at')::timestamptz <= now();
  get diagnostics v_rows = row_count;
  return v_rows;
end $$;

-- Permisos: solo usuarios con sesión (y el servidor) pueden llamar a estas funciones.
revoke all on function public.set_lights(uuid, boolean, integer, integer, integer) from public, anon;
revoke all on function public.set_thresholds(uuid, numeric, numeric, numeric, numeric) from public, anon;
revoke all on function public.expire_lights_timers() from public, anon, authenticated;
grant execute on function public.set_lights(uuid, boolean, integer, integer, integer) to authenticated, service_role;
grant execute on function public.set_thresholds(uuid, numeric, numeric, numeric, numeric) to authenticated, service_role;
grant execute on function public.expire_lights_timers() to service_role;

select cron.schedule('cm-expire-lights', '* * * * *', 'select public.expire_lights_timers()');
