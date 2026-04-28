begin;

alter table public.user_profiles enable row level security;
alter table public.projects enable row level security;

drop policy if exists "user_profiles_select_self_or_super_admin_v1" on public.user_profiles;
drop policy if exists "user_profiles_manage_super_admin_v1" on public.user_profiles;
drop policy if exists "user_profiles_authenticated_select_same_org_v2" on public.user_profiles;

drop policy if exists "projects_select_roles_v1" on public.projects;
drop policy if exists "projects_manage_project_editor_v1" on public.projects;
drop policy if exists "projects_update_project_editor_v1" on public.projects;
drop policy if exists "projects_delete_super_admin_v1" on public.projects;
drop policy if exists "projects_authenticated_select_same_org_v2" on public.projects;

revoke all on table public.user_profiles from anon, authenticated;
grant select on table public.user_profiles to authenticated;

revoke all on table public.projects from anon, authenticated;
grant select on table public.projects to authenticated;

create policy "user_profiles_authenticated_select_same_org_v2"
  on public.user_profiles
  for select
  to authenticated
  using (
    status = 'active'
    and (
      user_id = auth.uid()
      or (
        org_id is not null
        and org_id = public.current_user_org_id()
      )
    )
  );

create policy "projects_authenticated_select_same_org_v2"
  on public.projects
  for select
  to authenticated
  using (
    org_id is not null
    and org_id = public.current_user_org_id()
  );

comment on policy "user_profiles_authenticated_select_same_org_v2"
  on public.user_profiles is 'Staging tenant-aware select policy. Authenticated users can read self and same-org active profiles only.';

comment on policy "projects_authenticated_select_same_org_v2"
  on public.projects is 'Staging tenant-aware select policy. Authenticated users can read projects in their current org only.';

commit;
