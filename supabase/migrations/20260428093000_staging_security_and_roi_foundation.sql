begin;

create schema if not exists app;

create or replace function app.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select up.role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.status = 'active'
  order by up.created_at asc
  limit 1
$$;

create or replace function app.is_authenticated()
returns boolean
language sql
stable
as $$
  select auth.uid() is not null
$$;

create or replace function app.has_role(required_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles up
    where up.user_id = auth.uid()
      and up.status = 'active'
      and up.role = required_role
  )
$$;

create or replace function app.has_any_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles up
    where up.user_id = auth.uid()
      and up.status = 'active'
      and up.role = any(required_roles)
  )
$$;

alter table public.user_profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_evaluations enable row level security;
alter table public.investment_plans enable row level security;
alter table public.reports enable row level security;
alter table public.roi_models enable row level security;
alter table public.board_meetings enable row level security;
alter table public.board_resolutions enable row level security;
alter table public.board_action_items enable row level security;
alter table public.roi_model_change_logs enable row level security;

revoke all on table public.user_profiles from anon, authenticated;
revoke all on table public.projects from anon, authenticated;
revoke all on table public.project_evaluations from anon, authenticated;
revoke all on table public.investment_plans from anon, authenticated;
revoke all on table public.reports from anon, authenticated;
revoke all on table public.roi_models from anon, authenticated;
revoke all on table public.board_meetings from anon, authenticated;
revoke all on table public.board_resolutions from anon, authenticated;
revoke all on table public.board_action_items from anon, authenticated;
revoke all on table public.roi_model_change_logs from anon, authenticated;

grant usage on schema public to anon, authenticated;
grant usage on schema app to authenticated;
revoke all on function app.current_profile_role() from public, anon, authenticated;
revoke all on function app.has_role(text) from public, anon, authenticated;
revoke all on function app.has_any_role(text[]) from public, anon, authenticated;
grant execute on function app.current_profile_role() to authenticated;
grant execute on function app.has_role(text) to authenticated;
grant execute on function app.has_any_role(text[]) to authenticated;

grant select on table public.user_profiles to authenticated;
grant select, insert, update, delete on table public.projects to authenticated;
grant select, insert, update, delete on table public.project_evaluations to authenticated;
grant select, insert, update, delete on table public.investment_plans to authenticated;
grant select, insert, update, delete on table public.reports to authenticated;
grant select, insert, update, delete on table public.roi_models to authenticated;
grant select, insert, update, delete on table public.board_meetings to authenticated;
grant select, insert, update, delete on table public.board_resolutions to authenticated;
grant select, insert, update, delete on table public.board_action_items to authenticated;
grant select, insert, update, delete on table public.roi_model_change_logs to authenticated;

alter table public.roi_models
  add column if not exists model_type text,
  add column if not exists budget_min numeric(18,2),
  add column if not exists budget_max numeric(18,2),
  add column if not exists expected_roi_min numeric(8,4),
  add column if not exists expected_roi_max numeric(8,4),
  add column if not exists payback_months_min integer,
  add column if not exists payback_months_max integer,
  add column if not exists risk_level text,
  add column if not exists assumptions_json jsonb not null default '{}'::jsonb,
  add column if not exists formula_version text,
  add column if not exists status text not null default 'draft';

comment on column public.roi_models.model_name is 'Canonical ROI model name.';
comment on column public.roi_models.model_type is 'Business classification such as feature_film, series, commercial, or experimental.';
comment on column public.roi_models.assumptions_json is 'Structured seed assumptions only; scalar decision inputs should live in first-class columns.';

