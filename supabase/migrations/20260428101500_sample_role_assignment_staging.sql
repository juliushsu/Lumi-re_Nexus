begin;

-- Staging-only sample role alignment.
-- This migration never writes service_role credentials and preserves
-- juliushsu@gmail.com as the canonical super_admin account.

create schema if not exists app;

create or replace function app.upsert_user_profile_from_auth(
  target_email text,
  target_role text,
  target_full_name text,
  target_department text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  auth_user record;
begin
  select
    u.id,
    u.email
  into auth_user
  from auth.users u
  where lower(u.email) = lower(target_email)
  limit 1;

  if auth_user.id is null then
    raise notice 'Skipping profile assignment because auth user does not exist for %', target_email;
    return;
  end if;

  update public.user_profiles up
  set
    email = auth_user.email,
    full_name = coalesce(target_full_name, up.full_name),
    role = target_role,
    status = 'active',
    department = coalesce(target_department, up.department),
    updated_at = now()
  where up.user_id = auth_user.id;

  if not found then
    insert into public.user_profiles (
      user_id,
      email,
      full_name,
      role,
      status,
      department
    )
    values (
      auth_user.id,
      auth_user.email,
      target_full_name,
      target_role,
      'active',
      target_department
    );
  end if;
end
$$;

select app.upsert_user_profile_from_auth(
  'juliushsu@gmail.com',
  'super_admin',
  'Julius Hsu',
  'Executive'
);

select app.upsert_user_profile_from_auth(
  'shareholder.staging@lumiere-nexus.local',
  'shareholder_viewer',
  'Staging Shareholder Viewer',
  'Investor Relations'
);

select app.upsert_user_profile_from_auth(
  'analyst.staging@lumiere-nexus.local',
  'analyst',
  'Staging Analyst',
  'Investment Research'
);

select app.upsert_user_profile_from_auth(
  'project.editor.staging@lumiere-nexus.local',
  'project_editor',
  'Staging Project Editor',
  'Production'
);

select app.upsert_user_profile_from_auth(
  'report.viewer.staging@lumiere-nexus.local',
  'report_viewer',
  'Staging Report Viewer',
  'Reporting'
);

drop function if exists app.upsert_user_profile_from_auth(text, text, text, text);

commit;
