-- CIRQUA Sprint 2M
-- Business tables RLS staged plan skeleton only.
-- Do not apply directly.
-- This file intentionally does not:
-- - enable RLS on any new table
-- - change existing grants
-- - restore anon access
-- - reopen high-risk direct writes
--
-- Design assumptions:
-- - public.current_user_org_id() already exists
-- - role helpers such as app.has_role(...) and app.has_any_role(...) already exist
-- - projects is the canonical tenant root for project-scoped data
-- - investment_plans is becoming the canonical tenant root for plan-scoped data

select
  'Sprint 2M skeleton only.' as draft_notice,
  'Review write callers before enabling any commented policy block.' as write_path_notice;

-- ============================================================================
-- Proposed helper functions
-- Not applied in this round. Keep as design placeholders only.
-- ============================================================================

-- create or replace function app.can_access_project(p_project_id uuid)
-- returns boolean
-- language sql
-- stable
-- as $$
--   select exists (
--     select 1
--     from public.projects p
--     where p.id = p_project_id
--       and p.org_id = public.current_user_org_id()
--   );
-- $$;

-- create or replace function app.can_access_plan(p_plan_id uuid)
-- returns boolean
-- language sql
-- stable
-- as $$
--   select exists (
--     select 1
--     from public.investment_plans ip
--     where ip.id = p_plan_id
--       and ip.org_id = public.current_user_org_id()
--   );
-- $$;

-- create or replace function app.can_access_report(p_report_id uuid)
-- returns boolean
-- language sql
-- stable
-- as $$
--   select exists (
--     select 1
--     from public.reports r
--     where r.id = p_report_id
--       and (
--         (r.org_id is not null and r.org_id = public.current_user_org_id())
--         or (r.project_id is not null and app.can_access_project(r.project_id))
--         or (r.plan_id is not null and app.can_access_plan(r.plan_id))
--       )
--   );
-- $$;

-- ============================================================================
-- Phase A: lowest-risk project-scoped tables
-- Goal: read-first tenant scoping on tables with direct project lineage.
-- Write policies remain commented until caller inventory is complete.
-- ============================================================================

-- public.project_evaluations
-- alter table public.project_evaluations enable row level security;
-- revoke all on table public.project_evaluations from anon;
-- drop policy if exists "project_evaluations_select_roles_v1" on public.project_evaluations;
-- create policy "project_evaluations_select_same_org_project_v2"
--   on public.project_evaluations
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and app.can_access_project(project_id)
--   );
--
-- High-risk write path: keep commented until project evaluation caller path is moved to RPC/service
-- create policy "project_evaluations_insert_same_org_project_v2"
--   on public.project_evaluations
--   for insert
--   to authenticated
--   with check (
--     app.has_any_role(array['super_admin', 'analyst'])
--     and app.can_access_project(project_id)
--   );
--
-- create policy "project_evaluations_update_same_org_project_v2"
--   on public.project_evaluations
--   for update
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst'])
--     and app.can_access_project(project_id)
--   )
--   with check (
--     app.has_any_role(array['super_admin', 'analyst'])
--     and app.can_access_project(project_id)
--   );

-- public.project_costs
-- alter table public.project_costs enable row level security;
-- revoke all on table public.project_costs from anon;
-- create policy "project_costs_select_same_org_project_v1"
--   on public.project_costs
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and app.can_access_project(project_id)
--   );
--
-- High-risk write path: do not enable direct authenticated writes until writer path is identified
-- create policy "project_costs_write_same_org_project_v1" ...;

-- public.project_cost_items
-- alter table public.project_cost_items enable row level security;
-- revoke all on table public.project_cost_items from anon;
-- create policy "project_cost_items_select_same_org_project_v1"
--   on public.project_cost_items
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and app.can_access_project(project_id)
--   );
-- High-risk write policy intentionally omitted.

-- public.project_cast_costs
-- alter table public.project_cast_costs enable row level security;
-- revoke all on table public.project_cast_costs from anon;
-- create policy "project_cast_costs_select_same_org_project_v1"
--   on public.project_cast_costs
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and app.can_access_project(project_id)
--   );
-- High-risk write policy intentionally omitted.

