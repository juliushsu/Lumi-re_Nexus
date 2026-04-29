begin;

-- CIRQUA Sprint 2P rollback draft
-- Do not execute unless the staging Wave 1B rollout blocks the environment.
-- This rollback intentionally preserves public.can_access_project(uuid),
-- because the helper is already shared with Sprint 2O.

drop policy if exists "project_cast_costs_select_same_org_project_v1"
  on public.project_cast_costs;

alter table public.project_cast_costs disable row level security;

revoke all on table public.project_cast_costs from anon, authenticated, service_role;
grant all on table public.project_cast_costs to anon;
grant all on table public.project_cast_costs to authenticated;
grant all on table public.project_cast_costs to service_role;

commit;
