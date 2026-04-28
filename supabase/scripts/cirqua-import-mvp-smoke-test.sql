-- CIRQUA Import MVP smoke test
-- Purpose:
-- Validate the executable CIRQUA MVP pipeline in staging without any
-- real CIRQUA token or external API connectivity.
--
-- This script is intended to run in a privileged staging SQL context
-- such as Supabase SQL Editor (`postgres`) or a service-role backend path.
-- It creates test rows inside a transaction and rolls everything back.

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

-- 3. All required functions exist
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
      ('mark_cirqua_import_snapshot_received'),
      ('propose_cirqua_field_mappings'),
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
    raise exception 'Missing CIRQUA executable pipeline functions. Missing count: %', missing_count;
  end if;
end
$$;

-- 4. Direct DML on raw CIRQUA tables has been revoked for authenticated
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

-- 5. Service-only functions are not executable by authenticated
do $$
begin
  if has_function_privilege(
    'authenticated',
    'public.mark_cirqua_import_snapshot_received(uuid, jsonb, jsonb)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated should not have EXECUTE on mark_cirqua_import_snapshot_received';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.propose_cirqua_field_mappings(uuid)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated should not have EXECUTE on propose_cirqua_field_mappings';
  end if;
end
$$;

-- 6. Full executable pipeline smoke test
do $$
declare
  v_project_id uuid := gen_random_uuid();
  v_link_id uuid;
  v_pre_consent_run_id uuid;
  v_ready_run_id uuid;
  v_mapping_rec record;
  v_evaluation_id uuid;
  v_result jsonb;
  v_mapping_count integer;
  v_audit_count integer;
begin
  insert into public.projects (
    id,
    project_code,
    project_name_zh,
    project_name_en,
    project_type,
    genre,
    region,
    language,
    status,
    total_budget
  )
  values (
    v_project_id,
    concat('CIRQUA-SMOKE-', substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    'CIRQUA 測試專案',
    'CIRQUA Smoke Project',
    'feature_film',
    'drama',
    'TW',
    'Mandarin',
    'development',
    12000000
  );

  v_result := public.create_cirqua_project_link(
    v_project_id,
    concat('cirqua-demo-', substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    '{"project_profile": true, "budget_summary": true}'::jsonb
  );

  v_link_id := (v_result ->> 'project_source_link_id')::uuid;

  if v_link_id is null then
    raise exception 'create_cirqua_project_link did not return link id';
  end if;

  v_result := public.create_cirqua_import_run(v_link_id);
  v_pre_consent_run_id := (v_result ->> 'import_run_id')::uuid;

  if v_result ->> 'import_status' <> 'consent_required' then
    raise exception 'Expected pre-consent import run to be consent_required, got %', v_result ->> 'import_status';
  end if;

  v_result := public.grant_cirqua_consent(
    v_link_id,
    '{"project_profile": true, "budget_summary": true}'::jsonb,
    now() + interval '7 days'
  );

  if v_result ->> 'consent_status' <> 'granted' then
    raise exception 'Expected consent_status granted, got %', v_result ->> 'consent_status';
  end if;

  v_result := public.create_cirqua_import_run(v_link_id);
  v_ready_run_id := (v_result ->> 'import_run_id')::uuid;

  if v_result ->> 'import_status' <> 'ready_to_import' then
    raise exception 'Expected ready_to_import, got %', v_result ->> 'import_status';
  end if;

  v_result := public.mark_cirqua_import_snapshot_received(
    v_ready_run_id,
    '{
      "project_name_zh": "匯入測試片名",
      "project_name_en": "Imported Smoke Title",
      "project_type": "feature_film",
      "genre": "thriller",
      "region": "TW",
      "language": "Mandarin"
    }'::jsonb,
    '{
      "currency": "TWD",
      "budget_total": 18000000,
      "above_the_line_total": 3500000,
      "below_the_line_total": 12000000,
      "contingency_total": 2500000
    }'::jsonb
  );

  if v_result ->> 'import_status' <> 'imported' then
    raise exception 'Expected imported after snapshot receipt, got %', v_result ->> 'import_status';
  end if;

  v_result := public.propose_cirqua_field_mappings(v_ready_run_id);

  if v_result ->> 'import_status' <> 'mapping_required' then
    raise exception 'Expected mapping_required after proposal, got %', v_result ->> 'import_status';
  end if;

  select count(*)
  into v_mapping_count
  from public.external_import_field_mappings
  where import_run_id = v_ready_run_id;

  if v_mapping_count = 0 then
    raise exception 'Expected proposed mappings but found none';
  end if;

  for v_mapping_rec in
    select id
    from public.external_import_field_mappings
    where import_run_id = v_ready_run_id
      and mapping_status = 'pending_review'
  loop
    v_result := public.approve_cirqua_field_mapping(v_mapping_rec.id, 'Smoke test approval');
  end loop;

  if v_result ->> 'import_run_status' <> 'approved' then
    raise exception 'Expected import run to be approved after mapping approvals, got %', v_result ->> 'import_run_status';
  end if;

  v_result := public.generate_project_evaluation_baseline_from_cirqua(v_ready_run_id);
  v_evaluation_id := (v_result ->> 'project_evaluation_id')::uuid;

  if v_evaluation_id is null then
    raise exception 'Expected project_evaluation_id from baseline generation';
  end if;

  if v_result ->> 'evaluation_status' <> 'draft' then
    raise exception 'Expected draft evaluation status, got %', v_result ->> 'evaluation_status';
  end if;

  select count(*)
  into v_audit_count
  from public.external_import_audit_logs
  where import_run_id = v_ready_run_id
    and event_type in (
      'create_import_run',
      'import_snapshot',
      'propose_mapping',
      'approve_mapping',
      'generate_baseline'
    );

  if v_audit_count < 5 then
    raise exception 'Expected at least 5 audit events for full pipeline, found %', v_audit_count;
  end if;
end
$$;

-- 7. Output verification markers for operators
select
  'validated_function' as item_type,
  fn_name as item_name
from (
  values
    ('create_cirqua_project_link'),
    ('grant_cirqua_consent'),
    ('create_cirqua_import_run'),
    ('mark_cirqua_import_snapshot_received'),
    ('propose_cirqua_field_mappings'),
    ('approve_cirqua_field_mapping'),
    ('reject_cirqua_field_mapping'),
    ('generate_project_evaluation_baseline_from_cirqua')
) as expected(fn_name);

rollback;

-- Expected manual role checks after this script passes
-- ---------------------------------------------------
-- 1. As shareholder_viewer:
--    attempt any CIRQUA RPC
--    expect authorization failure
--
-- 2. As analyst:
--    attempt grant_cirqua_consent(...)
--    expect authorization failure
--
-- 3. As analyst:
--    create import run after valid consent
--    expect success
--
-- 4. As analyst:
--    approve/reject mappings
--    expect success
--
-- 5. As analyst:
--    generate baseline only after all mappings approved
--    expect new project_evaluations draft
