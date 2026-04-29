-- CIRQUA Sprint 2N
-- Phase A project-scoped child tables RLS draft only.
-- Do not apply directly.
-- This file intentionally does not:
-- - enable RLS on target tables
-- - change current grants
-- - reopen anon access
-- - enable direct authenticated write policies by default

select
  'Sprint 2N draft only.' as draft_notice,
  'Review helper semantics and write callers before any apply-wave.' as review_notice;

-- ============================================================================
-- 1. Helper function draft
-- ============================================================================

-- current_user_org_id() already exists in staging and remains the org root helper.

-- create or replace function public.can_access_project(project_id uuid)
-- returns boolean
-- language plpgsql
-- stable
-- security definer
-- set search_path = public
-- as $$
-- begin
--   if auth.role() = 'service_role' then
--     return true;
--   end if;
--
--   if auth.uid() is null then
--     return false;
--   end if;
--
--   return exists (
--     select 1
--     from public.projects p
--     where p.id = can_access_project.project_id
--       and p.org_id = public.current_user_org_id()
--   );
-- end;
-- $$;

-- Optional write helper if Phase A needs differentiated write rules later.
-- Keep out of first apply-wave unless a real caller requires it.

-- create or replace function public.can_write_project(project_id uuid)
-- returns boolean
-- language plpgsql
-- stable
-- security definer
-- set search_path = public
-- as $$
-- begin
--   if auth.role() = 'service_role' then
--     return true;
--   end if;
--
--   if auth.uid() is null then
--     return false;
--   end if;
--
--   return
--     public.can_access_project(project_id)
--     and exists (
--       select 1
--       from public.user_profiles up
--       where up.user_id = auth.uid()
--         and up.status = 'active'
--         and up.role in ('super_admin', 'analyst', 'project_editor')
--     );
-- end;
-- $$;

-- ============================================================================
-- 2. Phase A SELECT policies
-- First-wave recommendation: read-only RLS enable on one narrow table at a time.
-- ============================================================================

-- public.project_costs
-- alter table public.project_costs enable row level security;
-- revoke all on table public.project_costs from anon;
-- create policy "project_costs_select_same_org_project_v1"
--   on public.project_costs
--   for select
--   to authenticated
--   using (public.can_access_project(project_id));

-- public.project_cost_items
-- alter table public.project_cost_items enable row level security;
-- revoke all on table public.project_cost_items from anon;
-- create policy "project_cost_items_select_same_org_project_v1"
--   on public.project_cost_items
--   for select
--   to authenticated
--   using (public.can_access_project(project_id));

-- public.project_cast_costs
-- alter table public.project_cast_costs enable row level security;
-- revoke all on table public.project_cast_costs from anon;
-- create policy "project_cast_costs_select_same_org_project_v1"
--   on public.project_cast_costs
--   for select
--   to authenticated
--   using (public.can_access_project(project_id));

-- public.project_revenues
-- alter table public.project_revenues enable row level security;
-- revoke all on table public.project_revenues from anon;
-- create policy "project_revenues_select_same_org_project_v1"
--   on public.project_revenues
--   for select
--   to authenticated
--   using (public.can_access_project(project_id));

-- public.project_festival_records
-- alter table public.project_festival_records enable row level security;
-- revoke all on table public.project_festival_records from anon;
-- create policy "project_festival_records_select_same_org_project_v1"
--   on public.project_festival_records
--   for select
--   to authenticated
--   using (public.can_access_project(project_id));

-- ============================================================================
-- 3. Phase A INSERT / UPDATE / DELETE skeleton
-- Keep commented in first draft because current write callers are not verified in repo.
-- ============================================================================

-- public.project_costs
-- create policy "project_costs_write_same_org_project_v1"
--   on public.project_costs
--   for all
--   to authenticated
--   using (public.can_write_project(project_id))
--   with check (public.can_write_project(project_id));

-- public.project_cost_items
-- create policy "project_cost_items_write_same_org_project_v1"
--   on public.project_cost_items
--   for all
--   to authenticated
--   using (public.can_write_project(project_id))
--   with check (public.can_write_project(project_id));

-- public.project_cast_costs
-- create policy "project_cast_costs_write_same_org_project_v1"
--   on public.project_cast_costs
--   for all
--   to authenticated
--   using (public.can_write_project(project_id))
--   with check (public.can_write_project(project_id));

-- public.project_revenues
-- create policy "project_revenues_write_same_org_project_v1"
--   on public.project_revenues
--   for all
--   to authenticated
--   using (public.can_write_project(project_id))
--   with check (public.can_write_project(project_id));

-- public.project_festival_records
-- create policy "project_festival_records_write_same_org_project_v1"
--   on public.project_festival_records
--   for all
--   to authenticated
--   using (public.can_write_project(project_id))
--   with check (public.can_write_project(project_id));

-- ============================================================================
-- 4. Service-role note
-- ============================================================================

-- service_role should continue to bypass normal client RLS through privileged backend paths.
-- Do not add anon policies.
-- Do not rely on client-provided org_id or any caller-supplied tenant hint.

select
  'Sprint 2N draft complete.' as next_step_notice,
  'Recommended first apply-wave is one read-only table with explicit verification and rollback gates.' as rollout_notice;