-- public.project_revenues
-- alter table public.project_revenues enable row level security;
-- revoke all on table public.project_revenues from anon;
-- create policy "project_revenues_select_same_org_project_v1"
--   on public.project_revenues
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and app.can_access_project(project_id)
--   );
-- High-risk write policy intentionally omitted.

-- public.project_festival_records
-- alter table public.project_festival_records enable row level security;
-- revoke all on table public.project_festival_records from anon;
-- create policy "project_festival_records_select_same_org_project_v1"
--   on public.project_festival_records
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and app.can_access_project(project_id)
--   );
-- Low-write table, but direct writes still intentionally omitted from this skeleton.

-- ============================================================================
-- Phase B: tenant-root tables
-- Goal: replace role-only read policies with explicit org-root checks.
-- ============================================================================

-- public.investment_plans
-- Existing RLS already enabled. Replace read policy only after org_id backfill is verified in target env.
-- drop policy if exists "investment_plans_select_roles_v1" on public.investment_plans;
-- create policy "investment_plans_select_same_org_v2"
--   on public.investment_plans
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and org_id = public.current_user_org_id()
--   );
--
-- High-risk write path: keep direct authenticated writes disabled.
-- Preferred path:
-- - super_admin direct via existing policy
-- - future analyst/editor writes through RPC or service backend

-- public.reports
-- Existing RLS already enabled. Mixed lineage means org_id should be primary check with lineage fallback only if needed.
-- drop policy if exists "reports_select_roles_v1" on public.reports;
-- create policy "reports_select_same_org_v2"
--   on public.reports
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'report_viewer'])
--     and (
--       (org_id is not null and org_id = public.current_user_org_id())
--       or (project_id is not null and app.can_access_project(project_id))
--       or (plan_id is not null and app.can_access_plan(plan_id))
--     )
--   );
--
-- High-risk write path intentionally omitted. Future report generation should use service/RPC.

-- ============================================================================
-- Phase C: plan child tables
-- Goal: inherit tenant scope from investment_plans.org_id via plan helper.
-- ============================================================================

-- public.plan_projects
-- alter table public.plan_projects enable row level security;
-- revoke all on table public.plan_projects from anon;
-- create policy "plan_projects_select_same_org_plan_v1"
--   on public.plan_projects
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
--     and app.can_access_plan(plan_id)
--     and (
--       project_id is null
--       or app.can_access_project(project_id)
--     )
--   );
-- High-risk write path intentionally omitted until plan editing caller path is known.

-- public.plan_kpi_snapshots
-- alter table public.plan_kpi_snapshots enable row level security;
-- revoke all on table public.plan_kpi_snapshots from anon;
-- create policy "plan_kpi_snapshots_select_same_org_plan_v1"
--   on public.plan_kpi_snapshots
--   for select
--   to authenticated
--   using (
--     app.has_any_role(array['super_admin', 'analyst', 'project_editor', 'report_viewer'])
--     and app.can_access_plan(plan_id)
--   );
-- High-risk write path intentionally omitted until KPI ingestion path is identified.

-- ============================================================================
-- Phase D: system / raw / audit tables
-- Goal: keep client direct access minimal or zero. Prefer RPC/service-only access.
-- ============================================================================

-- public.project_source_links
-- keep current model:
-- - select only for allowed authenticated admin/analyst roles
-- - no client direct insert/update/delete
-- - all mutations through RPC/service functions

-- public.external_import_runs
-- keep system-only / RPC-only
-- no broader client policies

-- public.external_project_snapshots
-- keep system-only / service-only

-- public.external_budget_snapshots
-- keep system-only / service-only

-- public.external_import_field_mappings
-- keep analyst review access
-- writes should remain RPC/service-mediated where possible

-- public.external_import_audit_logs
-- keep append-only model
-- no client update/delete

-- public.roi_model_weights
-- candidate admin/reference table
-- if enabled later:
-- - read: authenticated analyst/project_editor only
-- - write: super_admin/service only

-- public.festival_events
-- candidate curated reference table
-- final decision required:
-- - public read-only with no writes
-- or
-- - authenticated read-only with admin/service writes only

select
  'Sprint 2M skeleton complete.' as next_step_notice,
  'Next stage should choose one narrow apply wave rather than enabling every commented block together.' as rollout_notice;
