-- CIRQUA Sprint 2N
-- Read-only verification query for Phase A project-scoped child tables.

-- 1. Helper existence checks.
select
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'current_user_org_id'
  ) as current_user_org_id_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'can_access_project'
  ) as can_access_project_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'can_write_project'
  ) as can_write_project_exists;

-- 2. Helper test guidance.
select guidance
from (
  values
    ('Helper expectation: current_user_org_id() should return the caller org for authenticated users and null/deny for anon.'),
    ('Helper expectation: can_access_project(project_id) should return true only when the project belongs to current_user_org_id() or when service_role is used.'),
    ('Helper expectation: can_write_project(project_id) should be narrower than read and should not trust caller-provided org_id.')
) as guidance_rows(guidance);

-- 3. RLS status for Phase A tables.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'project_costs',
    'project_cost_items',
    'project_cast_costs',
    'project_revenues',
    'project_festival_records'
  )
order by c.relname;

-- 4. Policy listing.
select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'project_costs',
    'project_cost_items',
    'project_cast_costs',
    'project_revenues',
    'project_festival_records'
  )
order by tablename, policyname;

-- 5. Grants.
with target_tables as (
  select unnest(array[
    'project_costs',
    'project_cost_items',
    'project_cast_costs',
    'project_revenues',
    'project_festival_records'
  ]) as table_name
),
roles(role_name) as (
  values ('anon'), ('authenticated'), ('service_role')
)
select
  tt.table_name,
  r.role_name,
  has_table_privilege(r.role_name, format('public.%I', tt.table_name), 'SELECT') as can_select,
  has_table_privilege(r.role_name, format('public.%I', tt.table_name), 'INSERT') as can_insert,
  has_table_privilege(r.role_name, format('public.%I', tt.table_name), 'UPDATE') as can_update,
  has_table_privilege(r.role_name, format('public.%I', tt.table_name), 'DELETE') as can_delete
from target_tables tt
cross join roles r
order by tt.table_name, r.role_name;

-- 6. Row counts.
select table_name, row_count
from (
  select 'project_cast_costs' as table_name, count(*)::bigint as row_count from public.project_cast_costs
  union all select 'project_cost_items', count(*)::bigint from public.project_cost_items
  union all select 'project_costs', count(*)::bigint from public.project_costs
  union all select 'project_festival_records', count(*)::bigint from public.project_festival_records
  union all select 'project_revenues', count(*)::bigint from public.project_revenues
) s
order by table_name;

-- 7. project_id null checks.
select metric, value
from (
  select 'project_cast_costs.project_id_null' as metric, count(*) filter (where project_id is null)::bigint as value from public.project_cast_costs
  union all select 'project_cost_items.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_cost_items
  union all select 'project_costs.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_costs
  union all select 'project_festival_records.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_festival_records
  union all select 'project_revenues.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_revenues
) s
order by metric;

-- 8. project_id orphan checks.
select metric, value
from (
  select 'project_cast_costs.project_id_orphan' as metric, count(*)::bigint as value
  from public.project_cast_costs t left join public.projects p on p.id = t.project_id
  where t.project_id is not null and p.id is null
  union all
  select 'project_cost_items.project_id_orphan', count(*)::bigint
  from public.project_cost_items t left join public.projects p on p.id = t.project_id
  where t.project_id is not null and p.id is null
  union all
  select 'project_costs.project_id_orphan', count(*)::bigint
  from public.project_costs t left join public.projects p on p.id = t.project_id
  where t.project_id is not null and p.id is null
  union all
  select 'project_festival_records.project_id_orphan', count(*)::bigint
  from public.project_festival_records t left join public.projects p on p.id = t.project_id
  where t.project_id is not null and p.id is null
  union all
  select 'project_revenues.project_id_orphan', count(*)::bigint
  from public.project_revenues t left join public.projects p on p.id = t.project_id
  where t.project_id is not null and p.id is null
) s
order by metric;

-- 9. Expected behavior reminders.
select behavior
from (
  values
    ('anon expected behavior: no Phase A table access after rollout.'),
    ('authenticated expected behavior: same-org project rows only, via helper-backed SELECT policy.'),
    ('service_role expected behavior: management and verification paths remain functional.'),
    ('Rollback trigger: any verified same-org read regression, unexpected empty result for known service-role read, or auth path denial for intended same-org reader.')
) as behavior_rows(behavior);
