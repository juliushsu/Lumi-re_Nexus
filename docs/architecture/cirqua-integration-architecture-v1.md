# CIRQUA Integration Architecture v1

## Purpose

This document defines the backend-first integration architecture for using CIRQUA as an external source system for the Film Investment Platform.

The goal is to reduce duplicate manual entry, improve cost precision, and preserve auditability without changing the current frontend UI in this phase.

## Core principles

- CIRQUA is an external source system, not the canonical project record for this platform.
- Film Investment Platform keeps the canonical `projects` row and its own evaluation workflow.
- No CIRQUA data may be imported without explicit production crew or rights-holder consent.
- Imported data must never silently overwrite human-edited project or evaluation fields.
- Imported data should arrive as snapshots plus mapping decisions, then become analyst-approved baselines.
- `shareholder_viewer` may only see approved summaries, never CIRQUA raw detail.

## System roles

### CIRQUA

- external source of operational production data
- may provide more granular cost, schedule, vendor, and budget details
- remains authoritative for its own raw operational records

### Film Investment Platform

- canonical source for investment-facing project identity and evaluation workflow
- canonical owner of `projects`, `project_evaluations`, `investment_plans`, `reports`
- owner of import consent state, baseline approval state, and ROI / Monte Carlo inputs

## Recommended data flow

### Stage 1. Project link creation

An internal project is linked to a CIRQUA project through a dedicated linkage table:

- `project_source_links` or `external_project_links`

This records:

- `project_id`
- `source_system = 'cirqua'`
- `external_project_id`
- `link_status`
- consent fields

### Stage 2. Consent gate

Before any import job runs, the platform checks:

- `consent_status = 'granted'`
- `consent_granted_by`
- `consent_granted_at`
- optional consent scope and expiration

If consent is absent, revoked, expired, or limited, the import must not proceed.

### Stage 3. Snapshot import

Raw CIRQUA data is ingested into snapshot tables, not directly into canonical project tables.

Recommended layers:

- project profile
- budget summary
- cost actuals
- shooting schedule
- revenue assumptions
- crew/vendor cost categories

Each import run should produce:

- source metadata
- imported snapshot payloads
- normalization status
- validation issues
- audit trail

### Stage 4. Human-approved mapping

Analysts or super admins review snapshot-to-canonical mapping:

- which CIRQUA fields map to which platform fields
- whether a value should update a baseline
- whether imported detail is accepted, rejected, or partially accepted

No direct overwrite happens before review.

### Stage 5. Baseline materialization

Approved imported data creates or updates:

- project cost baseline
- schedule baseline
- budget summary baseline
- revenue assumption baseline

These baselines feed:

- `project_evaluations`
- ROI model calculations
- Monte Carlo scenario generation

### Stage 6. Evaluation baseline generation

Once the import is approved, the platform creates a `project_evaluation` baseline draft or refreshes a controlled baseline version.

This should:

- preserve prior analyst commentary
- record which import snapshot/version drove the baseline
- separate baseline recalculation from recommendation approval

## Recommended new tables

### `project_source_links`

Purpose:
Link a canonical project to one or more external systems.

Suggested columns:

- `id`
- `project_id`
- `source_system`
- `external_project_id`
- `link_status`
- `consent_status`
- `consent_scope_json`
- `consent_granted_by`
- `consent_granted_at`
- `consent_expires_at`
- `created_at`
- `updated_at`

### `external_import_runs`

Purpose:
Track each CIRQUA import attempt.

Suggested columns:

- `id`
- `project_source_link_id`
- `source_system`
- `import_status`
- `started_at`
- `completed_at`
- `requested_by`
- `diagnostics_json`
- `snapshot_version`
- `created_at`

### `external_project_snapshots`

Purpose:
Store imported project profile snapshots.

Suggested columns:

- `id`
- `import_run_id`
- `project_source_link_id`
- `snapshot_type = 'project_profile'`
- `external_payload_json`
- `normalized_payload_json`
- `captured_at`
- `created_at`

### `external_budget_snapshots`

Purpose:
Store imported budget summary baselines.

Suggested columns:

