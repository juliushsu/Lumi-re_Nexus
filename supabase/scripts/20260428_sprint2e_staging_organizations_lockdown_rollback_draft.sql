-- Draft only. Do not execute automatically.
-- Use only if the Sprint 2E staging organizations lockdown must be reverted.

begin;

drop policy if exists "organizations_authenticated_select_own_org_v1" on public.organizations;

grant select, insert, update, delete on table public.organizations to anon;
grant select, insert, update, delete on table public.organizations to authenticated;

alter table public.organizations disable row level security;

revoke execute on function public.current_user_org_id() from authenticated;
revoke execute on function public.current_user_org_id() from service_role;
drop function if exists public.current_user_org_id();

commit;
