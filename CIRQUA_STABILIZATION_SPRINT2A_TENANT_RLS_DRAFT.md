# CIRQUA Stabilization Sprint 2A Tenant & RLS Draft

## Scope
This round only prepares a tenant hardening and RLS migration skeleton. No migration from this Sprint 2A draft has been applied by this task.

## New Files
- `supabase/migrations/20260428_sprint2a_tenant_backfill_prepare.sql`
- `supabase/migrations/20260428_sprint2a_rls_policy_skeleton.sql`
- `supabase/migrations/20260428_sprint2a_grants_lockdown.sql`
- `supabase/migrations/20260428_sprint2a_verification_queries.sql`

## Source Gap
The requested Sprint 1 source artifacts were not present in GitHub `main` at draft time:
- `CIRQUA_STABILIZATION_SPRINT1_P0_REPORT.md`
- `supabase_sprint1_snapshot.json`
- `sprint1_readonly_audit.sql`

Because of that, this draft is based on:
- current repository migrations and docs
- a read-only staging schema probe on `2026-04-28`

This matters because the current staging reality does not fully match the prompt assumptions:
- `public.projects.org_id` does not exist yet
- `public.profiles` does not exist
- `public.get_org_usage` does not exist

So Sprint 2A has been reframed as a safe hardening skeleton, not an execution-ready tenant rollout.

## Current Project Status
Read-only staging probe result:

| project_id | project_name | current_org_id | status |
| --- | --- | --- | --- |
| `e39feb8d-9bfe-44a8-b83e-7adb33ad0ab8` | `API 驗證專案` | unavailable | `projects.org_id` column missing |

## projects.org_id Repair Strategy
Current conclusion:
- this is not yet a “null backfill” problem in staging
- it is first a “missing tenant key” problem

Recommended sequence:
1. Add `user_profiles.org_id` and `projects.org_id` in a later reviewed migration.
2. Do not auto-populate `projects.org_id`.
3. Prepare a manual review table with:
   - `project_id`
   - `current_org_id`
   - `proposed_org_id`
   - `confidence`
   - `reason`
   - `evidence_json`
4. Only backfill rows marked `approved_for_backfill = true`.
5. Enable tenant RLS on `projects` only after the manual map is approved.

Can `org_id` be inferred from other current public tables?
- Not from the current staging schema.
- There is no public table that currently contains both `project_id` and `org_id`.
- Therefore no automatic tenant inference is justified.

Manual mapping draft for the current known project:

| project_id | current_org_id | proposed_org_id | confidence | reason |
| --- | --- | --- | --- | --- |
| `e39feb8d-9bfe-44a8-b83e-7adb33ad0ab8` | `null` | `null` | `manual_review_required` | `projects.org_id column missing in staging schema; no org-bearing project-linked table exists in current public schema` |

## Tenant Hardening Recommendations
The closest current “core 14” public tables are listed below. This set should still be reconciled against the missing Sprint 1 snapshot when it becomes available.

| table | has org_id | has project_id | suggested mode | recommendation |
| --- | --- | --- | --- | --- |
| `festival_events` | no | no | `public-read-only` | keep as reference taxonomy; revoke writes from `anon` |
| `investment_plans` | no | no | `org-scoped` | add org ownership directly or via a canonical tenant parent |
| `plan_kpi_snapshots` | no | no | `org-scoped` | scope through parent `plan_id` |
| `plan_projects` | no | yes | `org-scoped` | scope through `plan_id` plus consistency check with project ownership |
| `project_cast_costs` | no | yes | `project-scoped` | inherit access from parent project |
| `project_cost_items` | no | yes | `project-scoped` | inherit access from parent project |
| `project_costs` | no | yes | `project-scoped` | inherit access from parent project |
| `project_evaluations` | no | yes | `project-scoped` | inherit access from parent project |
| `project_festival_records` | no | yes | `project-scoped` | inherit access from parent project |
| `project_revenues` | no | yes | `project-scoped` | inherit access from parent project |
| `projects` | no | no | `org-scoped` | add `projects.org_id` before tenant RLS rollout |
| `reports` | no | yes | `project-scoped` | inherit access from parent project |
| `roi_models` | no | no | `admin-only` | treat as global config until a curated read path is approved |
| `user_profiles` | no | no | `org-scoped` | add `user_profiles.org_id` with self-read exception |

## RLS Policy Skeleton Summary
What Sprint 2A delivers:
- a policy matrix for the 14 core tables
- helper function skeletons for:
  - `app.current_org_id()`
  - `app.can_access_project(uuid)`
- commented high-risk policy templates for:
  - `projects`
  - `user_profiles`
  - project child tables
  - plan child tables

What Sprint 2A intentionally does not do:
- it does not enable new high-risk tenant policies
- it does not backfill tenant ids
- it does not guess production ownership

Current staging RLS observations:
- RLS is already enabled on:
  - `projects`
  - `project_evaluations`
  - `investment_plans`
  - `reports`
  - `roi_models`
  - `user_profiles`
  - CIRQUA import tables
- RLS is still not enabled on several project-financial tables:
  - `plan_kpi_snapshots`
  - `plan_projects`
  - `project_cast_costs`
  - `project_cost_items`
  - `project_costs`
  - `project_festival_records`
  - `project_revenues`

## Grants Lockdown Summary
Observed direct `anon` privileges still open in staging:
- `festival_events`
- `plan_kpi_snapshots`
- `plan_projects`
- `project_cast_costs`
- `project_cost_items`
- `project_costs`
- `project_festival_records`
- `project_revenues`

Observed historical risks that are not present in current staging:
- `public.profiles`
- `public.get_org_usage`

Lockdown plan:
1. Inventory and preserve current frontend dependencies.
2. Introduce replacement RPC / summary paths first.
3. Add tenant keys and parent-scoped RLS.
4. Revoke `anon` direct table access.
5. Keep `service_role` operational and backend-only.

Suggested replacement API / RPC direction:
- `get_public_festival_events()`
- `get_plan_overview(plan_id)`
- `get_project_cost_summary(project_id)`
- `get_project_revenue_summary(project_id)`
- `get_project_festival_summary(project_id)`

## Why This Cannot Be Auto-Executed Yet
- `projects.org_id` does not exist in current staging.
- `user_profiles.org_id` does not exist in current staging.
- no current public table supports reliable automatic project-to-org inference.
- the Sprint 1 audit artifacts referenced by the request are missing from GitHub `main`.
- several high-risk project financial tables still have broad grants and no tenant policy skeleton has been approved for rollout.

## CTO Go / No-Go
Current recommendation: `No-Go` for tenant RLS rollout.

Reason:
- the schema is not yet tenant-addressable at the project root
- there is no approved backfill source of truth
- rolling out org-based RLS before adding canonical org linkage would create brittle or misleading isolation

`Go` only for the following limited next step:
- review and approve the Sprint 2A draft files
- recover the missing Sprint 1 artifacts
- prepare Sprint 2B with actual `org_id` column introduction and manual mapping workflow

## Notes
- This task did not apply any migration to staging or production.
- The read-only staging probe was used only to shape the draft and confirm current schema reality.
