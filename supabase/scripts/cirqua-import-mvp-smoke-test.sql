-- CIRQUA Import MVP smoke test
-- Purpose:
-- Validate that the current MVP data layer and implemented RPC layer
-- are present and aligned with the staged service contract.
--
-- This script does not require real CIRQUA tokens and does not call
-- external APIs. It is a contract-validation and schema-readiness script.

begin;

-- 1. Required CIRQUA MVP tables exist
do $$
declare
  missing_count integer;
begin
  select count(*)
  into missing_count
  from (
    values
      ('project_source_links'),
      ('external_import_runs'),
      ('external_project_snapshots'),
      ('external_budget_snapshots'),
      ('external_import_field_mappings'),
      ('external_import_audit_logs')
  ) as required_tables(table_name)
  where not exists (
    select 1
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_name = required_tables.table_name
  );

  if missing_count <> 0 then
    raise exception 'Missing CIRQUA MVP tables. Missing count: %', missing_count;
  end if;
end
$$;

-- 2. RLS is enabled on all CIRQUA MVP tables
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
      'project_source_links',
      'external_import_runs',
      'external_project_snapshots',
      'external_budget_snapshots',
      'external_import_field_mappings',
      'external_import_audit_logs'
    )
    and c.relrowsecurity = false;

  if disabled_count <> 0 then
    raise exception 'One or more CIRQUA MVP tables do not have RLS enabled. Disabled count: %', disabled_count;
  end if;
end
$$;

-- 3. Critical enum-like checks exist in schema
do $$
declare
  bad_count integer;
begin
  select count(*)
  into bad_count
  from public.project_source_links
  where source_system <> 'cirqua';

  if bad_count <> 0 then
    raise exception 'Found non-cirqua source_system values in project_source_links.';
  end if;
end
$$;

-- 4. Contract-required columns exist for consent and import state
do $$
declare
  missing_count integer;
begin
  select count(*)
  into missing_count
  from (
    values
      ('project_source_links', 'consent_status'),
      ('project_source_links', 'consent_scope_json'),
      ('project_source_links', 'consent_granted_by'),
      ('project_source_links', 'consent_granted_at'),
      ('external_import_runs', 'import_status'),
      ('external_import_runs', 'baseline_generated_by'),
      ('external_import_runs', 'baseline_generated_at'),
      ('external_import_runs', 'baseline_project_evaluation_id'),
      ('external_import_audit_logs', 'event_type')
  ) as required_cols(table_name, column_name)
  where not exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = required_cols.table_name
      and c.column_name = required_cols.column_name
  );

  if missing_count <> 0 then
    raise exception 'Missing required CIRQUA contract columns. Missing count: %', missing_count;
  end if;
end
$$;

-- 5. Implemented RPC functions exist
do $$
declare
  missing_count integer;
begin
  select count(*)
  into missing_count
  from (
    values
      ('create_cirqua_project_link'),
      ('grant_cirqua_consent'),
      ('create_cirqua_import_run'),
      ('approve_cirqua_field_mapping'),
      ('reject_cirqua_field_mapping'),
      ('generate_project_evaluation_baseline_from_cirqua')
  ) as required_functions(function_name)
  where not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = required_functions.function_name
  );

  if missing_count <> 0 then
    raise exception 'Missing implemented CIRQUA RPC functions. Missing count: %', missing_count;
  end if;
end
$$;

-- 6. Service-only functions remain intentionally unimplemented
select
  'service_only_contract' as item_type,
  fn_name as item_name
from (
  values
    ('mark_cirqua_import_snapshot_received'),
    ('propose_cirqua_field_mappings')
) as expected(fn_name);

-- 7. Authenticated direct DML on raw CIRQUA tables has been revoked
do $$
declare
  unsafe_grant_count integer;
begin
  select count(*)
  into unsafe_grant_count
  from information_schema.role_table_grants g
  where g.grantee = 'authenticated'
    and g.table_schema = 'public'
    and g.table_name in (
      'project_source_links',
      'external_import_runs',
      'external_project_snapshots',
      'external_budget_snapshots',
      'external_import_field_mappings',
      'external_import_audit_logs'
    )
    and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE');

  if unsafe_grant_count <> 0 then
    raise exception 'Authenticated still has direct DML grants on CIRQUA raw tables. Count: %', unsafe_grant_count;
  end if;
end
$$;

-- 8. Manual verification order for implemented RPC layer
select
  'manual_smoke_order' as item_type,
  step_name as item_name
from (
  values
    ('create_cirqua_project_link'),
    ('grant_cirqua_consent'),
    ('create_cirqua_import_run'),
    ('service_only_snapshot_receive'),
    ('service_only_mapping_proposal'),
    ('approve_or_reject_mappings'),
    ('generate_project_evaluation_baseline_from_cirqua')
) as steps(step_name);

rollback;

-- Manual smoke test order after RPC implementation
-- ------------------------------------------------
-- 1. As super_admin:
--    call create_cirqua_project_link(...)
--    expect consent_status = 'pending'
--    expect audit event `create_project_link`
--
-- 2. As analyst:
--    call create_cirqua_import_run(...) before consent
--    expect `consent_required`
--    expect audit event `create_import_run`
--
-- 3. As super_admin:
--    call grant_cirqua_consent(...)
--    expect consent_status = 'granted'
--    expect audit event `grant_consent`
--
-- 4. As analyst:
--    call create_cirqua_import_run(...)
--    expect status = `ready_to_import`
--
-- 5. As backend/service:
--    perform snapshot insert flow through service-only contract
--    expect run status moves to `imported`
--    expect audit event `import_snapshot`
--
-- 6. As backend/service:
--    perform mapping proposal flow
--    expect run status moves to `mapping_required`
--    expect pending mappings created
--
-- 7. As analyst:
--    call approve_cirqua_field_mapping(...) and/or reject_cirqua_field_mapping(...)
--    expect audit event per decision
--    expect run status becomes `approved` or `rejected`
--
-- 8. As shareholder_viewer:
--    attempt any CIRQUA RPC
--    expect authorization failure
--
-- 9. As analyst or super_admin:
--    call generate_project_evaluation_baseline_from_cirqua(...)
--    only after `approved`
--    expect new `project_evaluations` draft
--    expect audit event `generate_baseline`
