begin;

-- CIRQUA Sprint 2O rollback draft
-- Do not execute unless the staging Wave 1 rollout blocks the environment.
-- If public.can_access_project(uuid) is reused by later tables before rollback,
-- review dependencies before dropping it.

drop policy if exists "project_festival_records_select_same_org_project_v1"
  on public.project_festival_records;

alter table public.project_festival_records disable row level security;

revoke all on table public.project_festival_records from anon, authenticated, service_role;
grant all on table public.project_festival_records to anon;
grant all on table public.project_festival_records to authenticated;
grant all on table public.project_festival_records to service_role;

revoke all on function public.can_access_project(uuid) from public, anon, authenticated, service_role;
drop function if exists public.can_access_project(uuid);

commit;
