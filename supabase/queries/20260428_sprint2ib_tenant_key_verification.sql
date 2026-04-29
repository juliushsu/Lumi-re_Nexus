-- CIRQUA Sprint 2I-B
-- Read-only verification queries for tenant key hardening planning.

-- 1. Current key-column inventory for target business tables.
with target_tables as (
  select *
  from (values
    ('investment_plans'),
    ('plan_kpi_snapshots'),
    ('plan_projects'),
    ('project_evaluations'),
    ('project_costs'),
    ('project_cost_items'),
    ('project_cast_costs'),
    ('project_revenues'),
    ('project_festival_records'),
    ('project_source_links'),
    ('reports'),
    ('external_import_runs'),
    ('external_project_snapshots'),
    ('external_budget_snapshots'),
    ('external_import_field_mappings'),
    ('external_import_audit_logs')
  ) as t(table_name)
)
select
  tt.table_name,
  exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = tt.table_name
      and c.column_name = 'org_id'
  ) as has_org_id,
  exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = tt.table_name
      and c.column_name = 'project_id'
  ) as has_project_id,
  exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = tt.table_name
      and c.column_name = 'plan_id'
  ) as has_plan_id,
  exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = tt.table_name
      and c.column_name = 'evaluation_id'
  ) as has_evaluation_id
from target_tables tt
order by tt.table_name;

-- 2. Row counts.
select 'investment_plans' as table_name, count(*)::bigint as row_count from public.investment_plans
union all
select 'plan_kpi_snapshots', count(*)::bigint from public.plan_kpi_snapshots
union all
select 'plan_projects', count(*)::bigint from public.plan_projects
union all
select 'project_evaluations', count(*)::bigint from public.project_evaluations
union all
select 'project_costs', count(*)::bigint from public.project_costs
union all
select 'project_cost_items', count(*)::bigint from public.project_cost_items
union all
select 'project_cast_costs', count(*)::bigint from public.project_cast_costs
union all
select 'project_revenues', count(*)::bigint from public.project_revenues
union all
select 'project_festival_records', count(*)::bigint from public.project_festival_records
union all
select 'project_source_links', count(*)::bigint from public.project_source_links
union all
select 'reports', count(*)::bigint from public.reports
union all
select 'external_import_runs', count(*)::bigint from public.external_import_runs
union all
select 'external_project_snapshots', count(*)::bigint from public.external_project_snapshots
union all
select 'external_budget_snapshots', count(*)::bigint from public.external_budget_snapshots
union all
select 'external_import_field_mappings', count(*)::bigint from public.external_import_field_mappings
union all
select 'external_import_audit_logs', count(*)::bigint from public.external_import_audit_logs
order by table_name;

-- 3. Null key counts where tenant anchors already exist.
select 'projects' as table_name, count(*) filter (where org_id is null)::bigint as null_org_id_count from public.projects
union all
select 'user_profiles', count(*) filter (where org_id is null)::bigint from public.user_profiles
union all
select 'project_evaluations', count(*) filter (where project_id is null)::bigint from public.project_evaluations
union all
select 'project_costs', count(*) filter (where project_id is null)::bigint from public.project_costs
union all
select 'project_cost_items', count(*) filter (where project_id is null)::bigint from public.project_cost_items
union all
select 'project_cast_costs', count(*) filter (where project_id is null)::bigint from public.project_cast_costs
union all
select 'project_revenues', count(*) filter (where project_id is null)::bigint from public.project_revenues
union all
select 'project_festival_records', count(*) filter (where project_id is null)::bigint from public.project_festival_records
union all
select 'project_source_links', count(*) filter (where project_id is null)::bigint from public.project_source_links
union all
select 'reports.project_id', count(*) filter (where project_id is null)::bigint from public.reports
union all
select 'plan_projects.project_id', count(*) filter (where project_id is null)::bigint from public.plan_projects
order by table_name;

