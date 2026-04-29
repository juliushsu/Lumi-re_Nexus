begin;

-- CIRQUA Sprint 2K
-- Staging-only tenant root schema dry run for:
-- - public.investment_plans
-- - public.reports
-- - public.plan_projects
-- - public.plan_kpi_snapshots
--
-- This migration intentionally does not:
-- - enable or disable RLS
-- - add NOT NULL to tenant root columns
-- - validate every new FK immediately
-- - touch production

alter table public.investment_plans
  add column if not exists org_id uuid;

comment on column public.investment_plans.org_id is
  'Staging-first tenant root key. Nullable during tenant mapping and verification. Do not enforce NOT NULL until backfill is complete.';

alter table public.reports
  add column if not exists org_id uuid;

comment on column public.reports.org_id is
  'Staging-first tenant root key for mixed-root report rows. Nullable during lineage reconciliation and verification.';

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

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'plan_projects_plan_id_fkey'
      and conrelid = 'public.plan_projects'::regclass
  ) then
    alter table public.plan_projects
      add constraint plan_projects_plan_id_fkey
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
    where conname = 'plan_projects_project_id_fkey'
      and conrelid = 'public.plan_projects'::regclass
  ) then
    alter table public.plan_projects
      add constraint plan_projects_project_id_fkey
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
    where conname = 'plan_projects_evaluation_id_fkey'
      and conrelid = 'public.plan_projects'::regclass
  ) then
    alter table public.plan_projects
      add constraint plan_projects_evaluation_id_fkey
      foreign key (evaluation_id) references public.project_evaluations(id)
      not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'plan_kpi_snapshots_plan_id_fkey'
      and conrelid = 'public.plan_kpi_snapshots'::regclass
  ) then
    alter table public.plan_kpi_snapshots
      add constraint plan_kpi_snapshots_plan_id_fkey
      foreign key (plan_id) references public.investment_plans(id)
      not valid;
  end if;
end
$$;

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

create index if not exists plan_projects_plan_id_idx
  on public.plan_projects (plan_id);

create index if not exists plan_projects_project_id_idx
  on public.plan_projects (project_id);

create index if not exists plan_projects_evaluation_id_idx
  on public.plan_projects (evaluation_id);

create index if not exists plan_kpi_snapshots_plan_id_idx
  on public.plan_kpi_snapshots (plan_id);

commit;