alter table public.roi_models
  alter column model_type set not null,
  alter column budget_min set not null,
  alter column budget_max set not null,
  alter column expected_roi_min set not null,
  alter column expected_roi_max set not null,
  alter column payback_months_min set not null,
  alter column payback_months_max set not null,
  alter column risk_level set not null,
  alter column formula_version set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'roi_models_budget_range_check'
  ) then
    alter table public.roi_models
      add constraint roi_models_budget_range_check
      check (budget_min <= budget_max);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'roi_models_expected_roi_range_check'
  ) then
    alter table public.roi_models
      add constraint roi_models_expected_roi_range_check
      check (expected_roi_min <= expected_roi_max);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'roi_models_payback_range_check'
  ) then
    alter table public.roi_models
      add constraint roi_models_payback_range_check
      check (payback_months_min <= payback_months_max);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'roi_models_status_check'
  ) then
    alter table public.roi_models
      add constraint roi_models_status_check
      check (status in ('draft', 'active', 'archived'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_profiles_role_check'
  ) then
    alter table public.user_profiles
      add constraint user_profiles_role_check
      check (role in ('super_admin', 'shareholder_viewer', 'analyst', 'project_editor', 'report_viewer'))
      not valid;
  end if;
end
$$;

create or replace function public.get_projects_dashboard_summary()
returns table (
  id uuid,
  project_code text,
  project_name_zh text,
  project_name_en text,
  project_type text,
  genre text,
  region text,
  language text,
  status text,
  total_budget numeric,
  projected_revenue numeric,
  projected_roi numeric,
  actual_roi numeric,
  payback_period_month integer,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.project_code,
    p.project_name_zh,
    p.project_name_en,
    p.project_type,
    p.genre,
    p.region,
    p.language,
    p.status,
    p.total_budget,
    p.projected_revenue,
    p.projected_roi,
    p.actual_roi,
    p.payback_period_month,
    p.updated_at
  from public.projects p
  where app.has_any_role(array['super_admin', 'shareholder_viewer'])
$$;

create or replace function public.get_investment_plans_dashboard_summary()
returns table (
  id uuid,
  plan_code text,
  plan_name text,
  entity_name text,
  vintage_year integer,
  target_raise numeric,
  actual_raise numeric,
  target_irr numeric,
  target_roi numeric,
  target_payback_month integer,
  risk_tolerance text,
  plan_status text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ip.id,
    ip.plan_code,
    ip.plan_name,
    ip.entity_name,
    ip.vintage_year,
    ip.target_raise,
    ip.actual_raise,
    ip.target_irr,
    ip.target_roi,
    ip.target_payback_month,
    ip.risk_tolerance,
    ip.plan_status,
    ip.updated_at
  from public.investment_plans ip
  where app.has_any_role(array['super_admin', 'shareholder_viewer'])
$$;

create or replace function public.get_reports_dashboard_summary()
returns table (
  id uuid,
  report_code varchar,
  report_type varchar,
  report_name_zh varchar,
  report_name_en varchar,
  plan_id uuid,
  project_id uuid,
  evaluation_id uuid,
  report_period varchar,
  report_status varchar,
  generated_by uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.report_code,
    r.report_type,
    r.report_name_zh,
    r.report_name_en,
    r.plan_id,
    r.project_id,
    r.evaluation_id,
    r.report_period,
    r.report_status,
    r.generated_by,
    r.created_at,
    r.updated_at
  from public.reports r
  where app.has_any_role(array['super_admin', 'shareholder_viewer'])
$$;

revoke all on function public.get_projects_dashboard_summary() from public, anon, authenticated;
revoke all on function public.get_investment_plans_dashboard_summary() from public, anon, authenticated;
revoke all on function public.get_reports_dashboard_summary() from public, anon, authenticated;
grant execute on function public.get_projects_dashboard_summary() to authenticated;
grant execute on function public.get_investment_plans_dashboard_summary() to authenticated;
grant execute on function public.get_reports_dashboard_summary() to authenticated;

drop policy if exists "user_profiles_select_self_or_super_admin_v1" on public.user_profiles;
create policy "user_profiles_select_self_or_super_admin_v1"
on public.user_profiles
for select
to authenticated
using (
  user_id = auth.uid()
  or app.has_role('super_admin')
);

drop policy if exists "user_profiles_manage_super_admin_v1" on public.user_profiles;
create policy "user_profiles_manage_super_admin_v1"
on public.user_profiles
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "projects_select_roles_v1" on public.projects;
create policy "projects_select_roles_v1"
on public.projects
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
);

drop policy if exists "projects_manage_project_editor_v1" on public.projects;
create policy "projects_manage_project_editor_v1"
on public.projects
for insert
to authenticated
with check (
  app.has_any_role(array['super_admin', 'project_editor'])
);

drop policy if exists "projects_update_project_editor_v1" on public.projects;
create policy "projects_update_project_editor_v1"
on public.projects
for update
to authenticated
using (
  app.has_any_role(array['super_admin', 'project_editor'])
)
with check (
  app.has_any_role(array['super_admin', 'project_editor'])
);

drop policy if exists "projects_delete_super_admin_v1" on public.projects;
create policy "projects_delete_super_admin_v1"
on public.projects
for delete
to authenticated
using (app.has_role('super_admin'));

drop policy if exists "project_evaluations_select_roles_v1" on public.project_evaluations;
create policy "project_evaluations_select_roles_v1"
on public.project_evaluations
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
);

drop policy if exists "project_evaluations_insert_analyst_v1" on public.project_evaluations;
create policy "project_evaluations_insert_analyst_v1"
on public.project_evaluations
for insert
to authenticated
with check (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "project_evaluations_update_analyst_v1" on public.project_evaluations;
create policy "project_evaluations_update_analyst_v1"
on public.project_evaluations
for update
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
)
with check (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "project_evaluations_delete_super_admin_v1" on public.project_evaluations;
create policy "project_evaluations_delete_super_admin_v1"
on public.project_evaluations
for delete
to authenticated
using (app.has_role('super_admin'));

drop policy if exists "investment_plans_select_roles_v1" on public.investment_plans;
create policy "investment_plans_select_roles_v1"
on public.investment_plans
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
);

drop policy if exists "investment_plans_manage_super_admin_v1" on public.investment_plans;
create policy "investment_plans_manage_super_admin_v1"
on public.investment_plans
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "reports_select_roles_v1" on public.reports;
create policy "reports_select_roles_v1"
on public.reports
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst', 'report_viewer'])
);

drop policy if exists "reports_manage_super_admin_v1" on public.reports;
create policy "reports_manage_super_admin_v1"
on public.reports
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "roi_models_select_roles_v1" on public.roi_models;
create policy "roi_models_select_roles_v1"
on public.roi_models
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
);

