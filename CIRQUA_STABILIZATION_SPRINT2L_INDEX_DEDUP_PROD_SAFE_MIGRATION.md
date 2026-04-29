# CIRQUA Stabilization Sprint 2L Index Dedup & Production-Safe Migration

## Scope
This round did not apply any migration.
This round did not touch production.
This round did not enable RLS and did not add new product behavior.

Artifacts produced:
- [supabase/migrations/20260428_sprint2l_investment_reports_tenant_root_prod_safe_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2l_investment_reports_tenant_root_prod_safe_draft.sql)
- [supabase/scripts/20260428_sprint2l_staging_duplicate_index_cleanup_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2l_staging_duplicate_index_cleanup_draft.sql)
- [supabase/queries/20260428_sprint2l_index_dedup_verification.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/queries/20260428_sprint2l_index_dedup_verification.sql)

## Duplicate Index Audit
Live staging read-only audit on `2026-04-29` confirmed:

### `investment_plans`
| index name | columns | duplicate | constraint-backed | keep | note |
| --- | --- | --- | --- | --- | --- |
| `investment_plans_pkey` | `id` | no | yes, PK | keep | automatic primary-key index |
| `investment_plans_plan_code_key` | `plan_code` | no | yes, UNIQUE | keep | automatic unique index |
| `idx_plans_status` | `plan_status` | no | no | keep | legacy business filter index |
| `idx_plans_vintage_year` | `vintage_year` | no | no | keep | legacy business filter index |
| `investment_plans_org_id_idx` | `org_id` | no | no | keep | tenant-root lookup index from Sprint 2K |

### `reports`
| index name | columns | duplicate | constraint-backed | keep | note |
| --- | --- | --- | --- | --- | --- |
| `reports_pkey` | `id` | no | yes, PK | keep | automatic primary-key index |
| `reports_report_code_key` | `report_code` | no | yes, UNIQUE | keep | automatic unique index |
| `reports_org_id_idx` | `org_id` | no | no | keep | tenant-root lookup index |
| `reports_project_id_idx` | `project_id` | no | no | keep | lineage lookup index |
| `reports_plan_id_idx` | `plan_id` | no | no | keep | lineage lookup index |
| `reports_evaluation_id_idx` | `evaluation_id` | no | no | keep | lineage lookup index |

### `plan_projects`
| index name | columns | duplicate | constraint-backed | keep | note |
| --- | --- | --- | --- | --- | --- |
| `plan_projects_pkey` | `id` | no | yes, PK | keep | automatic primary-key index |
| `idx_plan_projects_plan_id` | `plan_id` | yes | no | keep | legacy lineage index |
| `plan_projects_plan_id_idx` | `plan_id` | yes | no | remove in staging / avoid in prod | duplicate introduced by Sprint 2K |
| `idx_plan_projects_project_id` | `project_id` | yes | no | keep | legacy lineage index |
| `plan_projects_project_id_idx` | `project_id` | yes | no | remove in staging / avoid in prod | duplicate introduced by Sprint 2K |
| `plan_projects_evaluation_id_idx` | `evaluation_id` | no | no | keep | unique useful lineage index; not duplicate in live staging |

### `plan_kpi_snapshots`
| index name | columns | duplicate | constraint-backed | keep | note |
| --- | --- | --- | --- | --- | --- |
| `plan_kpi_snapshots_pkey` | `id` | no | yes, PK | keep | automatic primary-key index |
| `idx_kpi_snapshots_date` | `snapshot_date` | no | no | keep | legacy time-series filter index |
| `idx_kpi_snapshots_plan_id` | `plan_id` | yes | no | keep | legacy lineage index |
| `plan_kpi_snapshots_plan_id_idx` | `plan_id` | yes | no | remove in staging / avoid in prod | duplicate introduced by Sprint 2K |

## Corrected Migration Summary
The corrected draft changes the 2K strategy in one important way:
- it still adds nullable `org_id` on `investment_plans` and `reports`
- it still adds tenant-root and lineage FKs as `NOT VALID`
- it still avoids `NOT NULL`
- it still avoids RLS changes
- but it **stops creating new plan-child indexes** where equivalent legacy indexes already exist

Production-safe draft keeps:
- `investment_plans_org_id_idx`
- `reports_org_id_idx`
- `reports_project_id_idx`
- `reports_plan_id_idx`
- `reports_evaluation_id_idx`

Production-safe draft intentionally omits:
- `plan_projects_plan_id_idx`
- `plan_projects_project_id_idx`
- `plan_projects_evaluation_id_idx`
- `plan_kpi_snapshots_plan_id_idx`

Why omit `plan_projects_evaluation_id_idx` as well:
- it is already present on live staging
- this round is meant to be production-safe under preflight uncertainty
- if another environment lacks it, that can be handled by a separate narrowly scoped index migration after target-env verification

## Staging Cleanup Recommendation
Cleanup is recommended for staging, but not auto-executed.

Suggested staging-only cleanup draft:
- drop `plan_projects_plan_id_idx`
- drop `plan_projects_project_id_idx`
- drop `plan_kpi_snapshots_plan_id_idx`

Do not drop:
- PK indexes
- unique constraint indexes
- `plan_projects_evaluation_id_idx`
- tenant-root indexes on `investment_plans` and `reports`

## Verification Query Summary
The new verification query checks:
1. target table row counts
2. tenant-root column existence on:
   - `investment_plans.org_id`
   - `reports.org_id`
3. FK validity state
4. duplicate indexes by exact column list
5. full index listing for manual review

## Can We Enter Sprint 2M?
Recommendation: yes.

Sprint 2M should focus on:
- business-table RLS staged plan
- especially how `reports` should scope under mixed lineage
- whether `investment_plans` can become a clean org-scoped root before downstream business-table RLS expands

Suggested prerequisite before any production candidate is approved:
- run the 2L verification query on the exact target environment
- confirm whether `plan_projects_evaluation_id_idx` already exists there
- if staging cleanup is desired, execute only the cleanup draft and re-run index verification

## CTO Go / No-Go
### Go
- for Sprint 2M staged RLS planning
- for using the corrected 2L draft as the new baseline for production review
- for keeping the new tenant-root columns nullable until backfill and lineage verification are complete

### No-Go
- for production rollout without fresh target-env preflight
- for reusing the raw Sprint 2K migration in production
- for bundling index cleanup, tenant backfill, FK validation, and RLS enable into one release
