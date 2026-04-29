-- CIRQUA Sprint 2J
-- Staging-first draft only.
-- Do not apply directly to production.
-- This file is intentionally a reviewed draft, not an executable rollout.

select
  'Sprint 2J draft only: investment_plans / reports tenant-root staging design.' as draft_notice,
  'Not production-ready. Review preflight findings before any apply.' as production_notice;

-- ============================================================================
-- 1. Tenant root columns
-- ============================================================================

-- investment_plans is a tenant root and currently has no org_id.
-- Add nullable org_id first. Do not set NOT NULL in this phase.

-- alter table public.investment_plans
--   add column if not exists org_id uuid;

-- comment on column public.investment_plans.org_id is
--   'Staging-first tenant root key. Nullable during manual backfill and validation. Required before safe plan-scoped RLS.';

-- reports is a mixed-root table that may point to project, evaluation, or plan lineage.
-- Add nullable org_id to simplify future tenant RLS and reduce scope ambiguity.

-- alter table public.reports
--   add column if not exists org_id uuid;

-- comment on column public.reports.org_id is
--   'Staging-first tenant root key for reporting rows. Backfill from project/evaluation/plan lineage, then manual review if unresolved.';

-- ============================================================================
-- 2. Manual mapping support
-- ============================================================================

-- investment_plans currently has zero rows in staging, but the schema still needs
-- a manual-first mapping path before production assumptions are ever made.

-- create schema if not exists app;

-- create table if not exists app.investment_plan_org_backfill_manual_map (
--   plan_id uuid primary key,
--   current_org_id uuid,
--   proposed_org_id uuid,
--   confidence text not null default 'low',
--   reason text not null,
--   reviewed_at timestamptz,
--   approved_for_backfill boolean not null default false,
--   created_at timestamptz not null default timezone('utc', now()),
--   updated_at timestamptz not null default timezone('utc', now())
-- );

-- comment on table app.investment_plan_org_backfill_manual_map is
--   'Manual-first mapping table for investment_plans.org_id. Required because plan rows have no safe automatic tenant lineage.';

-- Optional manual map for reports only after automated derivation is exhausted.
-- create table if not exists app.report_org_backfill_manual_map (
--   report_id uuid primary key,
--   current_org_id uuid,
--   proposed_org_id uuid,
--   confidence text not null default 'low',
--   reason text not null,
--   reviewed_at timestamptz,
--   approved_for_backfill boolean not null default false,
--   created_at timestamptz not null default timezone('utc', now()),
--   updated_at timestamptz not null default timezone('utc', now())
-- );

-- ============================================================================
-- 3. Backfill drafts
-- ============================================================================

-- 3A. reports.project_id can be backfilled from evaluation lineage where safe.

-- update public.reports r
-- set project_id = pe.project_id
-- from public.project_evaluations pe
-- where r.project_id is null
--   and r.evaluation_id = pe.id
--   and pe.project_id is not null;

-- 3B. plan_projects.project_id can be backfilled from evaluation lineage where safe.

-- update public.plan_projects pp
-- set project_id = pe.project_id
-- from public.project_evaluations pe
-- where pp.project_id is null
--   and pp.evaluation_id = pe.id
--   and pe.project_id is not null;

-- 3C. reports.org_id backfill order:
-- 1. reports.project_id -> projects.org_id
-- 2. reports.evaluation_id -> project_evaluations.project_id -> projects.org_id
-- 3. reports.plan_id -> investment_plans.org_id (after plans are mapped)
-- 4. manual review for unresolved rows

-- update public.reports r
-- set org_id = p.org_id
-- from public.projects p
-- where r.org_id is null
--   and r.project_id = p.id
--   and p.org_id is not null;

-- update public.reports r
-- set org_id = p.org_id,
--     project_id = coalesce(r.project_id, pe.project_id)
-- from public.project_evaluations pe
-- join public.projects p
--   on p.id = pe.project_id
-- where r.org_id is null
--   and r.evaluation_id = pe.id
--   and pe.project_id is not null
--   and p.org_id is not null;

