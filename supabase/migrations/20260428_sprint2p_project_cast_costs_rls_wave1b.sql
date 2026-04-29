begin;

-- CIRQUA Sprint 2P
-- Staging-only Wave 1B RLS enable for public.project_cast_costs
-- Scope:
-- - reuse public.can_access_project(project_id uuid)
-- - enable read-only tenant RLS on project_cast_costs
-- - remove anon direct access
-- - keep service_role management access
-- - do not add insert/update/delete policies

alter table public.project_cast_costs enable row level security;

drop policy if exists "project_cast_costs_select_same_org_project_v1" on public.project_cast_costs;

revoke all on table public.project_cast_costs from anon, authenticated;
grant select on table public.project_cast_costs to authenticated;
grant all on table public.project_cast_costs to service_role;

create policy "project_cast_costs_select_same_org_project_v1"
  on public.project_cast_costs
  for select
  to authenticated
  using (public.can_access_project(project_id));

comment on policy "project_cast_costs_select_same_org_project_v1"
  on public.project_cast_costs is
  'Wave 1B read-only tenant policy for project_cast_costs. Authenticated callers can only read rows whose project belongs to their current organization.';

commit;
