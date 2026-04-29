-- CIRQUA Sprint 2J
-- Read-only verification query for investment_plans / reports tenant-root design.

-- 1. Row counts for the four target tables.
select 'investment_plans' as table_name, count(*)::bigint as row_count from public.investment_plans
union all
select 'reports', count(*)::bigint from public.reports
union all
select 'plan_projects', count(*)::bigint from public.plan_projects
union all
select 'plan_kpi_snapshots', count(*)::bigint from public.plan_kpi_snapshots
order by table_name;

-- 2. Existence checks for future tenant-root columns.
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

-- 3. Null org_id counts if the columns exist in a future staging pass.
with column_presence as (
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
    ) as reports_has_org_id
)
select
  case
    when cp.investment_plans_has_org_id then (select count(*)::bigint from public.investment_plans where org_id is null)
    else null
  end as investment_plans_null_org_id_count,
  case
    when cp.reports_has_org_id then (select count(*)::bigint from public.reports where org_id is null)
    else null
  end as reports_null_org_id_count
from column_presence cp;

-- 4. Null key status for existing lineage columns.
select 'reports.project_id_null' as metric, count(*) filter (where project_id is null)::bigint as value from public.reports
union all
select 'reports.plan_id_null', count(*) filter (where plan_id is null)::bigint from public.reports
union all
select 'reports.evaluation_id_null', count(*) filter (where evaluation_id is null)::bigint from public.reports
union all
select 'plan_projects.project_id_null', count(*) filter (where project_id is null)::bigint from public.plan_projects
union all
select 'plan_projects.plan_id_null', count(*) filter (where plan_id is null)::bigint from public.plan_projects
union all
select 'plan_projects.evaluation_id_null', count(*) filter (where evaluation_id is null)::bigint from public.plan_projects
union all
select 'plan_kpi_snapshots.plan_id_null', count(*) filter (where plan_id is null)::bigint from public.plan_kpi_snapshots
order by metric;

-- 5. Orphan lineage checks.
select 'reports.project_id_orphan' as metric, count(*)::bigint as value
from public.reports r
left join public.projects p on p.id = r.project_id
where r.project_id is not null and p.id is null
union all
select 'reports.plan_id_orphan', count(*)::bigint
from public.reports r
left join public.investment_plans ip on ip.id = r.plan_id
where r.plan_id is not null and ip.id is null
union all
select 'reports.evaluation_id_orphan', count(*)::bigint
from public.reports r
left join public.project_evaluations pe on pe.id = r.evaluation_id
where r.evaluation_id is not null and pe.id is null
union all
select 'plan_projects.project_id_orphan', count(*)::bigint
from public.plan_projects pp
left join public.projects p on p.id = pp.project_id
where pp.project_id is not null and p.id is null
union all
select 'plan_projects.plan_id_orphan', count(*)::bigint
from public.plan_projects pp
left join public.investment_plans ip on ip.id = pp.plan_id
where pp.plan_id is not null and ip.id is null
union all
select 'plan_projects.evaluation_id_orphan', count(*)::bigint
from public.plan_projects pp
left join public.project_evaluations pe on pe.id = pp.evaluation_id
where pp.evaluation_id is not null and pe.id is null
union all
select 'plan_kpi_snapshots.plan_id_orphan', count(*)::bigint
from public.plan_kpi_snapshots pks
left join public.investment_plans ip on ip.id = pks.plan_id
where pks.plan_id is not null and ip.id is null
order by metric;

-- 6. Report consistency checks.
select
  count(*)::bigint as reports_project_evaluation_mismatch_count
from public.reports r
join public.project_evaluations pe on pe.id = r.evaluation_id
where r.project_id is not null
  and pe.project_id is not null
  and r.project_id <> pe.project_id;

select
  count(*)::bigint as reports_without_project_plan_or_evaluation_anchor_count
from public.reports r
where r.project_id is null
  and r.plan_id is null
  and r.evaluation_id is null;

-- 7. Plan consistency checks.
select
  count(*)::bigint as plan_projects_project_evaluation_mismatch_count
from public.plan_projects pp
join public.project_evaluations pe on pe.id = pp.evaluation_id
where pp.project_id is not null
  and pe.project_id is not null
  and pp.project_id <> pe.project_id;

-- 8. Future org consistency check once org_id exists on roots.
-- Keep commented until columns are added.

-- select
--   count(*)::bigint as reports_project_org_mismatch_count
-- from public.reports r
-- join public.projects p on p.id = r.project_id
-- where r.org_id is not null
--   and p.org_id is not null
--   and r.org_id <> p.org_id;

-- select
--   count(*)::bigint as plan_projects_plan_org_mismatch_count
-- from public.plan_projects pp
-- join public.investment_plans ip on ip.id = pp.plan_id
-- join public.projects p on p.id = pp.project_id
-- where ip.org_id is not null
--   and p.org_id is not null
--   and ip.org_id <> p.org_id;