- `id`
- `import_run_id`
- `project_source_link_id`
- `currency`
- `budget_total`
- `above_the_line_total`
- `below_the_line_total`
- `contingency_total`
- `normalized_payload_json`
- `captured_at`

### `external_cost_actual_snapshots`

Purpose:
Store imported actual costs without flattening detail away.

Suggested columns:

- `id`
- `import_run_id`
- `project_source_link_id`
- `cost_category`
- `vendor_or_crew_name`
- `cost_amount`
- `currency`
- `incurred_on`
- `source_line_item_id`
- `normalized_payload_json`

### `external_schedule_snapshots`

Purpose:
Store shooting schedule and progress snapshots.

Suggested columns:

- `id`
- `import_run_id`
- `project_source_link_id`
- `schedule_phase`
- `planned_start_date`
- `planned_end_date`
- `actual_start_date`
- `actual_end_date`
- `completion_percent`
- `normalized_payload_json`

### `external_revenue_assumption_snapshots`

Purpose:
Store imported revenue-side assumptions if present and authorized.

Suggested columns:

- `id`
- `import_run_id`
- `project_source_link_id`
- `assumption_type`
- `assumption_name`
- `projected_amount`
- `currency`
- `confidence_score`
- `normalized_payload_json`

### `external_import_field_mappings`

Purpose:
Track human-approved mapping decisions.

Suggested columns:

- `id`
- `import_run_id`
- `project_id`
- `source_system`
- `snapshot_type`
- `source_field`
- `target_table`
- `target_field`
- `mapping_status`
- `approved_by`
- `approved_at`
- `approval_note`

### `external_import_audit_logs`

Purpose:
Immutable trail of import, approval, rejection, and baseline generation events.

Suggested columns:

- `id`
- `project_id`
- `project_source_link_id`
- `import_run_id`
- `event_type`
- `actor_user_id`
- `event_payload_json`
- `created_at`

## Canonical data ownership

### Canonical in Film Investment Platform

- project identity
- investment evaluation status
- ROI baseline selection
- board and report workflow
- approved summary views for shareholders

### Sourced from CIRQUA after approval

- detailed budget structure
- actual cost baseline
- shooting schedule progress
- crew/vendor categorization
- selected revenue assumptions when explicitly authorized

## Evaluation and Monte Carlo impact

Imported CIRQUA cost data should feed a separate approved baseline layer used by:

- `project_evaluations.estimated_budget`
- `project_evaluations.estimated_marketing_budget` where applicable
- project-level cost variance analytics
- Monte Carlo downside/upside cost scenarios

Recommended behavior:

- ROI models keep their formula logic
- imported CIRQUA baselines improve source precision for cost inputs
- Monte Carlo scenarios use approved imported variance bands rather than raw imported rows directly

## Suggested migration names

- `20260428xxxx_add_project_source_links_and_import_runs.sql`
- `20260428xxxx_add_external_snapshot_tables.sql`
- `20260428xxxx_add_external_import_field_mappings_and_audit_logs.sql`
- `20260428xxxx_add_cirqua_rls_and_summary_policies.sql`

## Impact on current RLS design

This architecture extends the current RLS model but does not require replacing it.

Expected additions:

- new restricted tables for CIRQUA linkage, snapshots, diagnostics, and audit logs
- `super_admin` full access
- `analyst` read access plus approval actions on mapping/import decisions
- `shareholder_viewer` no raw CIRQUA table access
- summary outputs only after approved mapping and baseline generation

## Readdy future UI work

- project source linking panel
- consent capture/status panel
- import run history and diagnostics view
- mapping approval workspace
- baseline comparison screen: manual vs imported
- shareholder-safe summary widgets that show approved aggregates only

## Risks

- importing operational detail without clear consent could create legal and commercial exposure
- CIRQUA field semantics may differ from investment-facing semantics
- over-trusting imported cost lines could distort ROI if mapping approval is weak
- duplicate project linking may create multiple conflicting baselines
- schedule and cost snapshots may arrive at different timestamps and cause mixed-version analyses
- revenue assumptions imported from operations may not be investor-approved assumptions

## Non-goals for this phase

- no frontend implementation
- no CIRQUA token storage in repo
- no automatic overwrite of human-edited data
- no direct shareholder access to imported raw detail
