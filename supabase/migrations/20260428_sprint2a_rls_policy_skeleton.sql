-- CIRQUA Stabilization Sprint 2A
-- Draft only. Policy review skeleton, not for direct apply.
--
-- Important blockers from the canonical 2026-04-28 baseline:
-- - public.projects currently has no org_id column in staging.
-- - public.user_profiles currently has no org_id column in staging.
-- - public.organizations does not exist in staging.
-- - the requested Sprint 1 audit artifacts were not present in GitHub main.
--
-- This file documents the intended RLS model and keeps high-risk statements
-- commented until tenant columns and manual mapping are approved.

select
  'Sprint 2A draft only: RLS skeleton remains intentionally non-executable until organizations, projects.org_id, and user_profiles.org_id are introduced and manually reconciled.' as draft_notice;

-- ---------------------------------------------------------------------------
-- Core 14-table hardening matrix
-- Derived from current staging public schema and app-domain tables.
-- ---------------------------------------------------------------------------
with table_matrix (
  table_name,
  has_org_id,
  has_project_id,
  suggested_mode,
  notes
) as (
  values
    ('festival_events', false, false, 'public-read-only', 'reference taxonomy; verify whether anon really needs access'),
    ('investment_plans', false, false, 'org-scoped', 'requires direct org_id or derived plan ownership'),
    ('plan_kpi_snapshots', false, false, 'org-scoped', 'scope through parent investment_plans.plan_id'),
    ('plan_projects', false, true, 'org-scoped', 'scope through parent plan_id and validate project/org consistency'),
    ('project_cast_costs', false, true, 'project-scoped', 'scope via parent project'),
    ('project_cost_items', false, true, 'project-scoped', 'scope via parent project'),
    ('project_costs', false, true, 'project-scoped', 'scope via parent project'),
    ('project_evaluations', false, true, 'project-scoped', 'scope via parent project'),
    ('project_festival_records', false, true, 'project-scoped', 'scope via parent project'),
    ('project_revenues', false, true, 'project-scoped', 'scope via parent project'),
    ('projects', false, false, 'org-scoped', 'must add canonical projects.org_id before tenant RLS is meaningful'),
    ('reports', false, true, 'project-scoped', 'scope via parent project'),
    ('roi_models', false, false, 'admin-only', 'global configuration table; later may expose summary RPC if needed'),
    ('user_profiles', false, false, 'org-scoped', 'requires user_profiles.org_id plus self-read exception')
)
select *
from table_matrix;

-- ---------------------------------------------------------------------------
-- Suggested helper functions for Sprint 2B / 2C
-- ---------------------------------------------------------------------------
-- create schema if not exists app;
--
-- create or replace function app.current_org_id()
-- returns uuid
-- language sql
-- stable
-- security definer
-- set search_path = public
-- as $$
--   select up.org_id
--   from public.user_profiles up
--   where up.user_id = auth.uid()
--     and up.status = 'active'
--   order by up.created_at asc
--   limit 1
-- $$;
--
-- create or replace function app.user_has_org_scope()
-- returns boolean
-- language sql
-- stable
-- security definer
-- set search_path = public
-- as $$
--   select app.current_org_id() is not null
-- $$;
--
-- create or replace function app.can_access_project(p_project_id uuid)
-- returns boolean
-- language sql
-- stable
-- security definer
-- set search_path = public
-- as $$
--   select exists (
--     select 1
--     from public.projects p
--     where p.id = p_project_id
--       and p.org_id = app.current_org_id()
--   )
-- $$;
--
-- create or replace function app.can_access_plan(p_plan_id uuid)
-- returns boolean
-- language sql
-- stable
-- security definer
-- set search_path = public
-- as $$
--   select exists (
--     select 1
--     from public.plan_projects pp
--     join public.projects p on p.id = pp.project_id
--     where pp.plan_id = p_plan_id
--       and p.org_id = app.current_org_id()
--   )
-- $$;

-- ---------------------------------------------------------------------------
-- Low-risk candidate skeletons
-- These stay commented in Sprint 2A to avoid accidental rollout.
-- ---------------------------------------------------------------------------
-- alter table public.festival_events enable row level security;
-- create policy "festival_events_public_read_v1"
--   on public.festival_events
--   for select
--   using (true);
-- create policy "festival_events_admin_write_v1"
--   on public.festival_events
--   for all
--   using (app.has_role('super_admin'))
--   with check (app.has_role('super_admin'));
--
-- alter table public.roi_models enable row level security;
-- create policy "roi_models_admin_read_write_v2"
--   on public.roi_models
--   for all
--   using (app.has_role('super_admin'))
--   with check (app.has_role('super_admin'));

-- ---------------------------------------------------------------------------
-- High-risk tenant policies
-- Keep commented until:
-- 1. user_profiles.org_id exists
-- 2. projects.org_id exists
-- 3. organizations exists
-- 4. manual backfill review is approved
-- ---------------------------------------------------------------------------
-- alter table public.user_profiles enable row level security;
-- create policy "user_profiles_select_self_same_org_or_super_admin_v2"
--   on public.user_profiles
--   for select
--   using (
--     user_id = auth.uid()
--     or app.has_role('super_admin')
--     or (
--       app.current_org_id() is not null
--       and org_id = app.current_org_id()
--     )
--   );
--
-- alter table public.projects enable row level security;
-- create policy "projects_select_same_org_v2"
--   on public.projects
--   for select
--   using (
--     app.has_role('super_admin')
--     or (
--       app.current_org_id() is not null
--       and org_id = app.current_org_id()
--     )
--   );
--
-- create policy "projects_insert_same_org_v2"
--   on public.projects
--   for insert
--   with check (
--     app.has_role('super_admin')
--     or (
--       app.has_any_role(array['project_editor', 'analyst'])
--       and app.current_org_id() is not null
--       and org_id = app.current_org_id()
--     )
--   );
--
-- create policy "projects_update_same_org_v2"
--   on public.projects
--   for update
--   using (
--     app.has_role('super_admin')
--     or (
--       app.has_any_role(array['project_editor', 'analyst'])
--       and app.current_org_id() is not null
--       and org_id = app.current_org_id()
--     )
--   )
--   with check (
--     app.has_role('super_admin')
--     or (
--       app.has_any_role(array['project_editor', 'analyst'])
--       and app.current_org_id() is not null
--       and org_id = app.current_org_id()
--     )
--   );
--
-- create policy "project_costs_select_same_project_org_v1"
--   on public.project_costs
--   for select
--   using (
--     app.has_role('super_admin')
--     or app.can_access_project(project_id)
--   );
--
-- Repeat the same parent-project pattern for:
-- - public.project_cast_costs
-- - public.project_cost_items
-- - public.project_evaluations
-- - public.project_festival_records
-- - public.project_revenues
-- - public.reports
--
-- Scope through parent investment plan for:
-- - public.investment_plans
-- - public.plan_kpi_snapshots
-- - public.plan_projects
--
-- Example plan-scoped skeleton once projects.org_id is backfilled:
-- create policy "investment_plans_select_same_org_v2"
--   on public.investment_plans
--   for select
--   using (
--     app.has_role('super_admin')
--     or app.can_access_plan(id)
--   );
