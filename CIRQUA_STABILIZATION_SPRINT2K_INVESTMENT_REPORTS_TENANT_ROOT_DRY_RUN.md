# CIRQUA Stabilization Sprint 2K Investment Plans / Reports Tenant Root Dry Run

## Scope
This round applied the tenant-root schema dry run to **staging only** for:
- `investment_plans`
- `reports`
- `plan_projects`
- `plan_kpi_snapshots`

Production was not touched.
No business-table RLS was enabled or changed in this round.
No `NOT NULL` constraint was added.

Applied staging migration:
- [supabase/migrations/20260428_sprint2k_investment_reports_tenant_root_staging.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2k_investment_reports_tenant_root_staging.sql)

Preflight snapshot:
- [CIRQUA_SPRINT2K_PREFLIGHT_SNAPSHOT.md](/private/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_SPRINT2K_PREFLIGHT_SNAPSHOT.md)

Rollback draft prepared but not executed:
- [supabase/scripts/20260428_sprint2k_investment_reports_tenant_root_staging_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2k_investment_reports_tenant_root_staging_rollback_draft.sql)

## Preflight Summary
Starting state before apply:
- `investment_plans` rows: `0`
- `reports` rows: `0`
- `plan_projects` rows: `0`
- `plan_kpi_snapshots` rows: `0`
- `investment_plans.org_id`: absent
- `reports.org_id`: absent

Existing lineage hardening already present before apply:
- `plan_kpi_snapshots_plan_id_fkey`
- `plan_projects_plan_id_fkey`
- `plan_projects_project_id_fkey`
- `plan_projects_evaluation_id_fkey`

Existing RLS state before apply:
- `investment_plans`: enabled
- `reports`: enabled
- `plan_projects`: disabled
- `plan_kpi_snapshots`: disabled

Important preflight nuance:
- `plan_projects` and `plan_kpi_snapshots` already had legacy indexes on `plan_id` and `project_id`.
- `reports` did not yet have formal lineage FKs.
- `investment_plans` did not yet have a tenant root column.

## Migration Apply Result
Migration apply response:
- status: `200`
- migration name:
  - `codex_1777443368732_sprint2k_investment_reports_tenant_root_staging`

Schema changes introduced on staging:
1. added nullable `public.investment_plans.org_id`
2. added nullable `public.reports.org_id`
3. added `NOT VALID` FK:
   - `investment_plans_org_id_fkey`
4. added `NOT VALID` FKs:
   - `reports_org_id_fkey`
   - `reports_project_id_fkey`
   - `reports_plan_id_fkey`
   - `reports_evaluation_id_fkey`
5. attempted to add plan-child FKs by name, but those already existed and were left unchanged
6. added indexes for new tenant-root and lineage access paths

What this migration intentionally did not do:
- no row backfill
- no `NOT NULL`
- no FK validation pass
- no RLS enable/disable
- no production migration

## Verification Results
### Column verification
After apply:
- `investment_plans.org_id` exists
  - type: `uuid`
  - nullable: `YES`
- `reports.org_id` exists
  - type: `uuid`
  - nullable: `YES`

### FK verification
After apply:
- new FK present:
  - `investment_plans_org_id_fkey`
  - `NOT VALID`
- new FKs present:
  - `reports_org_id_fkey`
  - `reports_project_id_fkey`
  - `reports_plan_id_fkey`
  - `reports_evaluation_id_fkey`
  - all `NOT VALID`

Still present from preflight:
- `plan_kpi_snapshots_plan_id_fkey`
- `plan_projects_plan_id_fkey`
- `plan_projects_project_id_fkey`
- `plan_projects_evaluation_id_fkey`

### Index verification
After apply, new indexes present:
- `investment_plans_org_id_idx`
- `reports_org_id_idx`
- `reports_project_id_idx`
- `reports_plan_id_idx`
- `reports_evaluation_id_idx`
- `plan_projects_plan_id_idx`
- `plan_projects_project_id_idx`
- `plan_projects_evaluation_id_idx`
- `plan_kpi_snapshots_plan_id_idx`

Important verification note:
- `plan_projects_plan_id_idx` duplicates the existing `idx_plan_projects_plan_id`
- `plan_projects_project_id_idx` duplicates the existing `idx_plan_projects_project_id`
- `plan_kpi_snapshots_plan_id_idx` duplicates the existing `idx_kpi_snapshots_plan_id`

This did not break staging, but it means the current 2K migration should **not** be reused for production as-is.

### Row count verification
Row counts did not change:
- `investment_plans`: still `0`
- `reports`: still `0`
- `plan_projects`: still `0`
- `plan_kpi_snapshots`: still `0`

### RLS verification
RLS state did not change:
- `investment_plans`: still enabled
- `reports`: still enabled
- `plan_projects`: still disabled
- `plan_kpi_snapshots`: still disabled

### Production verification
- no production endpoint or production database was targeted
- this apply used staging management API only

## Data Mutation Assessment
Actual data mutation:
- schema-only changes on staging
- `0` row-count change across all four target tables
- no tenant backfill performed
- no tenant inference performed

No observed breakage:
- no migration SQL error
- no RLS error introduced
- no row-level data corruption observed

Observed implementation issue:
- duplicate lineage indexes were created on:
  - `plan_projects.plan_id`
  - `plan_projects.project_id`
  - `plan_kpi_snapshots.plan_id`

This is a staging-safe issue, but it needs cleanup before any production-ready tenant-root migration is drafted.

## Rollback Plan
Rollback draft exists at:
- [supabase/scripts/20260428_sprint2k_investment_reports_tenant_root_staging_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2k_investment_reports_tenant_root_staging_rollback_draft.sql)

Rollback would:
1. drop the new indexes introduced in 2K
2. drop the new `NOT VALID` FKs on `investment_plans` and `reports`
3. drop the 2K-added columns:
   - `investment_plans.org_id`
   - `reports.org_id`

Rollback was not executed because staging did not block.

## Can We Enter Sprint 2L?
Recommendation: yes, with one condition.

Sprint 2L can proceed for:
- business-table RLS staged planning
- deciding how `reports` should scope through:
  - direct `org_id`
  - `project_id`
  - `evaluation_id`
  - `plan_id`
- deciding whether `plan_projects` should remain lineage-derived only

Condition before any production-ready follow-up:
- de-duplicate the newly created plan-child indexes in the next staging refinement or in a production-safe replacement migration

## CTO Go / No-Go
### Go
- for Sprint 2L staged planning on business-table RLS
- for keeping `investment_plans.org_id` and `reports.org_id` nullable during staging
- for keeping plan-child rows lineage-derived rather than adding more tenant root columns immediately

### No-Go
- for production rollout of this exact 2K migration
- for `NOT NULL` on the new tenant root columns
- for FK validation before real rows and backfill logic exist
- for enabling additional business-table RLS before the duplicate-index cleanup and lineage policy design are reviewed
