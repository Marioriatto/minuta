-- COL-002 (RF-12 / APP-010): al vencer un periodo de detección con duración se
-- registra `detection_ended`, igual que al detenerlo a mano con stop_detection().
--
-- Un job de pg_cron revisa cada minuto. Un periodo ya tiene su evento si existe
-- un `detection_ended` con payload.period_id = id (stop_detection lo escribe
-- así), de modo que nunca se duplica. Solo mira el último día: los periodos
-- vencidos antes de esta migración no generan eventos atrasados en masa.

create or replace function public.close_expired_detections()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rows integer;
begin
  insert into public.events (owner_id, baby_id, device_id, type, description, payload, occurred_at)
  select dp.owner_id, dp.baby_id, dp.device_id, 'detection_ended',
         'Fin de un periodo de detección (terminó su duración)',
         jsonb_build_object('period_id', dp.id, 'automatic', true),
         dp.ends_at
    from public.detection_periods dp
   where dp.ends_at is not null
     and dp.ends_at <= now()
     and dp.ends_at > now() - interval '1 day'
     and not exists (
       select 1 from public.events e
        where e.owner_id = dp.owner_id
          and e.type = 'detection_ended'
          and e.payload ->> 'period_id' = dp.id::text
     );
  get diagnostics v_rows = row_count;
  return v_rows;
end $$;

revoke all on function public.close_expired_detections() from public, anon, authenticated;
grant execute on function public.close_expired_detections() to service_role;

-- Reprogramar sin duplicar el job si la migración se vuelve a aplicar.
select cron.unschedule(jobid) from cron.job where jobname = 'cm-close-detections';
select cron.schedule('cm-close-detections', '* * * * *',
                     'select public.close_expired_detections()');
