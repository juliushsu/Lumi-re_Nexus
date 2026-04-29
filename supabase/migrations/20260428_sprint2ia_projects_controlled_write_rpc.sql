begin;

create schema if not exists app;

create or replace function app.is_service_role_context()
returns boolean
language sql
stable
as $$
  select
    coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), auth.role(), '') = 'service_role'
$$;

create or replace function public.create_project_controlled(
  p_payload jsonb,
  p_service_org_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_is_service_role boolean := app.is_service_role_context();
  v_org_id uuid;
  v_forbidden_key text;
  v_required_key text;
  v_missing_keys text[] := '{}'::text[];
  v_project public.projects%rowtype;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'create_project_controlled requires a JSON object payload';
  end if;

  select key
  into v_forbidden_key
  from jsonb_object_keys(p_payload) as key
  where key = any (array['id', 'org_id', 'created_at', 'updated_at'])
  limit 1;

  if v_forbidden_key is not null then
    raise exception 'Payload field % is server-managed and cannot be provided', v_forbidden_key;
  end if;

  if v_is_service_role then
    if p_service_org_id is null then
      raise exception 'service_role context requires p_service_org_id for create_project_controlled';
    end if;
    v_org_id := p_service_org_id;
  else
    if auth.uid() is null then
      raise exception 'Authenticated session required';
    end if;

    if not app.has_any_role(array['super_admin', 'project_editor']) then
      raise exception 'Insufficient project write permissions for role %', app.current_profile_role();
    end if;

    if p_service_org_id is not null then
      raise exception 'p_service_org_id is reserved for service_role context only';
    end if;

    v_org_id := public.current_user_org_id();

    if v_org_id is null then
      raise exception 'No active organization context found for current user';
    end if;
  end if;

  foreach v_required_key in array array[
    'project_code',
    'project_name_zh',
    'project_name_en',
    'project_type',
    'genre',
    'region',
    'language',
    'status'
  ]
  loop
    if not (p_payload ? v_required_key)
      or nullif(btrim(coalesce(p_payload ->> v_required_key, '')), '') is null then
      v_missing_keys := array_append(v_missing_keys, v_required_key);
    end if;
  end loop;

  if array_length(v_missing_keys, 1) is not null then
    raise exception 'Missing required project fields: %', array_to_string(v_missing_keys, ', ');
  end if;

  insert into public.projects (
    org_id,
    project_code,
    project_name_zh,
    project_name_en,
    project_type,
    genre,
    region,
    language,
    production_year,
    release_year,
    status,
    total_budget,
    marketing_budget,
    projected_revenue,
    actual_revenue,
    projected_roi,
    actual_roi,
    payback_period_month,
    script_score,
    package_score,
    cast_score,
    director_score,
    platform_fit_score,
    marketability_score,
    ip_strength_score,
    completion_risk_score,
    legal_risk_score,
    schedule_risk_score,
    notes,
    synopsis
  )
  values (
    v_org_id,
    p_payload ->> 'project_code',
    p_payload ->> 'project_name_zh',
    p_payload ->> 'project_name_en',
    p_payload ->> 'project_type',
    p_payload ->> 'genre',
    p_payload ->> 'region',
    p_payload ->> 'language',
    nullif(p_payload ->> 'production_year', '')::integer,
    nullif(p_payload ->> 'release_year', '')::integer,
    p_payload ->> 'status',
    nullif(p_payload ->> 'total_budget', '')::numeric,
    nullif(p_payload ->> 'marketing_budget', '')::numeric,
    nullif(p_payload ->> 'projected_revenue', '')::numeric,
    nullif(p_payload ->> 'actual_revenue', '')::numeric,
    nullif(p_payload ->> 'projected_roi', '')::numeric,
    nullif(p_payload ->> 'actual_roi', '')::numeric,
    nullif(p_payload ->> 'payback_period_month', '')::integer,
    nullif(p_payload ->> 'script_score', '')::numeric,
    nullif(p_payload ->> 'package_score', '')::numeric,
    nullif(p_payload ->> 'cast_score', '')::numeric,
    nullif(p_payload ->> 'director_score', '')::numeric,
    nullif(p_payload ->> 'platform_fit_score', '')::numeric,
    nullif(p_payload ->> 'marketability_score', '')::numeric,
    nullif(p_payload ->> 'ip_strength_score', '')::numeric,
    nullif(p_payload ->> 'completion_risk_score', '')::numeric,
    nullif(p_payload ->> 'legal_risk_score', '')::numeric,
    nullif(p_payload ->> 'schedule_risk_score', '')::numeric,
    p_payload ->> 'notes',
    p_payload ->> 'synopsis'
  )
  returning *
  into v_project;

  return jsonb_build_object(
    'action', 'created',
    'project_id', v_project.id,
    'org_id', v_project.org_id,
    'project', to_jsonb(v_project)
  );
end;
$$;

create or replace function public.update_project_controlled(
  p_project_id uuid,
  p_payload jsonb,
  p_service_org_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_is_service_role boolean := app.is_service_role_context();
  v_org_id uuid;
  v_forbidden_key text;
  v_project public.projects%rowtype;
begin
  if p_project_id is null then
    raise exception 'p_project_id is required';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'update_project_controlled requires a JSON object payload';
  end if;

  if p_payload = '{}'::jsonb then
    raise exception 'update_project_controlled requires at least one updatable field';
  end if;

  select key
  into v_forbidden_key
  from jsonb_object_keys(p_payload) as key
  where key = any (array['id', 'org_id', 'created_at', 'updated_at'])
  limit 1;

  if v_forbidden_key is not null then
    raise exception 'Payload field % is server-managed and cannot be provided', v_forbidden_key;
  end if;

  if v_is_service_role then
    v_org_id := p_service_org_id;
  else
    if auth.uid() is null then
      raise exception 'Authenticated session required';
    end if;

    if not app.has_any_role(array['super_admin', 'project_editor']) then
      raise exception 'Insufficient project write permissions for role %', app.current_profile_role();
    end if;

    if p_service_org_id is not null then
      raise exception 'p_service_org_id is reserved for service_role context only';
    end if;

    v_org_id := public.current_user_org_id();

    if v_org_id is null then
      raise exception 'No active organization context found for current user';
    end if;
  end if;

  select *
  into v_project
  from public.projects
  where id = p_project_id
  for update;

  if not found then
    raise exception 'Project % not found', p_project_id;
  end if;

  if not v_is_service_role and v_project.org_id is distinct from v_org_id then
    raise exception 'Project % is outside current organization scope', p_project_id;
  end if;

  if v_is_service_role and p_service_org_id is not null and v_project.org_id is distinct from p_service_org_id then
    raise exception 'Project % does not belong to service org context %', p_project_id, p_service_org_id;
  end if;

  if p_payload ? 'project_code' and nullif(btrim(coalesce(p_payload ->> 'project_code', '')), '') is null then
    raise exception 'project_code cannot be blank';
  end if;

  if p_payload ? 'project_name_zh' and nullif(btrim(coalesce(p_payload ->> 'project_name_zh', '')), '') is null then
    raise exception 'project_name_zh cannot be blank';
  end if;

  if p_payload ? 'project_name_en' and nullif(btrim(coalesce(p_payload ->> 'project_name_en', '')), '') is null then
    raise exception 'project_name_en cannot be blank';
  end if;

  if p_payload ? 'project_type' and nullif(btrim(coalesce(p_payload ->> 'project_type', '')), '') is null then
    raise exception 'project_type cannot be blank';
  end if;

  if p_payload ? 'genre' and nullif(btrim(coalesce(p_payload ->> 'genre', '')), '') is null then
    raise exception 'genre cannot be blank';
  end if;

  if p_payload ? 'region' and nullif(btrim(coalesce(p_payload ->> 'region', '')), '') is null then
    raise exception 'region cannot be blank';
  end if;

  if p_payload ? 'language' and nullif(btrim(coalesce(p_payload ->> 'language', '')), '') is null then
    raise exception 'language cannot be blank';
  end if;

  if p_payload ? 'status' and nullif(btrim(coalesce(p_payload ->> 'status', '')), '') is null then
    raise exception 'status cannot be blank';
  end if;

  update public.projects
  set
    project_code = case when p_payload ? 'project_code' then p_payload ->> 'project_code' else project_code end,
    project_name_zh = case when p_payload ? 'project_name_zh' then p_payload ->> 'project_name_zh' else project_name_zh end,
    project_name_en = case when p_payload ? 'project_name_en' then p_payload ->> 'project_name_en' else project_name_en end,
    project_type = case when p_payload ? 'project_type' then p_payload ->> 'project_type' else project_type end,
    genre = case when p_payload ? 'genre' then p_payload ->> 'genre' else genre end,
    region = case when p_payload ? 'region' then p_payload ->> 'region' else region end,
    language = case when p_payload ? 'language' then p_payload ->> 'language' else language end,
    production_year = case when p_payload ? 'production_year' then nullif(p_payload ->> 'production_year', '')::integer else production_year end,
    release_year = case when p_payload ? 'release_year' then nullif(p_payload ->> 'release_year', '')::integer else release_year end,
    status = case when p_payload ? 'status' then p_payload ->> 'status' else status end,
    total_budget = case when p_payload ? 'total_budget' then nullif(p_payload ->> 'total_budget', '')::numeric else total_budget end,
    marketing_budget = case when p_payload ? 'marketing_budget' then nullif(p_payload ->> 'marketing_budget', '')::numeric else marketing_budget end,
    projected_revenue = case when p_payload ? 'projected_revenue' then nullif(p_payload ->> 'projected_revenue', '')::numeric else projected_revenue end,
    actual_revenue = case when p_payload ? 'actual_revenue' then nullif(p_payload ->> 'actual_revenue', '')::numeric else actual_revenue end,
    projected_roi = case when p_payload ? 'projected_roi' then nullif(p_payload ->> 'projected_roi', '')::numeric else projected_roi end,
    actual_roi = case when p_payload ? 'actual_roi' then nullif(p_payload ->> 'actual_roi', '')::numeric else actual_roi end,
    payback_period_month = case when p_payload ? 'payback_period_month' then nullif(p_payload ->> 'payback_period_month', '')::integer else payback_period_month end,
    script_score = case when p_payload ? 'script_score' then nullif(p_payload ->> 'script_score', '')::numeric else script_score end,
    package_score = case when p_payload ? 'package_score' then nullif(p_payload ->> 'package_score', '')::numeric else package_score end,
    cast_score = case when p_payload ? 'cast_score' then nullif(p_payload ->> 'cast_score', '')::numeric else cast_score end,
    director_score = case when p_payload ? 'director_score' then nullif(p_payload ->> 'director_score', '')::numeric else director_score end,
    platform_fit_score = case when p_payload ? 'platform_fit_score' then nullif(p_payload ->> 'platform_fit_score', '')::numeric else platform_fit_score end,
    marketability_score = case when p_payload ? 'marketability_score' then nullif(p_payload ->> 'marketability_score', '')::numeric else marketability_score end,
    ip_strength_score = case when p_payload ? 'ip_strength_score' then nullif(p_payload ->> 'ip_strength_score', '')::numeric else ip_strength_score end,
    completion_risk_score = case when p_payload ? 'completion_risk_score' then nullif(p_payload ->> 'completion_risk_score', '')::numeric else completion_risk_score end,
    legal_risk_score = case when p_payload ? 'legal_risk_score' then nullif(p_payload ->> 'legal_risk_score', '')::numeric else legal_risk_score end,
    schedule_risk_score = case when p_payload ? 'schedule_risk_score' then nullif(p_payload ->> 'schedule_risk_score', '')::numeric else schedule_risk_score end,
    notes = case when p_payload ? 'notes' then p_payload ->> 'notes' else notes end,
    synopsis = case when p_payload ? 'synopsis' then p_payload ->> 'synopsis' else synopsis end,
    updated_at = timezone('utc', now())
  where id = p_project_id
  returning *
  into v_project;

  return jsonb_build_object(
    'action', 'updated',
    'project_id', v_project.id,
    'org_id', v_project.org_id,
    'project', to_jsonb(v_project)
  );
end;
$$;

revoke all on function app.is_service_role_context() from public, anon, authenticated;

revoke all on function public.create_project_controlled(jsonb, uuid) from public, anon, authenticated;
revoke all on function public.update_project_controlled(uuid, jsonb, uuid) from public, anon, authenticated;

grant execute on function public.create_project_controlled(jsonb, uuid) to authenticated;
grant execute on function public.update_project_controlled(uuid, jsonb, uuid) to authenticated;
grant execute on function public.create_project_controlled(jsonb, uuid) to service_role;
grant execute on function public.update_project_controlled(uuid, jsonb, uuid) to service_role;

comment on function app.is_service_role_context() is
  'Internal helper that detects service_role JWT context for staged controlled-write RPCs.';

comment on function public.create_project_controlled(jsonb, uuid) is
  'Staging-only controlled write RPC for project creation. Uses auth.uid() and current_user_org_id() for authenticated callers, auto-assigns projects.org_id, and rejects client-supplied org_id.';

comment on function public.update_project_controlled(uuid, jsonb, uuid) is
  'Staging-only controlled write RPC for project updates. Authenticated callers may update only same-org projects. Client-supplied org_id is rejected.';

commit;
