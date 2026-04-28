begin;

create schema if not exists app;

create or replace function app.assert_cirqua_role(required_roles text[])
returns void
language plpgsql
security definer
set search_path = public, app
as $$
begin
  if session_user = 'postgres' or auth.role() = 'service_role' then
    return;
  end if;

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not app.has_any_role(required_roles) then
    raise exception 'Insufficient CIRQUA RPC permissions for role %', app.current_profile_role();
  end if;
end;
$$;

create or replace function app.assert_cirqua_service_or_super_admin()
returns void
language plpgsql
security definer
set search_path = public, app
as $$
begin
  if session_user = 'postgres' or auth.role() = 'service_role' then
    return;
  end if;

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not app.has_role('super_admin') then
    raise exception 'Service-only CIRQUA function requires super_admin or backend/service execution path';
  end if;
end;
$$;

create or replace function public.mark_cirqua_import_snapshot_received(
  p_import_run_id uuid,
  p_project_snapshot_json jsonb,
  p_budget_snapshot_json jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_run public.external_import_runs%rowtype;
  v_link public.project_source_links%rowtype;
  v_project_snapshot_id uuid;
  v_budget_snapshot_id uuid;
  v_project_snapshot_created boolean := false;
  v_budget_snapshot_created boolean := false;
  v_snapshot_version text;
begin
  perform app.assert_cirqua_service_or_super_admin();

  if p_import_run_id is null then
    raise exception 'import_run_id is required';
  end if;

  if coalesce(p_project_snapshot_json, '{}'::jsonb) = '{}'::jsonb
     and coalesce(p_budget_snapshot_json, '{}'::jsonb) = '{}'::jsonb then
    raise exception 'At least one snapshot payload is required';
  end if;

  select *
  into v_run
  from public.external_import_runs
  where id = p_import_run_id
    and source_system = 'cirqua'
  for update;

  if v_run.id is null then
    raise exception 'CIRQUA import run not found';
  end if;

  if v_run.import_status <> 'ready_to_import' then
    raise exception 'Import run status % does not allow snapshot receipt', v_run.import_status;
  end if;

  select *
  into v_link
  from public.project_source_links
  where id = v_run.project_source_link_id
  for update;

  if v_link.id is null then
    raise exception 'Linked CIRQUA project_source_link not found';
  end if;

  if not app.is_cirqua_consent_valid(v_link.id) then
    update public.external_import_runs
    set
      import_status = 'failed',
      failure_reason = 'Consent invalid at snapshot receipt time',
      updated_at = now()
    where id = v_run.id
    returning * into v_run;

    perform app.write_cirqua_audit_log(
      v_link.project_id,
      v_link.id,
      v_run.id,
      'mark_failed',
      jsonb_build_object(
        'previous_status', 'ready_to_import',
        'new_status', v_run.import_status,
        'note', 'Consent invalid at snapshot receipt time'
      )
    );

    raise exception 'consent_invalid';
  end if;

  v_snapshot_version := coalesce(v_run.snapshot_version, concat('cirqua-mvp-', to_char(now(), 'YYYYMMDDHH24MISS')));

  if coalesce(p_project_snapshot_json, '{}'::jsonb) <> '{}'::jsonb then
    insert into public.external_project_snapshots (
      import_run_id,
      project_source_link_id,
      source_system,
      snapshot_type,
      external_payload_json,
      normalized_payload_json,
      imported_by
    )
    values (
      v_run.id,
      v_link.id,
      'cirqua',
      'project_profile',
      p_project_snapshot_json,
      p_project_snapshot_json,
      auth.uid()
    )
    returning id into v_project_snapshot_id;

    v_project_snapshot_created := true;
  end if;

  if coalesce(p_budget_snapshot_json, '{}'::jsonb) <> '{}'::jsonb then
    insert into public.external_budget_snapshots (
      import_run_id,
      project_source_link_id,
      source_system,
      snapshot_type,
      currency,
      budget_total,
      above_the_line_total,
      below_the_line_total,
      contingency_total,
      normalized_payload_json,
      imported_by
    )
    values (
      v_run.id,
      v_link.id,
      'cirqua',
      'budget_summary',
      p_budget_snapshot_json ->> 'currency',
      nullif(p_budget_snapshot_json ->> 'budget_total', '')::numeric,
      nullif(p_budget_snapshot_json ->> 'above_the_line_total', '')::numeric,
      nullif(p_budget_snapshot_json ->> 'below_the_line_total', '')::numeric,
      nullif(p_budget_snapshot_json ->> 'contingency_total', '')::numeric,
      p_budget_snapshot_json,
      auth.uid()
    )
    returning id into v_budget_snapshot_id;

    v_budget_snapshot_created := true;
  end if;

  update public.external_import_runs
  set
    import_status = 'imported',
    snapshot_version = v_snapshot_version,
    started_at = coalesce(started_at, now()),
    completed_at = now(),
    updated_at = now(),
    failure_reason = null
  where id = v_run.id
  returning * into v_run;

  update public.project_source_links
  set
    last_imported_at = now(),
    updated_at = now()
  where id = v_link.id;

  perform app.write_cirqua_audit_log(
    v_link.project_id,
    v_link.id,
    v_run.id,
    'import_snapshot',
    jsonb_build_object(
      'previous_status', 'ready_to_import',
      'new_status', v_run.import_status,
      'snapshot_version', v_run.snapshot_version,
      'project_snapshot_created', v_project_snapshot_created,
      'budget_snapshot_created', v_budget_snapshot_created
    )
  );

  return jsonb_build_object(
    'import_run_id', v_run.id,
    'import_status', v_run.import_status,
    'snapshot_version', v_run.snapshot_version,
    'project_snapshot_created', v_project_snapshot_created,
    'budget_snapshot_created', v_budget_snapshot_created,
    'project_snapshot_id', v_project_snapshot_id,
    'budget_snapshot_id', v_budget_snapshot_id
  );
end;
$$;

create or replace function public.propose_cirqua_field_mappings(
  p_import_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_run public.external_import_runs%rowtype;
  v_link public.project_source_links%rowtype;
  v_project public.projects%rowtype;
  v_project_snapshot public.external_project_snapshots%rowtype;
  v_budget_snapshot public.external_budget_snapshots%rowtype;
  v_mapping_count integer := 0;
begin
  perform app.assert_cirqua_service_or_super_admin();

  if p_import_run_id is null then
    raise exception 'import_run_id is required';
  end if;

  select *
  into v_run
  from public.external_import_runs
  where id = p_import_run_id
    and source_system = 'cirqua'
  for update;

  if v_run.id is null then
    raise exception 'CIRQUA import run not found';
  end if;

  if v_run.import_status <> 'imported' then
    raise exception 'Import run status % does not allow mapping proposal', v_run.import_status;
  end if;

  if exists (
    select 1
    from public.external_import_field_mappings
    where import_run_id = v_run.id
  ) then
    raise exception 'mappings_already_proposed';
  end if;

  select *
  into v_link
  from public.project_source_links
  where id = v_run.project_source_link_id;

  if v_link.id is null then
    raise exception 'Linked CIRQUA project_source_link not found';
  end if;

  select *
  into v_project
  from public.projects
  where id = v_link.project_id;

  if v_project.id is null then
    raise exception 'project_not_found';
  end if;

  select *
  into v_project_snapshot
  from public.external_project_snapshots
  where import_run_id = v_run.id
  order by created_at desc
  limit 1;

  select *
  into v_budget_snapshot
  from public.external_budget_snapshots
  where import_run_id = v_run.id
  order by created_at desc
  limit 1;

  if v_project_snapshot.id is not null then
    if coalesce(v_project_snapshot.normalized_payload_json ->> 'project_name_zh', '') <> '' then
      insert into public.external_import_field_mappings (
        import_run_id, project_id, source_system, snapshot_type, source_field, target_table, target_field,
        proposed_value_json, current_value_json, mapping_status, created_by
      ) values (
        v_run.id, v_project.id, 'cirqua', 'project_profile', 'project_name_zh', 'project_evaluations', 'project_name_zh',
        to_jsonb(v_project_snapshot.normalized_payload_json ->> 'project_name_zh'),
        to_jsonb(v_project.project_name_zh),
        'pending_review',
        auth.uid()
      );
      v_mapping_count := v_mapping_count + 1;
    end if;

    if coalesce(v_project_snapshot.normalized_payload_json ->> 'project_name_en', '') <> '' then
      insert into public.external_import_field_mappings (
        import_run_id, project_id, source_system, snapshot_type, source_field, target_table, target_field,
        proposed_value_json, current_value_json, mapping_status, created_by
      ) values (
        v_run.id, v_project.id, 'cirqua', 'project_profile', 'project_name_en', 'project_evaluations', 'project_name_en',
        to_jsonb(v_project_snapshot.normalized_payload_json ->> 'project_name_en'),
        to_jsonb(v_project.project_name_en),
        'pending_review',
        auth.uid()
      );
      v_mapping_count := v_mapping_count + 1;
    end if;

    if coalesce(v_project_snapshot.normalized_payload_json ->> 'project_type', '') <> '' then
      insert into public.external_import_field_mappings (
        import_run_id, project_id, source_system, snapshot_type, source_field, target_table, target_field,
        proposed_value_json, current_value_json, mapping_status, created_by
      ) values (
        v_run.id, v_project.id, 'cirqua', 'project_profile', 'project_type', 'project_evaluations', 'project_type',
        to_jsonb(v_project_snapshot.normalized_payload_json ->> 'project_type'),
        to_jsonb(v_project.project_type),
        'pending_review',
        auth.uid()
      );
      v_mapping_count := v_mapping_count + 1;
    end if;

    if coalesce(v_project_snapshot.normalized_payload_json ->> 'genre', '') <> '' then
      insert into public.external_import_field_mappings (
        import_run_id, project_id, source_system, snapshot_type, source_field, target_table, target_field,
        proposed_value_json, current_value_json, mapping_status, created_by
      ) values (
        v_run.id, v_project.id, 'cirqua', 'project_profile', 'genre', 'project_evaluations', 'genre',
        to_jsonb(v_project_snapshot.normalized_payload_json ->> 'genre'),
        to_jsonb(v_project.genre),
        'pending_review',
        auth.uid()
      );
      v_mapping_count := v_mapping_count + 1;
    end if;

    if coalesce(v_project_snapshot.normalized_payload_json ->> 'region', '') <> '' then
      insert into public.external_import_field_mappings (
        import_run_id, project_id, source_system, snapshot_type, source_field, target_table, target_field,
        proposed_value_json, current_value_json, mapping_status, created_by
      ) values (
        v_run.id, v_project.id, 'cirqua', 'project_profile', 'region', 'project_evaluations', 'region',
        to_jsonb(v_project_snapshot.normalized_payload_json ->> 'region'),
        to_jsonb(v_project.region),
        'pending_review',
        auth.uid()
      );
      v_mapping_count := v_mapping_count + 1;
    end if;

    if coalesce(v_project_snapshot.normalized_payload_json ->> 'language', '') <> '' then
      insert into public.external_import_field_mappings (
        import_run_id, project_id, source_system, snapshot_type, source_field, target_table, target_field,
        proposed_value_json, current_value_json, mapping_status, created_by
      ) values (
        v_run.id, v_project.id, 'cirqua', 'project_profile', 'language', 'project_evaluations', 'language',
        to_jsonb(v_project_snapshot.normalized_payload_json ->> 'language'),
        to_jsonb(v_project.language),
        'pending_review',
        auth.uid()
      );
      v_mapping_count := v_mapping_count + 1;
    end if;
  end if;

  if v_budget_snapshot.id is not null and v_budget_snapshot.budget_total is not null then
    insert into public.external_import_field_mappings (
      import_run_id, project_id, source_system, snapshot_type, source_field, target_table, target_field,
      proposed_value_json, current_value_json, mapping_status, created_by
    ) values (
      v_run.id, v_project.id, 'cirqua', 'budget_summary', 'budget_total', 'project_evaluations', 'estimated_budget',
      to_jsonb(v_budget_snapshot.budget_total),
      to_jsonb(v_project.total_budget),
      'pending_review',
      auth.uid()
    );
    v_mapping_count := v_mapping_count + 1;
  end if;

  if v_mapping_count = 0 then
    update public.external_import_runs
    set
      import_status = 'failed',
      failure_reason = 'No mappable CIRQUA fields found in imported snapshots',
      updated_at = now()
    where id = v_run.id
    returning * into v_run;

    perform app.write_cirqua_audit_log(
      v_project.id,
      v_link.id,
      v_run.id,
      'mark_failed',
      jsonb_build_object(
        'previous_status', 'imported',
        'new_status', v_run.import_status,
        'note', 'No mappable CIRQUA fields found in imported snapshots'
      )
    );

    raise exception 'No mappable CIRQUA fields found in imported snapshots';
  end if;

  update public.external_import_runs
  set
    import_status = 'mapping_required',
    updated_at = now()
  where id = v_run.id
  returning * into v_run;

  perform app.write_cirqua_audit_log(
    v_project.id,
    v_link.id,
    v_run.id,
    'propose_mapping',
    jsonb_build_object(
      'previous_status', 'imported',
      'new_status', v_run.import_status,
      'proposed_mapping_count', v_mapping_count
    )
  );

  return jsonb_build_object(
    'import_run_id', v_run.id,
    'import_status', v_run.import_status,
    'proposed_mapping_count', v_mapping_count
  );
end;
$$;

revoke all on function app.assert_cirqua_service_or_super_admin() from public, anon, authenticated;
revoke all on function public.mark_cirqua_import_snapshot_received(uuid, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.propose_cirqua_field_mappings(uuid) from public, anon, authenticated;

grant execute on function public.mark_cirqua_import_snapshot_received(uuid, jsonb, jsonb) to service_role;
grant execute on function public.propose_cirqua_field_mappings(uuid) to service_role;

comment on function public.mark_cirqua_import_snapshot_received(uuid, jsonb, jsonb) is 'Service-only CIRQUA pipeline function. Receives imported snapshots without touching canonical projects.';
comment on function public.propose_cirqua_field_mappings(uuid) is 'Service-only CIRQUA pipeline function. Generates pending_review mappings from imported snapshots.';

commit;
