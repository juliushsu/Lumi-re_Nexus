begin;

-- CIRQUA Sprint 2O
-- Staging-only Wave 1 RLS enable for public.project_festival_records
-- Scope:
-- - create public.can_access_project(project_id uuid)
-- - enable read-only tenant RLS on project_festival_records
-- - remove anon direct access
-- - keep service_role management access
-- - do not add insert/update/delete policies

create or replace function public.can_access_project(project_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text := coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), auth.role(), '');
begin
  if v_role = 'service_role' then
    return true;
  end if;

  if auth.uid() is null then
    return false;
  end if;

  return exists (
    select 1
    from public.projects p
    where p.id = can_access_project.project_id
      and p.org_id = public.current_user_org_id()
  );
end;
$$;

revoke all on function public.can_access_project(uuid) from public, anon, authenticated;
grant execute on function public.can_access_project(uuid) to authenticated;
grant execute on function public.can_access_project(uuid) to service_role;

alter table public.project_festival_records enable row level security;

drop policy if exists "project_festival_records_select_same_org_project_v1" on public.project_festival_records;

revoke all on table public.project_festival_records from anon, authenticated;
grant select on table public.project_festival_records to authenticated;
grant all on table public.project_festival_records to service_role;

create policy "project_festival_records_select_same_org_project_v1"
  on public.project_festival_records
  for select
  to authenticated
  using (public.can_access_project(project_id));

comment on function public.can_access_project(uuid) is
  'Wave 1 project-scope helper. Returns true only when the caller can access the target project through projects.org_id = current_user_org_id(), or when running under service_role.';

comment on policy "project_festival_records_select_same_org_project_v1"
  on public.project_festival_records is
  'Wave 1 read-only tenant policy for project_festival_records. Authenticated callers can only read rows whose project belongs to their current organization.';

commit;
