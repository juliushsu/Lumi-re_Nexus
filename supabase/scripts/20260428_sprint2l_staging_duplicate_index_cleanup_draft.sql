begin;

-- CIRQUA Sprint 2L staging cleanup draft
-- Do not execute automatically.
-- This draft only addresses duplicate non-constraint indexes introduced by Sprint 2K on staging.

-- Pre-cleanup checklist:
-- 1. confirm the legacy index still exists
-- 2. confirm the duplicate index is not referenced by any migration expectation
-- 3. confirm no query-plan regression concern for the target staging session

drop index if exists public.plan_projects_plan_id_idx;
drop index if exists public.plan_projects_project_id_idx;
drop index if exists public.plan_kpi_snapshots_plan_id_idx;

-- Keep these:
-- - idx_plan_projects_plan_id
-- - idx_plan_projects_project_id
-- - idx_kpi_snapshots_plan_id
-- - plan_projects_evaluation_id_idx
-- - all PK / unique indexes
-- - all tenant-root indexes on investment_plans / reports

commit;
