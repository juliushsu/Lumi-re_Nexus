# CIRQUA Stabilization Sprint 2J Investment Plans / Reports Tenant Root

## Scope
This round defines the tenant-root draft for:
- `investment_plans`
- `reports`
- `plan_projects`
- `plan_kpi_snapshots`

No migration was applied.
No production system was touched.
No business-table RLS was enabled in this round.

Artifacts produced:
- [supabase/migrations/20260428_sprint2j_investment_reports_tenant_root_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2j_investment_reports_tenant_root_draft.sql)
- [supabase/queries/20260428_sprint2j_investment_reports_tenant_root_verification.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/queries/20260428_sprint2j_investment_reports_tenant_root_verification.sql)

## Preflight Results
### Live staging read-only confirmation
Using Supabase REST/OpenAPI read-only probe on `2026-04-29`:
- `investment_plans` row count: `0`
- `reports` row count: `0`
- `plan_projects` row count: `0`
- `plan_kpi_snapshots` row count: `0`

Live column confirmation:
- `investment_plans` does **not** have `org_id`
- `reports` does **not** have `org_id`
- `plan_projects` has:
  - `plan_id`
  - `project_id`
  - `evaluation_id`
- `plan_kpi_snapshots` has:
  - `plan_id`

Live derivation implication:
- `reports` can potentially derive tenant from:
  - `project_id`
  - `evaluation_id`
  - `plan_id`
- `plan_projects` can potentially derive tenant from:
  - `project_id`
  - and secondarily `evaluation_id`
- `plan_kpi_snapshots` can only derive tenant through:
  - `plan_id -> investment_plans`

### FK confirmation caveat
Direct live FK metadata could not be queried from the Postgres host in this environment because DNS resolution to `db.gyoiqrywhcufrsqgyjre.supabase.co` still fails here.

So FK confirmation for this round uses:
- live row-count and live column confirmation from Supabase REST/OpenAPI
- committed repo migration history and current schema baseline for explicit FK presence review

### Repo-side FK baseline
Current committed migrations do **not** show explicit FK additions yet for the four target tables in scope.

That means the current state should be treated as:
- root and child lineage columns exist
- formal FK hardening is still mostly a draft concern

### Orphan / null state
Because all four target tables currently have `0` rows in staging:
- no current orphan rows were observed in live data
- no current null `plan_id` / `project_id` / `evaluation_id` row problems were observed in live data

This is helpful for staged rollout because:
- tenant-root schema changes can be introduced before significant live data complexity accumulates

## Tenant Root Design
### `investment_plans.org_id`
Recommendation: **add nullable `org_id`**

Reason:
- `investment_plans` is a tenant root
- there is no reliable current lineage path to infer org from another table
- future `plan_projects` and `plan_kpi_snapshots` scoping both depend on a trustworthy plan root

Backfill strategy:
- manual-first mapping only
- never infer from `plan_name`, `entity_name`, or other weak text signals

### `reports.org_id`
Recommendation: **add nullable `org_id`**

Reason:
- `reports` is a mixed-root table
- future tenant RLS would otherwise have to branch on:
  - `project_id`
  - `evaluation_id`
  - `plan_id`
- adding `org_id` gives a simplified future tenant root while preserving lineage columns

Backfill strategy:
1. `project_id -> projects.org_id`
2. `evaluation_id -> project_evaluations.project_id -> projects.org_id`
3. `plan_id -> investment_plans.org_id`
4. manual fallback for unresolved rows

### `plan_projects`
Recommendation: **do not add `org_id` now**

Reason:
- this table is a junction
- tenant should derive from:
  - `plan_id -> investment_plans.org_id`
  - plus consistency checks against `project_id -> projects.org_id`

Required hardening:
- add missing FKs
- backfill `project_id` from `evaluation_id` where safe
- later validate `plan org = project org`

### `plan_kpi_snapshots`
Recommendation: **do not add `org_id` now**

Reason:
- tenant should derive from `plan_id -> investment_plans.org_id`
- adding `org_id` here would duplicate the true root

Required hardening:
- add `plan_id -> investment_plans.id` FK
- rely on plan root after plans gain `org_id`

### Index / FK recommendations
Recommended future indexes:
- `investment_plans(org_id)`
- `reports(org_id)`
- `reports(project_id)`
- `reports(plan_id)`
- `reports(evaluation_id)`
- `plan_projects(plan_id)`
- `plan_projects(project_id)`
- `plan_projects(evaluation_id)`
- `plan_kpi_snapshots(plan_id)`

Recommended future FKs as `NOT VALID` first:
- `investment_plans.org_id -> organizations.id`
- `reports.org_id -> organizations.id`
- `reports.project_id -> projects.id`
- `reports.plan_id -> investment_plans.id`
- `reports.evaluation_id -> project_evaluations.id`
- `plan_projects.plan_id -> investment_plans.id`
- `plan_projects.project_id -> projects.id`
- `plan_projects.evaluation_id -> project_evaluations.id`
- `plan_kpi_snapshots.plan_id -> investment_plans.id`

### Why NOT NULL is deferred
Do **not** add `NOT NULL` yet because:
- `investment_plans` requires manual-first tenant mapping logic
- `reports` requires multi-step derivation and possible manual fallback
- staging should validate schema and lineage first
- production mapping rules are not yet finalized

`NOT NULL` should only be considered after:
- root columns exist
- backfill completes
- verification query returns zero unresolved tenant roots
- FK validation succeeds
- staging dry run is stable

## Migration Draft Summary
The draft migration includes:
1. nullable `investment_plans.org_id`
2. nullable `reports.org_id`
3. manual mapping support for plans
4. optional manual mapping support for unresolved reports
5. report lineage backfill drafts
6. `plan_projects.project_id` backfill draft from evaluation lineage
7. `NOT VALID` FK drafts
8. index drafts
9. explicit warnings that this is staging-first and not production-ready

## Risk
### P0
- `investment_plans` currently has no tenant root, so future plan-scoped RLS is unsafe until `org_id` exists.
- `reports` may combine multiple lineage paths, so future tenant scoping can become ambiguous without explicit `org_id`.

### P1
- `plan_projects` can silently become inconsistent if `plan_id` and `project_id` end up pointing at different org roots once real data arrives.
- `plan_kpi_snapshots` looks simple but is completely dependent on plan-root correctness.

### P2
- Live staging currently has zero rows in all four target tables, so structural rollout is easier now, but real-world lineage edge cases are not yet represented by data.

## Can We Enter Sprint 2K?
Recommendation: yes.

Sprint 2K should be:
- staging dry run only
- apply the tenant-root schema prep in a controlled order
- stop before RLS enable

Suggested 2K order:
1. add nullable `investment_plans.org_id`
2. add nullable `reports.org_id`
3. add manual mapping support tables
4. add draft indexes / low-risk FKs as appropriate
5. run verification query

## CTO Go / No-Go
### Go
- for Sprint 2K staging dry run of tenant-root schema prep
- for introducing nullable `org_id` on `investment_plans` and `reports`
- for keeping `plan_projects` and `plan_kpi_snapshots` derived from plan/project lineage rather than duplicating `org_id`

### No-Go
- for production rollout
- for `NOT NULL` in this phase
- for business-table RLS enable before tenant roots are in place