-- update public.reports r
-- set org_id = ip.org_id
-- from public.investment_plans ip
-- where r.org_id is null
--   and r.plan_id = ip.id
--   and ip.org_id is not null;

-- 3D. investment_plans.org_id is manual-first only.
-- Never infer from entity_name, plan_name, report text, or other weak signals.

-- update public.investment_plans ip
-- set org_id = m.proposed_org_id
-- from app.investment_plan_org_backfill_manual_map m
-- where ip.id = m.plan_id
--   and ip.org_id is null
--   and m.approved_for_backfill = true
--   and m.proposed_org_id is not null;

-- 3E. report fallback manual mapping.

-- update public.reports r
-- set org_id = m.proposed_org_id
-- from app.report_org_backfill_manual_map m
-- where r.id = m.report_id
--   and r.org_id is null
--   and m.approved_for_backfill = true
--   and m.proposed_org_id is not null;

-- ============================================================================
-- 4. FK drafts
-- Add as NOT VALID first. Validate only after cleanup.
-- ============================================================================

-- alter table public.investment_plans
--   add constraint investment_plans_org_id_fkey
--   foreign key (org_id) references public.organizations(id)
--   not valid;

-- alter table public.reports
--   add constraint reports_org_id_fkey
--   foreign key (org_id) references public.organizations(id)
--   not valid;

-- alter table public.reports
--   add constraint reports_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.reports
--   add constraint reports_plan_id_fkey
--   foreign key (plan_id) references public.investment_plans(id)
--   not valid;

-- alter table public.reports
--   add constraint reports_evaluation_id_fkey
--   foreign key (evaluation_id) references public.project_evaluations(id)
--   not valid;

-- alter table public.plan_projects
--   add constraint plan_projects_plan_id_fkey
--   foreign key (plan_id) references public.investment_plans(id)
--   not valid;

-- alter table public.plan_projects
--   add constraint plan_projects_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.plan_projects
--   add constraint plan_projects_evaluation_id_fkey
--   foreign key (evaluation_id) references public.project_evaluations(id)
--   not valid;

-- alter table public.plan_kpi_snapshots
--   add constraint plan_kpi_snapshots_plan_id_fkey
--   foreign key (plan_id) references public.investment_plans(id)
--   not valid;

-- ============================================================================
-- 5. Index drafts
-- ============================================================================

-- create index if not exists investment_plans_org_id_idx
--   on public.investment_plans (org_id);

-- create index if not exists reports_org_id_idx
--   on public.reports (org_id);

-- create index if not exists reports_project_id_idx
--   on public.reports (project_id);

-- create index if not exists reports_plan_id_idx
--   on public.reports (plan_id);

-- create index if not exists reports_evaluation_id_idx
--   on public.reports (evaluation_id);

-- create index if not exists plan_projects_plan_id_idx
--   on public.plan_projects (plan_id);

-- create index if not exists plan_projects_project_id_idx
--   on public.plan_projects (project_id);

-- create index if not exists plan_projects_evaluation_id_idx
--   on public.plan_projects (evaluation_id);

-- create index if not exists plan_kpi_snapshots_plan_id_idx
--   on public.plan_kpi_snapshots (plan_id);

-- ============================================================================
-- 6. Why NOT NULL is deferred
-- ============================================================================

-- Keep org_id nullable in this phase because:
-- 1. investment_plans has no safe automatic tenant lineage today
-- 2. reports may need multi-step derivation and manual review
-- 3. staged rollout must allow validation before enforcing mandatory tenant root
-- 4. production backfill rules are still unsettled

-- NOT NULL should only be considered after:
-- - manual mapping is approved
-- - backfill verification query returns zero unresolved roots
-- - FKs are added and validated
-- - staging dry run succeeds without breaking downstream flows

-- ============================================================================
-- 7. Explicit no-go
-- ============================================================================

-- Do not do any of the following in the same first apply:
-- - set NOT NULL on investment_plans.org_id
-- - set NOT NULL on reports.org_id
-- - validate FKs immediately
-- - enable or replace business-table RLS
-- - infer tenant from free text fields

select
  'Draft complete: if approved, next step is Sprint 2K staging dry run.' as next_step_notice;
