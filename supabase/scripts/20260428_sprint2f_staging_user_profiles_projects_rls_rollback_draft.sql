-- Draft only. Do not execute automatically.
-- Use only if the Sprint 2F staging core RLS enable must be reverted.

begin;

drop policy if exists "user_profiles_authenticated_select_same_org_v2" on public.user_profiles;
drop policy if exists "projects_authenticated_select_same_org_v2" on public.projects;

revoke all on table public.user_profiles from authenticated;
grant select on table public.user_profiles to authenticated;

revoke all on table public.projects from authenticated;
grant select, insert, update, delete on table public.projects to authenticated;

create policy "user_profiles_select_self_or_super_admin_v1"
  on public.user_profiles
  for select
  to authenticated
  using (
    (user_id = auth.uid())
    or app.has_role('super_admin')
  );

create policy "user_profiles_manage_super_admin_v1"
  on public.user_profiles
  for all
  to authenticated
  using (app.has_role('super_admin'))
  with check (app.has_role('super_admin'));

create policy "projects_select_roles_v1"
  on public.projects
  for select
  to authenticated
  using (
    app.has_any_role(array['super_admin', 'analyst', 'project_editor'])
  );

create policy "projects_manage_project_editor_v1"
  on public.projects
  for insert
  to authenticated
  with check (
    app.has_any_role(array['super_admin', 'project_editor'])
  );

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

create policy "projects_delete_super_admin_v1"
  on public.projects
  for delete
  to authenticated
  using (app.has_role('super_admin'));

commit;
