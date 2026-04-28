begin;

create schema if not exists app;

alter table public.external_import_audit_logs
  drop constraint if exists external_import_audit_logs_event_type_check;

alter table public.external_import_audit_logs
  add constraint external_import_audit_logs_event_type_check
  check (
    event_type in (
      'create_project_link',
      'create_import_run',
      'grant_consent',
      'revoke_consent',
      'expire_consent',
      'import_snapshot',
      'propose_mapping',
      'approve_mapping',
      'reject_mapping',
      'generate_baseline',
      'mark_failed'
    )
  );

revoke insert, update, delete on table public.project_source_links from authenticated;
revoke insert, update, delete on table public.external_import_runs from authenticated;
revoke insert, update, delete on table public.external_project_snapshots from authenticated;
revoke insert, update, delete on table public.external_budget_snapshots from authenticated;
revoke insert, update, delete on table public.external_import_field_mappings from authenticated;
revoke insert, update, delete on table public.external_import_audit_logs from authenticated;

create or replace function app.assert_cirqua_role(required_roles text[])
returns void
language plpgsql
security definer
set search_path = public, app
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not app.has_any_role(required_roles) then
    raise exception 'Insufficient CIRQUA RPC permissions for role %', app.current_profile_role();
  end if;
end;
$$;

create or replace function app.is_cirqua_consent_valid(p_project_source_link_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.project_source_links psl
    where psl.id = p_project_source_link_id
      and psl.source_system = 'cirqua'
      and psl.link_status = 'active'
      and psl.consent_status = 'granted'
      and (
        psl.consent_expires_at is null
        or psl.consent_expires_at > now()
      )
  )
$$;

