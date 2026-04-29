# CIRQUA Sprint 2K Preflight Snapshot

Captured from staging on `2026-04-29` before applying:
- [supabase/migrations/20260428_sprint2k_investment_reports_tenant_root_staging.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2k_investment_reports_tenant_root_staging.sql)

## Row Counts
- `investment_plans`: `0`
- `reports`: `0`
- `plan_projects`: `0`
- `plan_kpi_snapshots`: `0`

## Existing Columns
### `investment_plans`
- no `org_id` column yet
- existing columns end at:
  - `updated_at`

### `reports`
- no `org_id` column yet
- existing lineage columns:
  - `plan_id`
  - `project_id`
  - `evaluation_id`

### `plan_projects`
- lineage columns already present:
  - `plan_id`
  - `project_id`
  - `evaluation_id`

### `plan_kpi_snapshots`
- lineage root already present:
  - `plan_id`

## Existing FK State
Preflight live FK confirmation showed:
- `plan_kpi_snapshots_plan_id_fkey`
  - `plan_id -> investment_plans.id`
  - already exists
  - validated
- `plan_projects_plan_id_fkey`
  - `plan_id -> investment_plans.id`
  - already exists
  - validated
- `plan_projects_project_id_fkey`
  - `project_id -> projects.id`
  - already exists
  - validated
- `plan_projects_evaluation_id_fkey`
  - `evaluation_id -> project_evaluations.id`
  - already exists
  - validated

Preflight did not show these yet:
- `investment_plans_org_id_fkey`
- `reports_org_id_fkey`
- `reports_project_id_fkey`
- `reports_plan_id_fkey`
- `reports_evaluation_id_fkey`

## Existing Index State
### `investment_plans`
- `investment_plans_pkey`
- `investment_plans_plan_code_key`
- `idx_plans_status`
- `idx_plans_vintage_year`

### `reports`
- `reports_pkey`
- `reports_report_code_key`

### `plan_projects`
- `plan_projects_pkey`
- `idx_plan_projects_plan_id`
- `idx_plan_projects_project_id`

### `plan_kpi_snapshots`
- `plan_kpi_snapshots_pkey`
- `idx_kpi_snapshots_plan_id`
- `idx_kpi_snapshots_date`

## RLS State
- `investment_plans`
  - `RLS enabled = true`
- `reports`
  - `RLS enabled = true`
- `plan_projects`
  - `RLS enabled = false`
- `plan_kpi_snapshots`
  - `RLS enabled = false`

## Preflight Interpretation
- The four target tables are structurally quiet right now because all row counts are `0`.
- `investment_plans` and `reports` still need tenant root columns.
- `plan_projects` and `plan_kpi_snapshots` already have useful lineage keys and some FK coverage, so 2K can focus on root-column prep without doing tenant backfill or RLS expansion.
