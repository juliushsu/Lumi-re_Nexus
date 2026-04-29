# CIRQUA Stabilization Sprint 2I-B Business Tables Tenant Keys

## Scope
This round is a tenant key hardening draft only.

No migration was applied.
No production system was touched.
No broader business-table RLS was enabled.

Artifacts produced:
- [supabase/migrations/20260428_sprint2ib_business_tables_tenant_keys_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2ib_business_tables_tenant_keys_draft.sql)
- [supabase/queries/20260428_sprint2ib_tenant_key_verification.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/queries/20260428_sprint2ib_tenant_key_verification.sql)

## Tenant Key Audit
The design principle for this round is:
- do **not** add `org_id` everywhere by default
- keep pure project-child tables anchored by `project_id`
- add explicit `org_id` only where a table is itself a tenant root or mixed-root surface
- keep system-only / reference tables free of unnecessary tenant columns

| table | current tenant key columns | has org_id | has project_id | can derive org from project | needs new column | needs backfill | needs FK | recommended RLS mode |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `investment_plans` | none | no | no | no | yes: `org_id` | yes, manual-first | yes: `org_id -> organizations.id` | org-scoped |
| `plan_kpi_snapshots` | `plan_id` | no | no | no | no | depends on `investment_plans.org_id` | yes: `plan_id -> investment_plans.id` | plan-scoped |
| `plan_projects` | `plan_id`, `project_id`, `evaluation_id` | no | yes | yes when `project_id` present | no | maybe backfill `project_id` from `evaluation_id` | yes: `plan_id`, `project_id` | plan + project scoped |
| `project_evaluations` | `project_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | project-scoped |
| `project_costs` | `project_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | project-scoped |
| `project_cost_items` | `project_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | project-scoped |
| `project_cast_costs` | `project_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | project-scoped |
| `project_revenues` | `project_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | project-scoped |
| `project_festival_records` | `project_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | project-scoped |
| `project_source_links` | `project_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | system-only project-bound |
| `reports` | `project_id`, `plan_id`, `evaluation_id` | no | yes | sometimes | yes: `org_id` | yes, mixed derivation + manual fallback | yes: `org_id`, `project_id`, `plan_id`, `evaluation_id` | project/org-scoped mixed root |
| `external_import_runs` | `project_source_link_id` | no | no | indirectly via `project_source_links.project_id` | no | no | optional lineage FK only | system-only |
| `external_project_snapshots` | `project_source_link_id`, `import_run_id` | no | no | indirectly | no | no | optional lineage FK only | system-only |
| `external_budget_snapshots` | `project_source_link_id`, `import_run_id` | no | no | indirectly | no | no | optional lineage FK only | system-only |
| `external_import_field_mappings` | `project_id`, `import_run_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | system-only review workspace |
| `external_import_audit_logs` | `project_id`, `import_run_id` | no | yes | yes | no | verify null/orphan only | yes: `project_id -> projects.id` | system-only append-only |

## Backfill Dependency Map
### Tables that can derive tenant from `project_id -> projects.org_id`
- `project_evaluations`
- `project_costs`
- `project_cost_items`
- `project_cast_costs`
- `project_revenues`
- `project_festival_records`
- `project_source_links`
- `external_import_field_mappings`
- `external_import_audit_logs`
- `plan_projects` when `project_id` is populated
- `reports` when `project_id` is populated

These tables usually do **not** need a new `org_id` column for staged RLS.
The stronger immediate work is:
- make `project_id` complete
- remove orphan `project_id`
- add missing FKs and indexes

### Tables that can derive tenant only through secondary lineage
- `reports`
  - `evaluation_id -> project_evaluations.project_id -> projects.org_id`
  - `plan_id -> investment_plans.org_id` once plans are mapped
- `plan_projects`
  - `evaluation_id -> project_evaluations.project_id`
- `plan_kpi_snapshots`
  - `plan_id -> investment_plans.org_id` once plans gain `org_id`
