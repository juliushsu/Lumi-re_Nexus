-- CIRQUA Sprint 2M
-- Read-only verification query for business-table RLS readiness.

-- 1. RLS status and tenant-key presence.
with target_tables as (
  select unnest(array[
    'projects',
    'user_profiles',
    'project_evaluations',
    'project_costs',
    'project_cost_items',
    'project_cast_costs',
    'project_revenues',
    'project_festival_records',
    'investment_plans',
    'reports',
    'plan_projects',
    'plan_kpi_snapshots',
    'festival_events',
    'roi_models',
    'roi_model_weights',
    'project_source_links',
    'external_import_runs',
    'external_project_snapshots',
    'external_budget_snapshots',
    'external_import_field_mappings',
    'external_import_audit_logs'
  ]) as table_name
),
cols as (
  select
    table_name,
    max(case when column_name = 'org_id' then 1 else 0 end) as has_org_id,
    max(case when column_name = 'project_id' then 1 else 0 end) as has_project_id,
    max(case when column_name = 'plan_id' then 1 else 0 end) as has_plan_id
  from information_schema.columns
  where table_schema = 'public'
    and table_name in (select table_name from target_tables)
  group by table_name
)
select
  tt.table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced,
  coalesce(cols.has_org_id, 0)::int as has_org_id,
  coalesce(cols.has_project_id, 0)::int as has_project_id,
  coalesce(cols.has_plan_id, 0)::int as has_plan_id
from target_tables tt
join pg_class c on c.relname = tt.table_name
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
left join cols on cols.table_name = tt.table_name
where c.relkind = 'r'
order by tt.table_name;

-- 2. Policy listing.
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
    'projects',
    'user_profiles',
    'project_evaluations',
    'project_costs',
    'project_cost_items',
    'project_cast_costs',
    'project_revenues',
    'project_festival_records',
    'investment_plans',
    'reports',
    'plan_projects',
    'plan_kpi_snapshots',
    'festival_events',
    'roi_models',
    'roi_model_weights',
    'project_source_links',
    'external_import_runs',
    'external_project_snapshots',
    'external_budget_snapshots',
    'external_import_field_mappings',
    'external_import_audit_logs'
  )
order by tablename, policyname;

