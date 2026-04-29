begin;

revoke all on function public.create_project_controlled(jsonb, uuid) from authenticated, service_role;
revoke all on function public.update_project_controlled(uuid, jsonb, uuid) from authenticated, service_role;

drop function if exists public.create_project_controlled(jsonb, uuid);
drop function if exists public.update_project_controlled(uuid, jsonb, uuid);
drop function if exists app.is_service_role_context();

commit;
