-- Draft only. Do not execute automatically.
-- Use only if the Sprint 2C staging dry run causes blocking issues.

begin;

-- Warning:
-- - This drops the staging-only tenant prep artifacts introduced by
--   20260428193000_sprint2c_staging_tenant_schema_prep.sql
-- - Any manual mapping data entered after the dry run would be lost.

drop table if exists app.project_org_backfill_manual_map;

alter table if exists public.projects
  drop column if exists org_id;

alter table if exists public.user_profiles
  drop column if exists org_id;

drop table if exists public.organizations;

commit;
