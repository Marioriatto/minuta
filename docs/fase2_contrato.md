# Fase 2 — Contrato esperado de `babies` (Supabase)

La app habla con la tabla `public.babies` por PostgREST (con el JWT del usuario).
Esta es la especificación que **la app asume**; ajústala a tu esquema y avísame de
cualquier diferencia. La base de datos es tuya: esto no se ejecuta solo.

## Columnas

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK, default `gen_random_uuid()` | La app lo trata como texto |
| `parent_id` | `uuid` not null, default `auth.uid()`, FK → `users(id)` on delete cascade | **La app no lo envía**. En producción la columna se llama **`owner_id`** |
| `name` | `text` not null, 1–50 caracteres tras recortar | |
| `birth` | `date` not null, no futura | La edad se calcula en la app |
| `weight` | `numeric(5,3)` **null**, `> 0` y `<= 30` | kg. Desde 2026-11-19 lo escribe solo `weigh_baby` con la lectura del colchón (RF-11); ver `supabase/migrations/20261119000200_baby_weight_from_mattress.sql` |
| `registered_at` | `timestamptz` not null, default `now()` | Orden de la lista |
| `archived_at` | `timestamptz` null | `null` = activo |

## SQL de referencia

```sql
create table public.babies (
  id            uuid primary key default gen_random_uuid(),
  parent_id     uuid not null default auth.uid()
                  references public.users (id) on delete cascade,
  name          text not null check (char_length(btrim(name)) between 1 and 50),
  birth         date not null check (birth <= current_date),
  weight        numeric(5,3) not null check (weight > 0 and weight <= 30),
  registered_at timestamptz not null default now(),
  archived_at   timestamptz
);
create index on public.babies (parent_id);

alter table public.babies enable row level security;

create policy babies_select on public.babies for select to authenticated
  using (parent_id = (select auth.uid()));
create policy babies_insert on public.babies for insert to authenticated
  with check (parent_id = (select auth.uid()));
create policy babies_update on public.babies for update to authenticated
  using (parent_id = (select auth.uid()))
  with check (parent_id = (select auth.uid()));
create policy babies_delete on public.babies for delete to authenticated
  using (parent_id = (select auth.uid()));
```

## Operaciones que usa la app

| Acción | Petición |
|---|---|
| Listar | `select * from babies order by registered_at` |
| Crear | `insert {name, birth}` → devuelve la fila (peso `null`) |
| Editar | `update {name, birth} where id` → devuelve la fila |
| Pesar ahora | `rpc weigh_baby(p_baby_id)` → devuelve la fila. Errores: `mattress_not_linked`, `mattress_offline` (> 30 s sin reportar), `no_weight_reading` (< 1 kg o > 30 kg), `baby_not_found` |
| Archivar | `update {archived_at: <now UTC>} where id` |
| Restaurar | `update {archived_at: null} where id` |
| Eliminar | `delete where id` |

## Para el borrado definitivo

Toda tabla que cuelgue de `babies` (eventos, lecturas, capturas, periodos de
detección, etc.) debe referenciarla con `on delete cascade`; si no, el borrado
fallará por integridad referencial en lugar de eliminar el historial.

## Qué NO hace la app

- No guarda cuál es el perfil activo en la base: vive en el teléfono (por usuario).
- No guarda la edad: la calcula desde `birth`.
- No impide por sí sola crear perfiles duplicados (mismo nombre): no está en el SRS.
