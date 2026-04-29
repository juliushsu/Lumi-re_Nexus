-- CIRQUA Sprint 2L
-- Production-safe draft only.
-- Do not apply without a fresh preflight on the target environment.
--
-- Purpose:
-- - correct the Sprint 2K staging dry run
-- - avoid duplicate index creation on plan child tables
-- - preserve nullable tenant roots on investment_plans and reports
-- - keep FKs as NOT VALID
-- - do not enable RLS
-- - do not add NOT NULL

select
  'Sprint 2L production-safe draft only.' as draft_notice,
  'Run preflight index audit on the target database before apply.' as preflight_notice;

begin;

-- ============================================================================
-- 1. Tenant root columns
-- ============================================================================

alter table public.investment_plans
  add column if not exists org_id uuid;

comment on column public.investment_plans.org_id is
  'Tenant root key. Nullable during staging and production backfill. Do not enforce NOT NULL until tenant mapping is complete.';

alter table public.reports
  add column if not exists org_id uuid;

comment on column public.reports.org_id is
  'Tenant root key for mixed-lineage reports. Nullable until lineage reconciliation and backfill are verified.';

-- ============================================================================
-- 2. Tenant root FKs
-- Keep NOT VALID until the target environment passes data cleanup and lineage verification.
-- ============================================================================

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'investment_plans_org_id_fkey'
      and conrelid = 'public.investment_plans'::regclass
  ) then
    alter table public.investment_plans
      add constraint investment_plans_org_id_fkey
      foreign key (org_id) references public.organizations(id)
      not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reports_org_id_fkey'
      and conrelid = 'public.reports'::regclass
  ) then
    alter table public.reports
      add constraint reports_org_id_fkey
      foreign key (org_id) references public.organizations(id)
      not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reports_project_id_fkey'
      and conrelid = 'public.reports'::regclass
  ) then
    alter table public.reports
      add constraint reports_project_id_fkey
      foreign key (project_id) references public.projects(id)
      not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reports_plan_id_fkey'
      and conrelid = 'public.reports'::regclass
  ) then
    alter table public.reports
      add constraint reports_plan_id_fkey
      foreign key (plan_id) references public.investment_plans(id)
      not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reports_evaluation_id_fkey'
      and conrelid = 'public.reports'::regclass
  ) then
    alter table public.reports
      add constraint reports_evaluation_id_fkey
      foreign key (evaluation_id) references public.project_evaluations(id)
      not valid;
  end if;
end
$$;

-- ============================================================================
-- 3. Index strategy
-- Only add indexes that are still missing and are part of the tenant-root correction.
-- Do not recreate plan-child lineage indexes when equivalent legacy indexes already exist.
-- ============================================================================

create index if not exists investment_plans_org_id_idx
  on public.investment_plans (org_id);

create index if not exists reports_org_id_idx
  on public.reports (org_id);

create index if not exists reports_project_id_idx
  on public.reports (project_id);

create index if not exists reports_plan_id_idx
  on public.reports (plan_id);

create index if not exists reports_evaluation_id_idx
  on public.reports (evaluation_id);

-- Intentionally omitted from this production-safe draft:
-- - create index if not exists plan_projects_plan_id_idx ...
-- - create index if not exists plan_projects_project_id_idx ...
-- - create index if not exists plan_projects_evaluation_id_idx ...
-- - create index if not exists plan_kpi_snapshots_plan_id_idx ...
--
-- Reason:
-- - live staging already shows existing legacy indexes for:
--   * plan_projects(plan_id)
--   * plan_projects(project_id)
--   * plan_kpi_snapshots(plan_id)
-- - Sprint 2K created duplicate indexes by using new names on equivalent columns
-- - evaluation_id on plan_projects may be added separately only after target-env preflight confirms it is missing

-- ============================================================================
-- 4. Production preflight reminders
-- ============================================================================

-- Before any production apply, confirm:
-- 1. target-env indexes on:
--    - plan_projects(plan_id)
--    - plan_projects(project_id)
--    - plan_projects(evaluation_id)
--    - plan_kpi_snapshots(plan_id)
-- 2. target-env FK presence on:
--    - plan_projects_plan_id_fkey
--    - plan_projects_project_id_fkey
--    - plan_projects_evaluation_id_fkey
--    - plan_kpi_snapshots_plan_id_fkey
-- 3. target-env reports row counts and mixed-lineage distribution
-- 4. no NOT NULL or RLS enable is bundled into the same release

commit;

select
  'Draft complete: safe candidate for post-preflight production review.' as next_step_notice;
