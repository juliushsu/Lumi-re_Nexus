# CIRQUA Sprint 2C Preflight Snapshot

This snapshot was prepared for the staging-only tenant migration dry run on `2026-04-28`.

## Source Notes
- Immediate preflight structural checks were captured right before applying the staging migration.
- The earlier canonical baseline from [CIRQUA_CANONICAL_BASELINE_20260428.md](/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_CANONICAL_BASELINE_20260428.md) remains the source of truth for the pre-migration table / RLS / grant shape.
- Exact row counts for existing public tables are represented by the post-migration counts below because the Sprint 2C migration:
  - added new schema objects only
  - did not insert, update, or delete any existing `public.*` rows
  - inserted only into `app.project_org_backfill_manual_map`

## Preflight Structural State
- `public.organizations` existed before apply: no
- `public.projects.org_id` existed before apply: no
- `public.user_profiles.org_id` existed before apply: no
- `app.project_org_backfill_manual_map` existed before apply: no

## Public Tables Before Apply
- `board_action_items`
- `board_meetings`
- `board_resolutions`
- `external_budget_snapshots`
- `external_import_audit_logs`
- `external_import_field_mappings`
- `external_import_runs`
- `external_project_snapshots`
- `festival_events`
- `investment_plans`
- `plan_kpi_snapshots`
- `plan_projects`
- `project_cast_costs`
- `project_cost_items`
- `project_costs`
- `project_evaluations`
- `project_festival_records`
- `project_revenues`
- `project_source_links`
- `projects`
- `reports`
- `roi_model_change_logs`
- `roi_model_weights`
- `roi_models`
- `user_profiles`

## Row Counts
Existing public table counts remained stable across the dry run.

| table | preflight row count |
| --- | ---: |
| `board_action_items` | 0 |
| `board_meetings` | 0 |
| `board_resolutions` | 0 |
| `external_budget_snapshots` | 1 |
| `external_import_audit_logs` | 13 |
| `external_import_field_mappings` | 7 |
| `external_import_runs` | 1 |
| `external_project_snapshots` | 1 |
| `festival_events` | 8 |
| `investment_plans` | 0 |
| `plan_kpi_snapshots` | 0 |
| `plan_projects` | 0 |
| `project_cast_costs` | 0 |
| `project_cost_items` | 0 |
| `project_costs` | 0 |
| `project_evaluations` | 1 |
| `project_festival_records` | 0 |
| `project_revenues` | 0 |
| `project_source_links` | 1 |
| `projects` | 1 |
| `reports` | 0 |
| `roi_model_change_logs` | 0 |
| `roi_model_weights` | 0 |
| `roi_models` | 5 |
| `user_profiles` | 5 |

Absent before apply:
- `public.organizations`
- `app.project_org_backfill_manual_map`

## Projects State Before Apply
- `projects` rows: `1`
- `projects.org_id` column: absent
- known project summary:
  - `e39feb8d-9bfe-44a8-b83e-7adb33ad0ab8` / `API 驗證專案`

## Users / Profiles State Before Apply
- `auth.users` rows: `7`
- `public.user_profiles` rows: `5`
- `public.user_profiles.org_id` column: absent
- role/status summary:
  - `analyst / active`: `1`
  - `shareholder_viewer / active`: `2`
  - `super_admin / active`: `2`

## RLS Enabled Before Apply
RLS already enabled:
- `board_action_items`
- `board_meetings`
- `board_resolutions`
- `external_budget_snapshots`
- `external_import_audit_logs`
- `external_import_field_mappings`
- `external_import_runs`
- `external_project_snapshots`
- `investment_plans`
- `project_evaluations`
- `project_source_links`
- `projects`
- `reports`
- `roi_model_change_logs`
- `roi_models`
- `user_profiles`

RLS not enabled:
- `festival_events`
- `plan_kpi_snapshots`
- `plan_projects`
- `project_cast_costs`
- `project_cost_items`
- `project_costs`
- `project_festival_records`
- `project_revenues`
- `roi_model_weights`

## Grants Summary Before Apply
Current direct `anon` table privileges still open:
- `festival_events`
- `plan_kpi_snapshots`
- `plan_projects`
- `project_cast_costs`
- `project_cost_items`
- `project_costs`
- `project_festival_records`
- `project_revenues`

Current direct `anon` access blocked:
- `projects`
- `project_evaluations`
- `investment_plans`
- `reports`
- `roi_models`
- `user_profiles`

## Frontend Read Safety Check Before Apply
These checks were executed immediately before the staging migration:
- `anon -> projects` remained blocked:
  - `401`
  - `42501 permission denied for table projects`
- `service_role -> projects` remained readable:
  - `200`
  - returned existing project id `e39feb8d-9bfe-44a8-b83e-7adb33ad0ab8`

Because the Sprint 2C migration only introduced nullable columns and new tables, with no grant or RLS changes, this preflight indicated low immediate risk of breaking existing frontend reads.
