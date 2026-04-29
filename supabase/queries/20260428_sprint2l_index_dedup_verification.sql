-- CIRQUA Sprint 2L
-- Read-only verification query for duplicate index detection and tenant-root correction status.

-- 1. Row counts for target tables.
select 'investment_plans' as table_name, count(*)::bigint as row_count from public.investment_plans
union all
select 'reports', count(*)::bigint from public.reports
union all
select 'plan_projects', count(*)::bigint from public.plan_projects
union all
select 'plan_kpi_snapshots', count(*)::bigint from public.plan_kpi_snapshots
order by table_name;

-- 2. Tenant root column presence.
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

-- 3. FK validity status for tenant-root related constraints.
select
  conrelid::regclass::text as table_name,
  conname as constraint_name,
  contype,
  convalidated,
  pg_get_constraintdef(oid) as constraint_def
from pg_constraint
where conname in (
  'investment_plans_org_id_fkey',
  'reports_org_id_fkey',
  'reports_project_id_fkey',
  'reports_plan_id_fkey',
  'reports_evaluation_id_fkey',
  'plan_projects_plan_id_fkey',
  'plan_projects_project_id_fkey',
  'plan_projects_evaluation_id_fkey',
  'plan_kpi_snapshots_plan_id_fkey'
)
order by conrelid::regclass::text, conname;

-- 4. Duplicate index detection by exact indexed column list.
with idx as (
  select
    t.relname as table_name,
    i.relname as index_name,
    ix.indisprimary,
    ix.indisunique,
    pg_get_indexdef(i.oid) as index_def,
    coalesce(string_agg(a.attname, ', ' order by ord.ord), '') as index_columns
  from pg_class t
  join pg_namespace n on n.oid = t.relnamespace
  join pg_index ix on ix.indrelid = t.oid
  join pg_class i on i.oid = ix.indexrelid
  left join lateral unnest(ix.indkey) with ordinality as ord(attnum, ord) on true
  left join pg_attribute a on a.attrelid = t.oid and a.attnum = ord.attnum
  where n.nspname = 'public'
    and t.relname in ('investment_plans', 'reports', 'plan_projects', 'plan_kpi_snapshots')
  group by t.relname, i.relname, ix.indisprimary, ix.indisunique, i.oid
),
dup as (
  select
    table_name,
    index_columns,
    count(*) as duplicate_count,
    array_agg(index_name order by index_name) as duplicate_index_names
  from idx
  group by table_name, index_columns
  having count(*) > 1
)
select
  table_name,
  index_columns,
  duplicate_count,
  duplicate_index_names
from dup
order by table_name, index_columns;

-- 5. Full index listing for manual review.
select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in ('investment_plans', 'reports', 'plan_projects', 'plan_kpi_snapshots')
order by tablename, indexname;