drop policy if exists "roi_models_manage_super_admin_v1" on public.roi_models;
create policy "roi_models_manage_super_admin_v1"
on public.roi_models
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "board_meetings_select_super_admin_v1" on public.board_meetings;
create policy "board_meetings_select_super_admin_v1"
on public.board_meetings
for select
to authenticated
using (app.has_role('super_admin'));

drop policy if exists "board_meetings_manage_super_admin_v1" on public.board_meetings;
create policy "board_meetings_manage_super_admin_v1"
on public.board_meetings
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "board_resolutions_select_super_admin_v1" on public.board_resolutions;
create policy "board_resolutions_select_super_admin_v1"
on public.board_resolutions
for select
to authenticated
using (app.has_role('super_admin'));

drop policy if exists "board_resolutions_manage_super_admin_v1" on public.board_resolutions;
create policy "board_resolutions_manage_super_admin_v1"
on public.board_resolutions
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "board_action_items_select_super_admin_v1" on public.board_action_items;
create policy "board_action_items_select_super_admin_v1"
on public.board_action_items
for select
to authenticated
using (app.has_role('super_admin'));

drop policy if exists "board_action_items_manage_super_admin_v1" on public.board_action_items;
create policy "board_action_items_manage_super_admin_v1"
on public.board_action_items
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "roi_model_change_logs_select_super_admin_v1" on public.roi_model_change_logs;
create policy "roi_model_change_logs_select_super_admin_v1"
on public.roi_model_change_logs
for select
to authenticated
using (app.has_role('super_admin'));

drop policy if exists "roi_model_change_logs_manage_super_admin_v1" on public.roi_model_change_logs;
create policy "roi_model_change_logs_manage_super_admin_v1"
on public.roi_model_change_logs
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

commit;
