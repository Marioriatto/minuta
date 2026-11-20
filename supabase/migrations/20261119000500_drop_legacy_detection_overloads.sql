-- La migración inicial traía start_detection(uuid, uuid, timestamptz) y
-- stop_detection(uuid): sin validar colchón ni periodo único y sin registrar
-- eventos. Las reemplazan las de 20261119000400_detection_rpc.sql.
drop function if exists public.start_detection(uuid, uuid, timestamptz);
drop function if exists public.stop_detection(uuid);