-- 4. Orphan project_id checks.
select 'project_evaluations' as table_name, count(*)::bigint as orphan_project_id_count
from public.project_evaluations pe
left join public.projects p on p.id = pe.project_id
where pe.project_id is not null and p.id is null
union all
select 'project_costs', count(*)::bigint
from public.project_costs pc
left join public.projects p on p.id = pc.project_id
where pc.project_id is not null and p.id is null
union all
select 'project_cost_items', count(*)::bigint
from public.project_cost_items pci
left join public.projects p on p.id = pci.project_id
where pci.project_id is not null and p.id is null
union all
select 'project_cast_costs', count(*)::bigint
from public.project_cast_costs pcc
left join public.projects p on p.id = pcc.project_id
where pcc.project_id is not null and p.id is null
union all
select 'project_revenues', count(*)::bigint
from public.project_revenues pr
left join public.projects p on p.id = pr.project_id
where pr.project_id is not null and p.id is null
union all
select 'project_festival_records', count(*)::bigint
from public.project_festival_records pfr
left join public.projects p on p.id = pfr.project_id
where pfr.project_id is not null and p.id is null
union all
select 'project_source_links', count(*)::bigint
from public.project_source_links psl
left join public.projects p on p.id = psl.project_id
where psl.project_id is not null and p.id is null
union all
select 'external_import_field_mappings', count(*)::bigint
from public.external_import_field_mappings eifm
left join public.projects p on p.id = eifm.project_id
where eifm.project_id is not null and p.id is null
union all
select 'external_import_audit_logs', count(*)::bigint
from public.external_import_audit_logs eial
left join public.projects p on p.id = eial.project_id
where eial.project_id is not null and p.id is null
union all
select 'reports', count(*)::bigint
from public.reports r
left join public.projects p on p.id = r.project_id
where r.project_id is not null and p.id is null
union all
select 'plan_projects', count(*)::bigint
from public.plan_projects pp
left join public.projects p on p.id = pp.project_id
where pp.project_id is not null and p.id is null
order by table_name;

-- 5. Orphan plan_id and evaluation_id checks.
select 'plan_kpi_snapshots.plan_id' as table_name, count(*)::bigint as orphan_count
from public.plan_kpi_snapshots pks
left join public.investment_plans ip on ip.id = pks.plan_id
where pks.plan_id is not null and ip.id is null
union all
select 'plan_projects.plan_id', count(*)::bigint
from public.plan_projects pp
left join public.investment_plans ip on ip.id = pp.plan_id
where pp.plan_id is not null and ip.id is null
union all
select 'reports.plan_id', count(*)::bigint
from public.reports r
left join public.investment_plans ip on ip.id = r.plan_id
where r.plan_id is not null and ip.id is null
union all
select 'plan_projects.evaluation_id', count(*)::bigint
from public.plan_projects pp
left join public.project_evaluations pe on pe.id = pp.evaluation_id
where pp.evaluation_id is not null and pe.id is null
union all
select 'reports.evaluation_id', count(*)::bigint
from public.reports r
left join public.project_evaluations pe on pe.id = r.evaluation_id
where r.evaluation_id is not null and pe.id is null
order by table_name;

-- 6. Cross-org leakage risk checks based on currently derivable roots.
-- 6A. reports with mismatched project/evaluation lineage
select
  count(*)::bigint as reports_project_evaluation_mismatch_count
from public.reports r
join public.project_evaluations pe on pe.id = r.evaluation_id
where r.project_id is not null
  and pe.project_id is not null
  and r.project_id <> pe.project_id;

-- 6B. reports without any current tenant anchor
select
  count(*)::bigint as reports_without_project_plan_or_evaluation_anchor_count
from public.reports r
where r.project_id is null
  and r.plan_id is null
  and r.evaluation_id is null;

-- 6C. plan_projects where evaluation.project_id disagrees with project_id
select
  count(*)::bigint as plan_projects_project_evaluation_mismatch_count
from public.plan_projects pp
join public.project_evaluations pe on pe.id = pp.evaluation_id
where pp.project_id is not null
  and pe.project_id is not null
  and pp.project_id <> pe.project_id;

-- 6D. existence checks for missing tenant root columns that block future staged RLS.
select
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'investment_plans'
      and column_name = 'org_id'
  ) as investment_plans_has_org_id,
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reports'
      and column_name = 'org_id'
  ) as reports_has_org_id;
