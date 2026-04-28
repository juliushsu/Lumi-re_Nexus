-- CIRQUA Stabilization Sprint 2A
-- Read-only verification queries
--
-- These queries are safe to run as inspection checks before any tenant hardening
-- rollout. They do not mutate data.

-- ---------------------------------------------------------------------------
-- 1. RLS enabled status
-- ---------------------------------------------------------------------------
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname;

-- ---------------------------------------------------------------------------
-- 2. Table privileges for anon / authenticated / service_role
-- ---------------------------------------------------------------------------
with target_tables(table_name) as (
  values
    ('festival_events'),
    ('investment_plans'),
    ('plan_kpi_snapshots'),
    ('plan_projects'),
    ('project_cast_costs'),
    ('project_cost_items'),
    ('project_costs'),
    ('project_evaluations'),
    ('project_festival_records'),
    ('project_revenues'),
    ('projects'),
    ('reports'),
    ('roi_models'),
    ('user_profiles')
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

-- ---------------------------------------------------------------------------
-- 3. Existing policies
-- ---------------------------------------------------------------------------
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
order by tablename, policyname;

-- ---------------------------------------------------------------------------
-- 4. projects.org_id state
-- ---------------------------------------------------------------------------
select
  exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'projects'
      and c.column_name = 'org_id'
  ) as projects_has_org_id;

select
  p.id as project_id,
  coalesce(
    nullif(p.project_name_zh, ''),
    nullif(p.project_name_en, ''),
    nullif(p.project_code, ''),
    p.id::text
  ) as project_name,
  case
    when exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'projects'
        and c.column_name = 'org_id'
    ) then to_jsonb(p) ->> 'org_id'
    else null
  end as current_org_id,
  case
    when exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'projects'
        and c.column_name = 'org_id'
    ) then 'org_id present'
    else 'org_id missing'
  end as org_id_status
from public.projects p
order by p.created_at nulls last, p.updated_at nulls last, p.id;

select
  case
    when exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'projects'
        and c.column_name = 'org_id'
    ) then (
      select count(*)
      from public.projects p
      where (to_jsonb(p) ->> 'org_id') is null
    )::text
    else 'projects.org_id column missing'
  end as projects_org_id_null_state;

-- ---------------------------------------------------------------------------
-- 5. Historical Sprint 1 checks
-- ---------------------------------------------------------------------------
select
  exists (
    select 1
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_name = 'profiles'
  ) as profiles_table_exists;

select
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_org_usage'
  ) as get_org_usage_exists;

-- ---------------------------------------------------------------------------
-- 6. Cross-tenant read readiness / blocker check
-- ---------------------------------------------------------------------------
-- This query does not prove tenant isolation by itself.
-- It tells the operator whether the tenant key exists yet.
select
  case
    when exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'projects'
        and c.column_name = 'org_id'
    ) then 'ready_for_cross_tenant_rls_verification'
    else 'blocked_missing_projects_org_id'
  end as cross_tenant_verification_state;

-- After projects.org_id and user_profiles.org_id exist, validate with real users
-- from two different orgs and confirm:
-- - user A cannot read user B org rows
-- - user A cannot select projects where projects.org_id <> app.current_org_id()
-- - child tables inherit the same restriction through project_id / plan_id joins
