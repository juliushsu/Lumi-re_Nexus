begin;

create or replace function public.current_user_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select up.org_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.status = 'active'
  order by up.created_at asc
  limit 1
$$;

revoke all on function public.current_user_org_id() from public, anon, authenticated;
grant execute on function public.current_user_org_id() to authenticated;
grant execute on function public.current_user_org_id() to service_role;

alter table public.organizations enable row level security;

drop policy if exists "organizations_select_current_org_v1" on public.organizations;
drop policy if exists "organizations_authenticated_select_own_org_v1" on public.organizations;
drop policy if exists "organizations_authenticated_manage_v1" on public.organizations;

revoke all on table public.organizations from anon, authenticated;
grant select on table public.organizations to authenticated;

create policy "organizations_authenticated_select_own_org_v1"
  on public.organizations
  for select
  to authenticated
  using (
    id = public.current_user_org_id()
  );

comment on function public.current_user_org_id() is
  'Returns the active caller org_id from public.user_profiles for staged tenant-aware RLS checks.';

commit;
