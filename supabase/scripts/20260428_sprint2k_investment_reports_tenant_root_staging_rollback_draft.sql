begin;

-- CIRQUA Sprint 2K rollback draft
-- Do not execute unless the staging tenant-root dry run blocks the environment.
-- Review current dependencies before dropping any constraint, index, or column.

drop index if exists public.plan_kpi_snapshots_plan_id_idx;
drop index if exists public.plan_projects_evaluation_id_idx;
drop index if exists public.plan_projects_project_id_idx;
drop index if exists public.plan_projects_plan_id_idx;
drop index if exists public.reports_evaluation_id_idx;
drop index if exists public.reports_plan_id_idx;
drop index if exists public.reports_project_id_idx;
drop index if exists public.reports_org_id_idx;
drop index if exists public.investment_plans_org_id_idx;

alter table if exists public.plan_kpi_snapshots
  drop constraint if exists plan_kpi_snapshots_plan_id_fkey;

alter table if exists public.plan_projects
  drop constraint if exists plan_projects_evaluation_id_fkey;

alter table if exists public.plan_projects
  drop constraint if exists plan_projects_project_id_fkey;

alter table if exists public.plan_projects
  drop constraint if exists plan_projects_plan_id_fkey;

alter table if exists public.reports
  drop constraint if exists reports_evaluation_id_fkey;

alter table if exists public.reports
  drop constraint if exists reports_plan_id_fkey;

alter table if exists public.reports
  drop constraint if exists reports_project_id_fkey;

alter table if exists public.reports
  drop constraint if exists reports_org_id_fkey;

alter table if exists public.investment_plans
  drop constraint if exists investment_plans_org_id_fkey;

alter table if exists public.reports
  drop column if exists org_id;

alter table if exists public.investment_plans
  drop column if exists org_id;

commit;
