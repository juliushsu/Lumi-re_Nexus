-- CIRQUA Sprint 2G
-- Read-only audit queries for public business tables, scope columns, RLS state,
-- policies, grants, FK relationships, and exact row/null counts.

-- 1. Table inventory with scope-column flags and RLS status.
with public_tables as (
  select
    t.table_schema,
    t.table_name
  from information_schema.tables t
  where t.table_schema = 'public'
    and t.table_type = 'BASE TABLE'
),
table_columns as (
  select
    c.table_schema,
    c.table_name,
    string_agg(c.column_name, ', ' order by c.ordinal_position) as columns_list,
    bool_or(c.column_name = 'org_id') as has_org_id,
    bool_or(c.column_name = 'project_id') as has_project_id
  from information_schema.columns c
  where c.table_schema = 'public'
  group by c.table_schema, c.table_name
)
select
  pt.table_name,
  coalesce(tc.has_org_id, false) as has_org_id,
  coalesce(tc.has_project_id, false) as has_project_id,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls,
  tc.columns_list
from public_tables pt
join pg_class c
  on c.relname = pt.table_name
join pg_namespace n
  on n.oid = c.relnamespace
 and n.nspname = pt.table_schema
left join table_columns tc
  on tc.table_schema = pt.table_schema
 and tc.table_name = pt.table_name
order by pt.table_name;

-- 2. Policy inventory for all public tables.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 3. Grant inventory for anon / authenticated / service_role.
select
  table_schema,
  table_name,
  grantee,
  string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated', 'service_role')
group by table_schema, table_name, grantee
order by table_name, grantee;

-- 4. Function execute grants for RPC / helper review.
select
  routine_schema,
  routine_name,
  grantee,
  string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.routine_privileges
where specific_schema = 'public'
  and grantee in ('anon', 'authenticated', 'service_role')
group by routine_schema, routine_name, grantee
order by routine_name, grantee;

-- 5. FK relationships for scope propagation review.
select
  tc.table_name,
  kcu.column_name,
  ccu.table_name as foreign_table_name,
  ccu.column_name as foreign_column_name,
  tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.table_schema = kcu.table_schema
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
 and ccu.table_schema = tc.table_schema
where tc.table_schema = 'public'
  and tc.constraint_type = 'FOREIGN KEY'
order by tc.table_name, kcu.column_name;

-- 6. Exact row counts for every public table.
with public_tables as (
  select table_name
  from information_schema.tables
  where table_schema = 'public'
    and table_type = 'BASE TABLE'
)
select
  pt.table_name,
  (
    xpath(
      '/row/cnt/text()',
      query_to_xml(
        format('select count(*) as cnt from public.%I', pt.table_name),
        false,
        true,
        ''
      )
    )
  )[1]::text::bigint as exact_row_count
from public_tables pt
order by pt.table_name;

-- 7. Exact null-counts for org_id / project_id wherever those columns exist.
with scope_columns as (
  select
    t.table_name,
    exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = t.table_name
        and c.column_name = 'org_id'
    ) as has_org_id,
    exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = t.table_name
        and c.column_name = 'project_id'
    ) as has_project_id
  from information_schema.tables t
  where t.table_schema = 'public'
    and t.table_type = 'BASE TABLE'
)
select
  sc.table_name,
  sc.has_org_id,
  sc.has_project_id,
  (
    xpath(
      '/row/cnt/text()',
      query_to_xml(
        format('select count(*) as cnt from public.%I', sc.table_name),
        false,
        true,
        ''
      )
    )
  )[1]::text::bigint as exact_row_count,
  case
    when sc.has_org_id then (
      xpath(
        '/row/cnt/text()',
        query_to_xml(
          format('select count(*) as cnt from public.%I where org_id is null', sc.table_name),
          false,
          true,
          ''
        )
      )
    )[1]::text::bigint
    else null
  end as null_org_id_count,
  case
    when sc.has_project_id then (
      xpath(
        '/row/cnt/text()',
        query_to_xml(
          format('select count(*) as cnt from public.%I where project_id is null', sc.table_name),
          false,
          true,
          ''
        )
      )
    )[1]::text::bigint
    else null
  end as null_project_id_count
from scope_columns sc
where sc.has_org_id or sc.has_project_id
order by sc.table_name;

-- 8. Quick-check rows for core tenant roots after Sprint 2F.
select
  (select count(*) from public.organizations) as organizations_count,
  (select count(*) from public.user_profiles) as user_profiles_count,
  (select count(*) from public.user_profiles where org_id is null) as user_profiles_null_org_id_count,
  (select count(*) from public.projects) as projects_count,
  (select count(*) from public.projects where org_id is null) as projects_null_org_id_count;
