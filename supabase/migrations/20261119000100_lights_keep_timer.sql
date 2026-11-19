-- Cambiar brillo o velocidad no debe reiniciar el temporizador en curso (RF-22).
-- Se reemplaza set_lights añadiendo p_keep_timer (se borra la firma anterior para
-- que PostgREST no vea dos sobrecargas ambiguas).
drop function if exists public.set_lights(uuid, boolean, integer, integer, integer);

create or replace function public.set_lights(
  p_device_id  uuid,
  p_on         boolean,
  p_brightness integer,
  p_speed      integer,
  p_minutes    integer default null,
  p_keep_timer boolean default false)
returns public.devices language plpgsql security definer set search_path = '' as $$
declare
  v_row public.devices;
  v_timer jsonb;
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

  select d.* into v_row from public.devices d
   where d.id = p_device_id and d.owner_id = auth.uid() and d.kind = 'lights'
   for update;
  if not found then
    raise exception 'device_not_found' using errcode = 'P0002';
  end if;

  if not p_on then
    v_timer := '{"timer_minutes":null,"ends_at":null}'::jsonb;
  elsif p_keep_timer
        and nullif(v_row.config ->> 'ends_at', '') is not null
        and (v_row.config ->> 'ends_at')::timestamptz > now() then
    v_timer := jsonb_build_object('timer_minutes', v_row.config -> 'timer_minutes',
                                  'ends_at', v_row.config -> 'ends_at');
  else
    v_timer := jsonb_build_object(
      'timer_minutes', p_minutes,
      'ends_at', case when p_minutes is not null
                      then to_jsonb(now() + make_interval(mins => p_minutes)) end);
  end if;

  update public.devices d
     set config = d.config || jsonb_build_object('on', p_on, 'brightness', p_brightness,
                                                 'speed', p_speed) || v_timer
   where d.id = p_device_id
  returning d.* into v_row;

  insert into public.events (device_id, type, description, payload)
  values (p_device_id, 'lights_changed', null,
          jsonb_build_object('on', p_on, 'brightness', p_brightness,
                             'speed', p_speed, 'minutes', p_minutes));
  return v_row;
end $$;

revoke all on function public.set_lights(uuid, boolean, integer, integer, integer, boolean) from public, anon;
grant execute on function public.set_lights(uuid, boolean, integer, integer, integer, boolean) to authenticated, service_role;