- `external_import_runs`
  - `project_source_link_id -> project_source_links.project_id -> projects.org_id`
- `external_project_snapshots`
  - `project_source_link_id -> project_source_links.project_id -> projects.org_id`
- `external_budget_snapshots`
  - `project_source_link_id -> project_source_links.project_id -> projects.org_id`

### Tables that require manual mapping first
- `investment_plans`
  - current schema has no safe tenant lineage
  - do not guess org from `entity_name`, `plan_name`, or free text
- `reports`
  - only for rows still unresolved after project/evaluation/plan derivation

### Tables that should remain system-only and should not gain `org_id` now
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`
- `project_source_links`

Reason:
- these are controlled RPC/service surfaces already
- adding `org_id` now would denormalize lineage without solving the main safety issue

### Tables that behave as reference tables
- `festival_events`
- `roi_models`
- `roi_model_weights`

These are not tenant-key candidates in this phase.

## Migration Draft Summary
The draft migration takes a staged, non-destructive path.

### Proposed new columns
- `public.investment_plans.org_id`
- `public.reports.org_id`

### Proposed manual mapping tables
- `app.investment_plan_org_backfill_manual_map`
- optional `app.report_org_backfill_manual_map`

### Proposed backfill strategy
- `reports.project_id` backfill from `project_evaluations.project_id`
- `plan_projects.project_id` backfill from `project_evaluations.project_id`
- `reports.org_id` backfill in this order:
  1. direct from `reports.project_id -> projects.org_id`
  2. from `reports.evaluation_id -> project_evaluations.project_id -> projects.org_id`
  3. from `reports.plan_id -> investment_plans.org_id` after plan mapping
  4. manual mapping for unresolved rows
- `investment_plans.org_id` backfill is manual-first only

### Proposed FK draft
Add `NOT VALID` FKs first for:
- project child tables -> `projects.id`
- plan tables -> `investment_plans.id`
- mixed report keys -> `projects.id`, `investment_plans.id`, `project_evaluations.id`
- new root org keys -> `organizations.id`

### Proposed index draft
Add supporting indexes for:
- `investment_plans.org_id`
- `reports.org_id`
- `reports.project_id`
- `reports.plan_id`
- `reports.evaluation_id`
- all high-traffic `project_id` columns currently used as tenant roots for child tables

## High-Risk Tables
### `investment_plans`
Highest tenant-root risk.

Why:
- no `org_id`
- no safe automatic tenant inference path
- future plan-scoped RLS is unsafe until this root is modeled

### `reports`
Highest mixed-root risk.

Why:
- may rely on `project_id`, `plan_id`, or `evaluation_id`
- tenant lineage can be incomplete or ambiguous
- likely needs explicit `org_id` to avoid complicated runtime scope branching

### `plan_projects`
Consistency risk.

Why:
- joins plan scope and project scope
- future validation must ensure `plan_id` tenant matches `project_id` tenant

### `plan_kpi_snapshots`
Hidden dependency risk.

Why:
- looks simple, but cannot be safely scoped until `investment_plans` itself has a tenant root

## Sprint 2J Recommendation
Recommended next scope:
- `2J-A`: prepare `investment_plans` and `reports` tenant-root schema changes on staging
- `2J-B`: add missing `project_id` / FK cleanup for project-child tables
- `2J-C`: design `app.can_access_project()` and `app.can_access_plan()` helpers before wider business-table RLS

Recommended order:
1. make tenant-root keys explicit
2. clean FK / orphan issues
3. only then stage broader business-table RLS

## CTO Go / No-Go
### Go
- for reviewing the draft migration and verification query
- for staged schema prep on `investment_plans` and `reports`
- for FK and tenant lineage cleanup before broader RLS

### No-Go
- for adding `NOT NULL` in this phase
- for applying the draft migration directly to production
- for enabling more business-table RLS before tenant roots are made explicit