create or replace function app.write_cirqua_audit_log(
  p_project_id uuid,
  p_project_source_link_id uuid,
  p_import_run_id uuid,
  p_event_type text,
  p_event_payload_json jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_audit_id uuid;
begin
  insert into public.external_import_audit_logs (
    project_id,
    project_source_link_id,
    import_run_id,
    source_system,
    event_type,
    actor_user_id,
    event_payload_json
  )
  values (
    p_project_id,
    p_project_source_link_id,
    p_import_run_id,
    'cirqua',
    p_event_type,
    auth.uid(),
    coalesce(p_event_payload_json, '{}'::jsonb)
      || jsonb_build_object(
        'source_system', 'cirqua',
        'actor_role', app.current_profile_role()
      )
  )
  returning id into v_audit_id;

  return v_audit_id;
end;
$$;

create or replace function public.create_cirqua_project_link(
  p_project_id uuid,
  p_external_project_id text,
  p_consent_scope_json jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_link public.project_source_links%rowtype;
begin
  perform app.assert_cirqua_role(array['super_admin']);

  if p_project_id is null then
    raise exception 'project_id is required';
  end if;

  if coalesce(nullif(trim(p_external_project_id), ''), '') = '' then
    raise exception 'external_project_id is required';
  end if;

  insert into public.project_source_links (
    project_id,
    source_system,
    external_project_id,
    link_status,
    consent_status,
    consent_scope_json,
    created_by
  )
  values (
    p_project_id,
    'cirqua',
    p_external_project_id,
    'active',
    'pending',
    coalesce(p_consent_scope_json, '{}'::jsonb),
    auth.uid()
  )
  returning * into v_link;

  perform app.write_cirqua_audit_log(
    v_link.project_id,
    v_link.id,
    null,
    'create_project_link',
    jsonb_build_object(
      'new_status', 'pending',
      'external_project_id', v_link.external_project_id
    )
  );

  return jsonb_build_object(
    'project_source_link_id', v_link.id,
    'project_id', v_link.project_id,
    'source_system', v_link.source_system,
    'consent_status', v_link.consent_status,
    'link_status', v_link.link_status
  );
end;
$$;

create or replace function public.grant_cirqua_consent(
  p_project_source_link_id uuid,
  p_consent_scope_json jsonb,
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_previous_status text;
  v_link public.project_source_links%rowtype;
begin
  perform app.assert_cirqua_role(array['super_admin']);

  if p_project_source_link_id is null then
    raise exception 'project_source_link_id is required';
  end if;

  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'expires_at must be in the future';
  end if;

  select consent_status
  into v_previous_status
  from public.project_source_links
  where id = p_project_source_link_id
    and source_system = 'cirqua'
  for update;

  if v_previous_status is null then
    raise exception 'CIRQUA project_source_link not found';
  end if;

  update public.project_source_links
  set
    consent_status = 'granted',
    consent_scope_json = coalesce(p_consent_scope_json, '{}'::jsonb),
    consent_granted_by = auth.uid(),
    consent_granted_at = now(),
    consent_expires_at = p_expires_at,
    consent_revoked_by = null,
    consent_revoked_at = null,
    updated_at = now()
  where id = p_project_source_link_id
  returning * into v_link;

  perform app.write_cirqua_audit_log(
    v_link.project_id,
    v_link.id,
    null,
    'grant_consent',
    jsonb_build_object(
      'previous_status', v_previous_status,
      'new_status', v_link.consent_status,
      'expires_at', v_link.consent_expires_at
    )
  );

  return jsonb_build_object(
    'project_source_link_id', v_link.id,
    'consent_status', v_link.consent_status,
    'consent_granted_at', v_link.consent_granted_at,
    'consent_expires_at', v_link.consent_expires_at
  );
end;
$$;

create or replace function public.create_cirqua_import_run(
  p_project_source_link_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_link public.project_source_links%rowtype;
  v_run public.external_import_runs%rowtype;
  v_status text;
  v_failure_reason text;
begin
  perform app.assert_cirqua_role(array['super_admin', 'analyst']);

  if p_project_source_link_id is null then
    raise exception 'project_source_link_id is required';
  end if;

  select *
  into v_link
  from public.project_source_links
  where id = p_project_source_link_id
    and source_system = 'cirqua'
  for update;

  if v_link.id is null then
    raise exception 'CIRQUA project_source_link not found';
  end if;

  if app.is_cirqua_consent_valid(v_link.id) then
    v_status := 'ready_to_import';
    v_failure_reason := null;
  else
    v_status := 'consent_required';
    v_failure_reason := 'Consent missing, revoked, expired, or invalid for CIRQUA import.';
  end if;

  insert into public.external_import_runs (
    project_source_link_id,
    source_system,
    import_status,
    requested_by,
    failure_reason
  )
  values (
    v_link.id,
    'cirqua',
    v_status,
    auth.uid(),
    v_failure_reason
  )
  returning * into v_run;

  perform app.write_cirqua_audit_log(
    v_link.project_id,
    v_link.id,
    v_run.id,
    'create_import_run',
    jsonb_build_object(
      'new_status', v_run.import_status,
      'failure_reason', v_run.failure_reason
    )
  );

  return jsonb_build_object(
    'import_run_id', v_run.id,
    'project_source_link_id', v_run.project_source_link_id,
    'import_status', v_run.import_status
  );
end;
$$;

create or replace function public.approve_cirqua_field_mapping(
  p_mapping_id uuid,
  p_approval_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_mapping public.external_import_field_mappings%rowtype;
  v_run public.external_import_runs%rowtype;
  v_pending_count integer;
  v_rejected_count integer;
  v_new_run_status text;
  v_previous_mapping_status text;
begin
  perform app.assert_cirqua_role(array['super_admin', 'analyst']);

  if p_mapping_id is null then
    raise exception 'mapping_id is required';
  end if;

  select *
  into v_mapping
  from public.external_import_field_mappings
  where id = p_mapping_id
    and source_system = 'cirqua'
  for update;

  if v_mapping.id is null then
    raise exception 'CIRQUA field mapping not found';
  end if;

  select *
  into v_run
  from public.external_import_runs
  where id = v_mapping.import_run_id
  for update;

  if v_run.import_status not in ('mapping_required', 'approved') then
    raise exception 'Import run status % does not allow mapping approval', v_run.import_status;
  end if;

  v_previous_mapping_status := v_mapping.mapping_status;

  update public.external_import_field_mappings
  set
    mapping_status = 'approved',
    approval_note = p_approval_note,
    approved_by = auth.uid(),
    approved_at = now(),
    rejected_by = null,
    rejected_at = null,
    updated_at = now()
  where id = v_mapping.id
  returning * into v_mapping;

  select count(*)
  into v_pending_count
  from public.external_import_field_mappings
  where import_run_id = v_run.id
    and mapping_status = 'pending_review';

  select count(*)
  into v_rejected_count
  from public.external_import_field_mappings
  where import_run_id = v_run.id
    and mapping_status = 'rejected';

  if v_pending_count = 0 and v_rejected_count = 0 then
    v_new_run_status := 'approved';
  else
    v_new_run_status := 'mapping_required';
  end if;

  update public.external_import_runs
  set
    import_status = v_new_run_status,
    approved_by = case when v_new_run_status = 'approved' then auth.uid() else approved_by end,
    approved_at = case when v_new_run_status = 'approved' then now() else approved_at end,
    updated_at = now()
  where id = v_run.id
  returning * into v_run;

  perform app.write_cirqua_audit_log(
    v_mapping.project_id,
    v_run.project_source_link_id,
    v_run.id,
    'approve_mapping',
    jsonb_build_object(
      'mapping_id', v_mapping.id,
      'previous_status', v_previous_mapping_status,
      'new_status', v_mapping.mapping_status,
      'import_run_status', v_run.import_status,
      'note', p_approval_note
    )
  );

  return jsonb_build_object(
    'mapping_id', v_mapping.id,
    'mapping_status', v_mapping.mapping_status,
    'import_run_status', v_run.import_status
  );
end;
$$;

create or replace function public.reject_cirqua_field_mapping(
  p_mapping_id uuid,
  p_approval_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_mapping public.external_import_field_mappings%rowtype;
  v_run public.external_import_runs%rowtype;
  v_previous_mapping_status text;
begin
  perform app.assert_cirqua_role(array['super_admin', 'analyst']);

  if p_mapping_id is null then
    raise exception 'mapping_id is required';
  end if;

  select *
  into v_mapping
  from public.external_import_field_mappings
  where id = p_mapping_id
    and source_system = 'cirqua'
  for update;

  if v_mapping.id is null then
    raise exception 'CIRQUA field mapping not found';
  end if;

  select *
  into v_run
  from public.external_import_runs
  where id = v_mapping.import_run_id
  for update;

  if v_run.import_status not in ('mapping_required', 'approved') then
    raise exception 'Import run status % does not allow mapping rejection', v_run.import_status;
  end if;

  v_previous_mapping_status := v_mapping.mapping_status;

  update public.external_import_field_mappings
  set
    mapping_status = 'rejected',
    approval_note = p_approval_note,
    rejected_by = auth.uid(),
    rejected_at = now(),
    approved_by = null,
    approved_at = null,
    updated_at = now()
  where id = v_mapping.id
  returning * into v_mapping;

  update public.external_import_runs
  set
    import_status = 'rejected',
    updated_at = now()
  where id = v_run.id
  returning * into v_run;

  perform app.write_cirqua_audit_log(
    v_mapping.project_id,
    v_run.project_source_link_id,
    v_run.id,
    'reject_mapping',
    jsonb_build_object(
      'mapping_id', v_mapping.id,
      'previous_status', v_previous_mapping_status,
      'new_status', v_mapping.mapping_status,
      'import_run_status', v_run.import_status,
      'note', p_approval_note
    )
  );

  return jsonb_build_object(
    'mapping_id', v_mapping.id,
    'mapping_status', v_mapping.mapping_status,
    'import_run_status', v_run.import_status
  );
end;
$$;

create or replace function public.generate_project_evaluation_baseline_from_cirqua(
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
  v_evaluation public.project_evaluations%rowtype;
  v_applied_count integer;
  v_project_name_zh text;
  v_project_name_en text;
  v_project_type text;
  v_genre text;
  v_region text;
  v_language text;
  v_estimated_budget numeric;
  v_expected_roi numeric;
  v_estimated_payback_period integer;
  v_completion_probability numeric;
  v_schedule_risk_score numeric;
  v_analyst_comment text;
begin
  perform app.assert_cirqua_role(array['super_admin', 'analyst']);

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

  if v_run.import_status <> 'approved' then
    raise exception 'Import run status % cannot generate baseline', v_run.import_status;
  end if;

  if v_run.baseline_project_evaluation_id is not null then
    raise exception 'baseline_already_generated';
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
    raise exception 'consent_invalid';
  end if;

  select *
  into v_project
  from public.projects
  where id = v_link.project_id;

  if v_project.id is null then
    raise exception 'project_not_found';
  end if;

  if exists (
    select 1
    from public.external_import_field_mappings
    where import_run_id = v_run.id
      and mapping_status = 'pending_review'
  ) then
    raise exception 'invalid_import_status: pending mappings remain';
  end if;

  select count(*)
  into v_applied_count
  from public.external_import_field_mappings
  where import_run_id = v_run.id
    and mapping_status = 'approved';

  if v_applied_count = 0 then
    raise exception 'no_approved_mappings';
  end if;

  select
    coalesce(
      (
        select proposed_value_json #>> '{}'
        from public.external_import_field_mappings
        where import_run_id = v_run.id
          and mapping_status = 'approved'
          and target_field = 'project_name_zh'
        order by created_at desc
        limit 1
      ),
      v_project.project_name_zh
    ),
    coalesce(
      (
        select proposed_value_json #>> '{}'
        from public.external_import_field_mappings
        where import_run_id = v_run.id
          and mapping_status = 'approved'
          and target_field = 'project_name_en'
        order by created_at desc
        limit 1
      ),
      v_project.project_name_en
    ),
    coalesce(
      (
        select proposed_value_json #>> '{}'
        from public.external_import_field_mappings
        where import_run_id = v_run.id
          and mapping_status = 'approved'
          and target_field = 'project_type'
        order by created_at desc
        limit 1
      ),
      v_project.project_type
    ),
    coalesce(
      (
        select proposed_value_json #>> '{}'
        from public.external_import_field_mappings
        where import_run_id = v_run.id
          and mapping_status = 'approved'
          and target_field = 'genre'
        order by created_at desc
        limit 1
      ),
      v_project.genre
    ),
    coalesce(
      (
        select proposed_value_json #>> '{}'
        from public.external_import_field_mappings
        where import_run_id = v_run.id
          and mapping_status = 'approved'
          and target_field = 'region'
        order by created_at desc
        limit 1
      ),
      v_project.region
    ),
    coalesce(
      (
        select proposed_value_json #>> '{}'
        from public.external_import_field_mappings
        where import_run_id = v_run.id
          and mapping_status = 'approved'
          and target_field = 'language'
        order by created_at desc
        limit 1
      ),
      v_project.language
    ),
    coalesce(
      (
        select (proposed_value_json #>> '{}')::numeric
        from public.external_import_field_mappings
        where import_run_id = v_run.id
          and mapping_status = 'approved'
          and target_field in ('estimated_budget', 'total_budget')
        order by created_at desc
        limit 1
      ),
      v_project.total_budget
    ),
    (
      select (proposed_value_json #>> '{}')::numeric
      from public.external_import_field_mappings
      where import_run_id = v_run.id
        and mapping_status = 'approved'
        and target_field = 'expected_roi'
      order by created_at desc
      limit 1
    ),
    (
      select (proposed_value_json #>> '{}')::integer
      from public.external_import_field_mappings
      where import_run_id = v_run.id
        and mapping_status = 'approved'
        and target_field = 'estimated_payback_period'
      order by created_at desc
      limit 1
    ),
    (
      select (proposed_value_json #>> '{}')::numeric
      from public.external_import_field_mappings
      where import_run_id = v_run.id
        and mapping_status = 'approved'
        and target_field = 'completion_probability'
      order by created_at desc
      limit 1
    ),
    (
      select (proposed_value_json #>> '{}')::numeric
      from public.external_import_field_mappings
      where import_run_id = v_run.id
        and mapping_status = 'approved'
        and target_field = 'schedule_risk_score'
      order by created_at desc
      limit 1
    ),
    (
      select proposed_value_json #>> '{}'
      from public.external_import_field_mappings
      where import_run_id = v_run.id
        and mapping_status = 'approved'
        and target_field = 'analyst_comment'
      order by created_at desc
      limit 1
    )
  into
    v_project_name_zh,
    v_project_name_en,
    v_project_type,
    v_genre,
    v_region,
    v_language,
    v_estimated_budget,
    v_expected_roi,
    v_estimated_payback_period,
    v_completion_probability,
    v_schedule_risk_score,
    v_analyst_comment;

  insert into public.project_evaluations (
    evaluation_code,
    project_name_zh,
    project_name_en,
    project_type,
    genre,
    region,
    language,
    estimated_budget,
    expected_roi,
    estimated_payback_period,
    completion_probability,
    schedule_risk_score,
    analyst_comment,
    evaluation_status,
    project_id,
    created_by
  )
  values (
    concat('CIR-', to_char(now(), 'YYYYMMDDHH24MISS'), '-', substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    v_project_name_zh,
    v_project_name_en,
    v_project_type,
    v_genre,
    v_region,
    v_language,
    v_estimated_budget,
    v_expected_roi,
    v_estimated_payback_period,
    v_completion_probability,
    v_schedule_risk_score,
    coalesce(v_analyst_comment, 'Baseline generated from approved CIRQUA import snapshot.'),
    'draft',
    v_project.id,
    auth.uid()
  )
  returning * into v_evaluation;

  update public.external_import_field_mappings
  set
    mapping_status = 'applied_to_baseline',
    updated_at = now()
  where import_run_id = v_run.id
    and mapping_status = 'approved';

  update public.external_import_runs
  set
    baseline_generated_by = auth.uid(),
    baseline_generated_at = now(),
    baseline_project_evaluation_id = v_evaluation.id,
    updated_at = now()
  where id = v_run.id
  returning * into v_run;

  perform app.write_cirqua_audit_log(
    v_project.id,
    v_run.project_source_link_id,
    v_run.id,
    'generate_baseline',
    jsonb_build_object(
      'project_evaluation_id', v_evaluation.id,
      'applied_field_count', v_applied_count,
      'baseline_source', 'cirqua_import'
    )
  );

  return jsonb_build_object(
    'import_run_id', v_run.id,
    'project_id', v_project.id,
    'project_evaluation_id', v_evaluation.id,
    'evaluation_status', v_evaluation.evaluation_status,
    'baseline_fields_applied', jsonb_build_array(
      'project_name_zh',
      'project_name_en',
      'project_type',
      'genre',
      'region',
      'language',
      'estimated_budget'
    ),
    'baseline_source', 'cirqua_import'
  );
end;
$$;

revoke all on function app.assert_cirqua_role(text[]) from public, anon, authenticated;
revoke all on function app.is_cirqua_consent_valid(uuid) from public, anon, authenticated;
revoke all on function app.write_cirqua_audit_log(uuid, uuid, uuid, text, jsonb) from public, anon, authenticated;

revoke all on function public.create_cirqua_project_link(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.grant_cirqua_consent(uuid, jsonb, timestamptz) from public, anon, authenticated;
revoke all on function public.create_cirqua_import_run(uuid) from public, anon, authenticated;
revoke all on function public.approve_cirqua_field_mapping(uuid, text) from public, anon, authenticated;
revoke all on function public.reject_cirqua_field_mapping(uuid, text) from public, anon, authenticated;
revoke all on function public.generate_project_evaluation_baseline_from_cirqua(uuid) from public, anon, authenticated;

grant execute on function public.create_cirqua_project_link(uuid, text, jsonb) to authenticated;
grant execute on function public.grant_cirqua_consent(uuid, jsonb, timestamptz) to authenticated;
grant execute on function public.create_cirqua_import_run(uuid) to authenticated;
grant execute on function public.approve_cirqua_field_mapping(uuid, text) to authenticated;
grant execute on function public.reject_cirqua_field_mapping(uuid, text) to authenticated;
grant execute on function public.generate_project_evaluation_baseline_from_cirqua(uuid) to authenticated;

comment on function public.create_cirqua_project_link(uuid, text, jsonb) is 'Controlled RPC for creating CIRQUA project links. Prevents direct raw table writes from client code.';
comment on function public.grant_cirqua_consent(uuid, jsonb, timestamptz) is 'Controlled RPC for granting CIRQUA consent. super_admin only.';
comment on function public.create_cirqua_import_run(uuid) is 'Controlled RPC for creating CIRQUA import runs. Analyst may call, but cannot bypass consent.';
comment on function public.approve_cirqua_field_mapping(uuid, text) is 'Controlled RPC for approving CIRQUA field mappings.';
comment on function public.reject_cirqua_field_mapping(uuid, text) is 'Controlled RPC for rejecting CIRQUA field mappings.';
comment on function public.generate_project_evaluation_baseline_from_cirqua(uuid) is 'Controlled RPC for generating a draft project_evaluation baseline from approved CIRQUA import data.';

commit;
