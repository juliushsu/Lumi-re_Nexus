-- Staging RLS smoke test for Film Investment Platform
-- Run after:
-- 1. 20260428093000_staging_security_and_roi_foundation.sql
-- 2. 20260428094500_roi_models_seed.sql
-- 3. 20260428101500_sample_role_assignment_staging.sql
--
-- Recommended execution contexts:
-- - Supabase SQL Editor for structure checks
-- - Authenticated API requests or impersonated sessions for role behavior checks

begin;

-- 1. Core structural assertions
do $$
declare
  missing_count integer;
begin
  select count(*)
  into missing_count
  from (
    values
      ('public', 'user_profiles'),
      ('public', 'projects'),
      ('public', 'project_evaluations'),
      ('public', 'investment_plans'),
      ('public', 'reports'),
      ('public', 'roi_models'),
      ('public', 'board_meetings'),
      ('public', 'board_resolutions'),
      ('public', 'board_action_items'),
      ('public', 'roi_model_change_logs')
  ) as required_tables(schema_name, table_name)
  where not exists (
    select 1
    from information_schema.tables t
    where t.table_schema = required_tables.schema_name
      and t.table_name = required_tables.table_name
  );

  if missing_count <> 0 then
    raise exception 'Missing required tables. Missing count: %', missing_count;
  end if;
end
$$;

-- 2. RLS enabled assertions
do $$
declare
  disabled_count integer;
begin
  select count(*)
  into disabled_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'user_profiles',
      'projects',
      'project_evaluations',
      'investment_plans',
      'reports',
      'roi_models',
      'board_meetings',
      'board_resolutions',
      'board_action_items',
      'roi_model_change_logs'
    )
    and c.relrowsecurity = false;

  if disabled_count <> 0 then
    raise exception 'One or more reviewed tables do not have RLS enabled. Disabled count: %', disabled_count;
  end if;
end
$$;

-- 3. ROI model columns required by v1
do $$
declare
  missing_count integer;
begin
  select count(*)
  into missing_count
  from (
    values
      ('model_name'),
      ('model_type'),
      ('budget_min'),
      ('budget_max'),
      ('expected_roi_min'),
      ('expected_roi_max'),
      ('payback_months_min'),
      ('payback_months_max'),
      ('risk_level'),
      ('assumptions_json'),
      ('formula_version'),
      ('status')
  ) as required_cols(column_name)
  where not exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'roi_models'
      and c.column_name = required_cols.column_name
  );

  if missing_count <> 0 then
    raise exception 'roi_models is missing required v1 columns. Missing count: %', missing_count;
  end if;
end
$$;

-- 4. Seed presence
do $$
declare
  seed_count integer;
begin
  select count(*)
  into seed_count
  from public.roi_models
  where model_name in (
    'micro_feature_film',
    'commercial_video_project',
    'streaming_series',
    'international_coproduction',
    'experimental_high_risk'
  );

  if seed_count <> 5 then
    raise exception 'Expected 5 seeded ROI models but found %.', seed_count;
  end if;
end
$$;

-- 5. Security helper and shareholder RPC assertions
do $$
declare
  missing_count integer;
begin
  select count(*)
  into missing_count
  from (
    values
      ('app', 'current_profile_role'),
      ('app', 'has_role'),
      ('app', 'has_any_role'),
      ('public', 'get_projects_dashboard_summary'),
      ('public', 'get_investment_plans_dashboard_summary'),
      ('public', 'get_reports_dashboard_summary')
  ) as required_functions(schema_name, function_name)
  where not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = required_functions.schema_name
      and p.proname = required_functions.function_name
  );

  if missing_count <> 0 then
    raise exception 'Missing expected helper or RPC functions. Missing count: %', missing_count;
  end if;
end
$$;

-- 6. Role assignment sanity, preserving the known super admin
do $$
declare
  admin_count integer;
begin
  select count(*)
  into admin_count
  from public.user_profiles
  where lower(email) = 'juliushsu@gmail.com'
    and role = 'super_admin'
    and status = 'active';

  if admin_count <> 1 then
    raise exception 'Expected exactly one active super_admin profile for juliushsu@gmail.com, found %.', admin_count;
  end if;
end
$$;

-- 7. Summary report for operator visibility
select
  'roi_models_seed_count' as check_name,
  count(*)::text as check_value
from public.roi_models
where model_name in (
  'micro_feature_film',
  'commercial_video_project',
  'streaming_series',
  'international_coproduction',
  'experimental_high_risk'
)
union all
select
  'active_super_admin_profiles',
  count(*)::text
from public.user_profiles
where role = 'super_admin'
  and status = 'active'
union all
select
  'shareholder_rpc_projects_rows',
  count(*)::text
from public.get_projects_dashboard_summary()
where app.has_role('super_admin');

rollback;

-- Manual authenticated tests
-- --------------------------
-- Use these as API-level role checks with real JWTs or impersonation:
--
-- `shareholder_viewer`
-- - `select * from public.get_projects_dashboard_summary();` => should succeed
-- - `select * from public.projects;` => should return 0 rows or fail at API layer due to no table contract
--
-- `report_viewer`
-- - `select id, report_code from public.reports limit 5;` => should succeed
-- - `select * from public.get_reports_dashboard_summary();` => should not be used by this role
--
-- `project_editor`
-- - insert/update on `public.projects` => should succeed
-- - insert on `public.project_evaluations` => should fail
--
-- `analyst`
-- - insert/update on `public.project_evaluations` => should succeed
-- - update on `public.projects` => should fail
