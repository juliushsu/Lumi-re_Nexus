-- CIRQUA Sprint 2I-B
-- Draft only. Do not apply directly to production.
-- This file is intentionally non-executable as a migration rollout plan.
-- It documents tenant key hardening steps required before broader business-table RLS.

select
  'Sprint 2I-B draft only: review, adapt per environment, and execute in staged phases after data validation.' as draft_notice,
  'Do not run this file as-is in production.' as production_notice;

-- ============================================================================
-- 1. Root org-scoped tables that likely need explicit org_id
-- ============================================================================

-- investment_plans is currently a tenant root without org_id.
-- Draft: add nullable org_id first, backfill later from approved manual mapping,
-- then add FK only after validation. Do not set NOT NULL in this phase.

-- alter table public.investment_plans
--   add column if not exists org_id uuid;

-- comment on column public.investment_plans.org_id is
--   'Draft tenant root key. Nullable during staged backfill. Required before plan-scoped RLS becomes safe.';

-- reports is a mixed-root table that may point to project_id, plan_id, and/or evaluation_id.
-- Draft: add nullable org_id as a simplified tenant key for future RLS, then backfill from
-- project/evaluation/plan anchors where possible.

-- alter table public.reports
--   add column if not exists org_id uuid;

-- comment on column public.reports.org_id is
--   'Draft tenant key for mixed-root reporting rows. Backfill from project/evaluation/plan lineage before staged RLS.';

-- ============================================================================
-- 2. Manual mapping tables for roots that cannot be safely auto-inferred
-- ============================================================================

-- investment_plans currently has no reliable org lineage in schema.
-- Draft manual mapping table:

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
--   'Draft-only manual review table for assigning investment_plans.org_id when no safe automatic inference path exists.';

-- Optional follow-up manual map for reports that remain unresolved after project/evaluation/plan derivation:
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

-- 3A. reports.project_id can often be backfilled from project_evaluations
-- when evaluation_id exists and project_id is null.

-- update public.reports r
-- set project_id = pe.project_id
-- from public.project_evaluations pe
-- where r.project_id is null
--   and r.evaluation_id = pe.id
--   and pe.project_id is not null;

-- 3B. plan_projects.project_id can often be backfilled from project_evaluations
-- when evaluation_id exists and project_id is null.

-- update public.plan_projects pp
-- set project_id = pe.project_id
-- from public.project_evaluations pe
-- where pp.project_id is null
--   and pp.evaluation_id = pe.id
--   and pe.project_id is not null;

-- 3C. reports.org_id backfill order:
-- 1. direct from reports.project_id -> projects.org_id
-- 2. fallback from reports.evaluation_id -> project_evaluations.project_id -> projects.org_id
-- 3. fallback from reports.plan_id -> investment_plans.org_id only after plans are mapped
-- 4. anything unresolved goes to manual mapping

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

-- 3D. investment_plans.org_id backfill must be manual-first.
-- Do not guess production tenant from names or free text.

-- update public.investment_plans ip
-- set org_id = m.proposed_org_id
-- from app.investment_plan_org_backfill_manual_map m
-- where ip.id = m.plan_id
--   and ip.org_id is null
--   and m.approved_for_backfill = true
--   and m.proposed_org_id is not null;

-- 3E. reports unresolved after automatic derivation:
-- update public.reports r
-- set org_id = m.proposed_org_id
-- from app.report_org_backfill_manual_map m
-- where r.id = m.report_id
--   and r.org_id is null
--   and m.approved_for_backfill = true
--   and m.proposed_org_id is not null;

-- ============================================================================
-- 4. FK drafts
-- Add with NOT VALID first. Validate only after cleanup.
-- ============================================================================

-- alter table public.investment_plans
--   add constraint investment_plans_org_id_fkey
--   foreign key (org_id) references public.organizations(id)
--   not valid;

-- alter table public.reports
--   add constraint reports_org_id_fkey
--   foreign key (org_id) references public.organizations(id)
--   not valid;

-- alter table public.project_evaluations
--   add constraint project_evaluations_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.project_costs
--   add constraint project_costs_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.project_cost_items
--   add constraint project_cost_items_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.project_cast_costs
--   add constraint project_cast_costs_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.project_revenues
--   add constraint project_revenues_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.project_festival_records
--   add constraint project_festival_records_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.plan_projects
--   add constraint plan_projects_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.plan_projects
--   add constraint plan_projects_plan_id_fkey
--   foreign key (plan_id) references public.investment_plans(id)
--   not valid;

-- alter table public.plan_kpi_snapshots
--   add constraint plan_kpi_snapshots_plan_id_fkey
--   foreign key (plan_id) references public.investment_plans(id)
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

-- alter table public.project_source_links
--   add constraint project_source_links_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.external_import_field_mappings
--   add constraint external_import_field_mappings_project_id_fkey
--   foreign key (project_id) references public.projects(id)
--   not valid;

-- alter table public.external_import_audit_logs
--   add constraint external_import_audit_logs_project_id_fkey
--   foreign key (project_id) references public.projects(id)
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

-- create index if not exists project_evaluations_project_id_idx
--   on public.project_evaluations (project_id);

-- create index if not exists project_costs_project_id_idx
--   on public.project_costs (project_id);

-- create index if not exists project_cost_items_project_id_idx
--   on public.project_cost_items (project_id);

-- create index if not exists project_cast_costs_project_id_idx
--   on public.project_cast_costs (project_id);

-- create index if not exists project_revenues_project_id_idx
--   on public.project_revenues (project_id);

-- create index if not exists project_festival_records_project_id_idx
--   on public.project_festival_records (project_id);

-- create index if not exists plan_projects_plan_id_idx
--   on public.plan_projects (plan_id);

-- create index if not exists plan_projects_project_id_idx
--   on public.plan_projects (project_id);

-- create index if not exists plan_kpi_snapshots_plan_id_idx
--   on public.plan_kpi_snapshots (plan_id);

-- create index if not exists project_source_links_project_id_idx
--   on public.project_source_links (project_id);

-- create index if not exists external_import_field_mappings_project_id_idx
--   on public.external_import_field_mappings (project_id);

-- create index if not exists external_import_audit_logs_project_id_idx
--   on public.external_import_audit_logs (project_id);

-- ============================================================================
-- 6. Explicit no-go sections
-- ============================================================================

-- DO NOT directly apply the following in production in the same change set:
-- - any NOT NULL on newly added org_id columns
-- - any VALIDATE CONSTRAINT on newly added FKs before cleanup
-- - any business-table RLS enable/replace statements
-- - any automatic org assignment for investment_plans without approved manual mapping
-- - any report org backfill that guesses tenant from free text, entity name, or report title

select
  'Draft complete: review with CTO before Sprint 2J.' as next_step_notice;
