-- =============================================================================
-- Peso del bebé medido por el colchón (RF-11), no escrito a mano.
--   * babies.weight admite null: el perfil se crea sin peso.
--   * weigh_baby(p_baby_id): "Pesar ahora". Copia la última lectura del colchón
--     del usuario (reported_state.weight_kg) al perfil.
--   * Trigger: el peso solo puede cambiar a través de weigh_baby; un insert o
--     update directo por PostgREST no puede fijarlo.
-- =============================================================================

alter table public.babies alter column weight drop not null;
-- El check existente (weight > 0 and weight <= 30) sigue valiendo: null lo cumple.

-- Bloquea escrituras del peso que no vengan de weigh_baby.
create or replace function public.guard_baby_weight()
returns trigger language plpgsql set search_path = '' as $$
begin
  if coalesce(current_setting('cm.weighing', true), '') = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.weight := null;
  elsif new.weight is distinct from old.weight then
    new.weight := old.weight;
  end if;
  return new;
end $$;

drop trigger if exists guard_baby_weight on public.babies;
create trigger guard_baby_weight
  before insert or update on public.babies
  for each row execute function public.guard_baby_weight();

-- "Pesar ahora": toma el peso actual del colchón del usuario.
create or replace function public.weigh_baby(p_baby_id uuid)
returns public.babies language plpgsql security definer set search_path = '' as $$
declare
  v_device public.devices;
  v_weight numeric;
  v_row    public.babies;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select d.* into v_device
    from public.devices d
   where d.owner_id = auth.uid() and d.kind = 'mattress'
   order by d.last_seen_at desc nulls last
   limit 1;

  if not found then
    raise exception 'mattress_not_linked' using errcode = 'P0001';
  end if;
  -- Misma ventana que la app usa para "en línea" (30 s).
  if v_device.last_seen_at is null or v_device.last_seen_at < now() - interval '30 seconds' then
    raise exception 'mattress_offline' using errcode = 'P0001';
  end if;

  v_weight := case jsonb_typeof(v_device.reported_state -> 'weight_kg')
                when 'number' then (v_device.reported_state ->> 'weight_kg')::numeric
              end;
  -- Bajo 1 kg el puente considera el colchón vacío (presence_threshold_kg).
  if v_weight is null or v_weight < 1 or v_weight > 30 then
    raise exception 'no_weight_reading' using errcode = 'P0001';
  end if;

  perform set_config('cm.weighing', 'on', true);
  update public.babies b
     set weight = round(v_weight, 3)
   where b.id = p_baby_id and b.owner_id = auth.uid() and b.archived_at is null
  returning b.* into v_row;
  -- Revisar FOUND antes de otro PERFORM, que lo sobrescribe.
  if not found then
    raise exception 'baby_not_found' using errcode = 'P0002';
  end if;
  perform set_config('cm.weighing', 'off', true);
  return v_row;
end $$;

revoke all on function public.weigh_baby(uuid) from public, anon;
grant execute on function public.weigh_baby(uuid) to authenticated, service_role;
revoke all on function public.guard_baby_weight() from public, anon, authenticated;
