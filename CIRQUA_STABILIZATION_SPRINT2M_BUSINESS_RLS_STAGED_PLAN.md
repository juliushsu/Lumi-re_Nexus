# CIRQUA Stabilization Sprint 2M Business Tables RLS Staged Plan

## Scope
This round is a staged RLS planning pass only.

No migration was applied.
No production system was touched.
No new client or backend feature was introduced.

Artifacts produced:
- [supabase/migrations/20260428_sprint2m_business_tables_rls_policy_skeleton.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2m_business_tables_rls_policy_skeleton.sql)
- [supabase/queries/20260428_sprint2m_business_rls_readiness_verification.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/queries/20260428_sprint2m_business_rls_readiness_verification.sql)

## Current Baseline
Live staging read-only baseline on `2026-04-29` confirms:

### Already RLS-enabled
- `projects`
- `user_profiles`
- `project_evaluations`
- `investment_plans`
- `reports`
- `roi_models`
- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

### Still without RLS
- `project_costs`
- `project_cost_items`
- `project_cast_costs`
- `project_revenues`
- `project_festival_records`
- `plan_projects`
- `plan_kpi_snapshots`
- `festival_events`
- `roi_model_weights`

### Current grant risk summary
High-risk broad direct DML still visible on non-RLS business tables:
- `project_costs`
- `project_cost_items`
- `project_cast_costs`
- `project_revenues`
- `project_festival_records`
- `plan_projects`
- `plan_kpi_snapshots`
- `festival_events`
- `roi_model_weights`

For those tables, live staging currently shows:
- `anon`: `select/insert/update/delete = true`
- `authenticated`: `select/insert/update/delete = true`
- `service_role`: full access

That is the most important current security gap for business data.

### Tenant key state
- `projects.org_id`: present and backfilled
- `user_profiles.org_id`: present and backfilled
- `investment_plans.org_id`: present on staging after Sprint 2K, but table has `0` rows
- `reports.org_id`: present on staging after Sprint 2K, but table has `0` rows
- project child tables generally rely on `project_id`
- plan child tables rely on `plan_id`

### Write path risk summary
From Sprint 2G plus current grants:
- `projects` direct client write is intentionally disabled and should stay RPC-controlled
- `project_evaluations` still has direct authenticated write policy and becomes the next likely breaking or leakage point when tenant scoping tightens
- project financial child tables have no verified caller path in repo, but currently remain broadly writable if a caller exists
- CIRQUA raw and audit surfaces should remain service/RPC mediated

## RLS Enable Phases
### Phase A — lowest risk
Target tables:
- `project_evaluations`
- `project_costs`
- `project_cost_items`
- `project_cast_costs`
- `project_revenues`
- `project_festival_records`

Policy shape:
- project-scoped via `app.can_access_project(project_id)`
- no `anon`
- authenticated read allowed only within the caller org through project root
- write paths should stay commented or move to RPC/service until real callers are confirmed

Per-table recommendation:

| table | RLS policy type | helper needed | read policy | write policy | RPC/service? | breaking risk |
| --- | --- | --- | --- | --- | --- | --- |
| `project_evaluations` | project-scoped | `app.can_access_project()` | authenticated analyst/editor/admin same-org project read | high-risk; comment direct write until caller contract is narrowed | preferred RPC/service for create/update | high |
| `project_costs` | project-scoped | `app.can_access_project()` | same-org project read | do not enable direct write yet | likely service/API | high |
| `project_cost_items` | project-scoped | `app.can_access_project()` | same-org project read | do not enable direct write yet | likely service/API | high |
| `project_cast_costs` | project-scoped | `app.can_access_project()` | same-org project read | do not enable direct write yet | likely service/API | medium |
| `project_revenues` | project-scoped | `app.can_access_project()` | same-org project read | do not enable direct write yet | likely service/API | high |
| `project_festival_records` | project-scoped | `app.can_access_project()` | same-org project read | keep write commented until caller is known | maybe direct later, but service safer | medium |

### Phase B — tenant root tables
Target tables:
- `investment_plans`
- `reports`

Policy shape:
- replace role-only reads with explicit tenant-root checks
- keep `super_admin` management
- avoid generic client write reopening

Per-table recommendation:

| table | RLS policy type | helper needed | read policy | write policy | RPC/service? | breaking risk |
| --- | --- | --- | --- | --- | --- | --- |
| `investment_plans` | org-scoped root | `current_user_org_id()`, optional `app.can_access_plan()` | authenticated same-org read by allowed roles | keep direct write closed except super_admin until explicit editor flow exists | preferred RPC/service for future plan editing | medium |
| `reports` | mixed-root but org-root-first | `current_user_org_id()`, `app.can_access_project()`, `app.can_access_plan()` | same-org read using `org_id` primary and lineage fallback only if needed | keep direct write closed except super_admin/service | report generation should be service/API only | high |