-- 3. Grants summary.
with target_tables as (
  select unnest(array[
    'projects',
    'user_profiles',
    'project_evaluations',
    'project_costs',
    'project_cost_items',
    'project_cast_costs',
    'project_revenues',
    'project_festival_records',
    'investment_plans',
    'reports',
    'plan_projects',
    'plan_kpi_snapshots',
    'festival_events',
    'roi_models',
    'roi_model_weights',
    'project_source_links',
    'external_import_runs',
    'external_project_snapshots',
    'external_budget_snapshots',
    'external_import_field_mappings',
    'external_import_audit_logs'
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

-- 4. Tenant-key null counts.
select metric, value
from (
  select 'projects.org_id_null' as metric, count(*) filter (where org_id is null)::bigint as value from public.projects
  union all select 'user_profiles.org_id_null', count(*) filter (where org_id is null)::bigint from public.user_profiles
  union all select 'project_evaluations.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_evaluations
  union all select 'project_costs.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_costs
  union all select 'project_cost_items.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_cost_items
  union all select 'project_cast_costs.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_cast_costs
  union all select 'project_revenues.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_revenues
  union all select 'project_festival_records.project_id_null', count(*) filter (where project_id is null)::bigint from public.project_festival_records
  union all select 'investment_plans.org_id_null', count(*) filter (where org_id is null)::bigint from public.investment_plans
  union all select 'reports.org_id_null', count(*) filter (where org_id is null)::bigint from public.reports
  union all select 'reports.project_id_null', count(*) filter (where project_id is null)::bigint from public.reports
  union all select 'reports.plan_id_null', count(*) filter (where plan_id is null)::bigint from public.reports
  union all select 'reports.evaluation_id_null', count(*) filter (where evaluation_id is null)::bigint from public.reports
  union all select 'plan_projects.project_id_null', count(*) filter (where project_id is null)::bigint from public.plan_projects
  union all select 'plan_projects.plan_id_null', count(*) filter (where plan_id is null)::bigint from public.plan_projects
  union all select 'plan_projects.evaluation_id_null', count(*) filter (where evaluation_id is null)::bigint from public.plan_projects
  union all select 'plan_kpi_snapshots.plan_id_null', count(*) filter (where plan_id is null)::bigint from public.plan_kpi_snapshots
) s
order by metric;

-- 5. Orphan checks.
select metric, value
from (
  select 'project_evaluations.project_id_orphan' as metric, count(*)::bigint as value
  from public.project_evaluations pe left join public.projects p on p.id = pe.project_id
  where pe.project_id is not null and p.id is null
  union all
  select 'project_costs.project_id_orphan', count(*)::bigint
  from public.project_costs pc left join public.projects p on p.id = pc.project_id
  where pc.project_id is not null and p.id is null
  union all
  select 'project_cost_items.project_id_orphan', count(*)::bigint
  from public.project_cost_items pci left join public.projects p on p.id = pci.project_id
  where pci.project_id is not null and p.id is null
  union all
  select 'project_cast_costs.project_id_orphan', count(*)::bigint
  from public.project_cast_costs pcc left join public.projects p on p.id = pcc.project_id
  where pcc.project_id is not null and p.id is null
  union all
  select 'project_revenues.project_id_orphan', count(*)::bigint
  from public.project_revenues pr left join public.projects p on p.id = pr.project_id
  where pr.project_id is not null and p.id is null
  union all
  select 'project_festival_records.project_id_orphan', count(*)::bigint
  from public.project_festival_records pfr left join public.projects p on p.id = pfr.project_id
  where pfr.project_id is not null and p.id is null
  union all
  select 'reports.project_id_orphan', count(*)::bigint
  from public.reports r left join public.projects p on p.id = r.project_id
  where r.project_id is not null and p.id is null
  union all
  select 'reports.plan_id_orphan', count(*)::bigint
  from public.reports r left join public.investment_plans ip on ip.id = r.plan_id
  where r.plan_id is not null and ip.id is null
  union all
  select 'reports.evaluation_id_orphan', count(*)::bigint
  from public.reports r left join public.project_evaluations pe on pe.id = r.evaluation_id
  where r.evaluation_id is not null and pe.id is null
  union all
  select 'plan_projects.project_id_orphan', count(*)::bigint
  from public.plan_projects pp left join public.projects p on p.id = pp.project_id
  where pp.project_id is not null and p.id is null
  union all
  select 'plan_projects.plan_id_orphan', count(*)::bigint
  from public.plan_projects pp left join public.investment_plans ip on ip.id = pp.plan_id
  where pp.plan_id is not null and ip.id is null
  union all
  select 'plan_projects.evaluation_id_orphan', count(*)::bigint
  from public.plan_projects pp left join public.project_evaluations pe on pe.id = pp.evaluation_id
  where pp.evaluation_id is not null and pe.id is null
  union all
  select 'plan_kpi_snapshots.plan_id_orphan', count(*)::bigint
  from public.plan_kpi_snapshots ks left join public.investment_plans ip on ip.id = ks.plan_id
  where ks.plan_id is not null and ip.id is null
) s
order by metric;

-- 6. Write-path dependency warnings.
select warning
from (
  values
    ('projects direct client write is intentionally disabled; use controlled RPC.'),
    ('project_evaluations still has direct authenticated write policies and should be reconciled before wider tenant RLS.'),
    ('project_costs, project_cost_items, project_cast_costs, project_revenues, project_festival_records currently have broad grants and no RLS.'),
    ('investment_plans and reports have RLS enabled but are still role-scoped rather than tenant-scoped.'),
    ('plan_projects and plan_kpi_snapshots require plan helper design before RLS enable.'),
    ('system/raw CIRQUA tables should remain RPC or service mediated rather than broad client-writable.')
) as warnings(warning);