### Phase C — plan child tables
Target tables:
- `plan_projects`
- `plan_kpi_snapshots`

Policy shape:
- plan-scoped through `app.can_access_plan(plan_id)`
- optional project consistency check for `plan_projects`

Per-table recommendation:

| table | RLS policy type | helper needed | read policy | write policy | RPC/service? | breaking risk |
| --- | --- | --- | --- | --- | --- | --- |
| `plan_projects` | plan + project scoped | `app.can_access_plan()`, `app.can_access_project()` | authenticated same-org plan read, require project match when `project_id` present | keep direct write closed until plan editor path is defined | likely RPC/service | high |
| `plan_kpi_snapshots` | plan-scoped | `app.can_access_plan()` | authenticated same-org plan read | keep direct write closed until KPI ingestion path is known | likely service/API | medium |

### Phase D — system / raw / audit tables
Target tables:
- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`
- plus admin/reference holdouts like `roi_model_weights`

Policy shape:
- system-only or admin-only
- no client direct raw writes
- preserve service-role management

Per-table recommendation:

| table | RLS policy type | helper needed | read policy | write policy | RPC/service? | breaking risk |
| --- | --- | --- | --- | --- | --- | --- |
| `project_source_links` | system-only project-bound | optional `app.can_access_project()` later | admin/analyst read only | RPC-only mutation | yes | low |
| `external_import_runs` | system-only | none at client layer | admin/analyst read only | RPC/service only | yes | low |
| `external_project_snapshots` | system-only raw | none at client layer | admin/analyst read only | service only | yes | low |
| `external_budget_snapshots` | system-only raw | none at client layer | admin/analyst read only | service only | yes | low |
| `external_import_field_mappings` | system review workspace | optional project helper later | admin/analyst read | analyst/admin mediated through RPC where possible | yes | medium |
| `external_import_audit_logs` | append-only audit | optional project helper later | admin/analyst read | no client update/delete | yes | low |
| `roi_model_weights` | admin/reference | none | authenticated curated read or admin read only | admin/service only | likely admin path | low |

## Policy Skeleton Summary
The skeleton draft does three things:
1. proposes helper functions:
   - `app.can_access_project(...)`
   - `app.can_access_plan(...)`
   - optional `app.can_access_report(...)`
2. sketches phase-by-phase read policies
3. intentionally comments out high-risk write policies

The skeleton intentionally does not:
- enable new RLS in-place
- restore `anon` access
- reopen generic authenticated writes
- change current grants

## High-Risk Tables
### `project_evaluations`
Highest near-term RLS risk because:
- it already has direct authenticated writes
- it is still role-scoped, not tenant-scoped
- it is the first table likely to break when project helper enforcement is introduced

### `project_costs`, `project_cost_items`, `project_cast_costs`, `project_revenues`
Highest current exposure risk because:
- live staging shows no RLS
- live staging shows broad `anon/authenticated` DML
- no verified caller path exists in repo

### `reports`
Highest mixed-lineage policy complexity because:
- it now has `org_id`, `project_id`, `plan_id`, and `evaluation_id`
- future read policy must avoid ambiguous tenant branching

### `plan_projects`
Highest consistency risk because:
- it ties plan root and project root together
- future policy should ensure plan org and project org do not diverge

## Sprint 2N Recommendation
Recommended next scope:
- `2N-A`: prepare `app.can_access_project()` helper and narrow project child read-only rollout plan
- `2N-B`: decide whether `project_evaluations` writes move to RPC first or get one constrained direct write policy
- `2N-C`: plan-table helper design for `app.can_access_plan()`

Recommended order:
1. lock down non-RLS project child grants on paper
2. design helper-backed read policies
3. reconcile write callers for `project_evaluations`
4. only then stage one narrow apply wave, likely `project_festival_records` or `project_evaluations` read-first

## CTO Go / No-Go
### Go
- for Sprint 2N helper and apply-wave design
- for treating Phase A project child tables as the first real business-table RLS rollout target
- for keeping system/raw CIRQUA tables RPC/service mediated

### No-Go
- for enabling all Phase A/B/C tables in one migration
- for reopening generic authenticated writes on `projects`, `reports`, or plan tables
- for production rollout before helper functions, write-path reconciliation, and grant tightening are staged and verified
