# CIRQUA RPC Implementation Notes v1

## Purpose

This document explains how the stage-1 CIRQUA RPC implementation maps the v1 contracts into a staging-first Supabase migration.

## Implemented in migration

Migration:

- `supabase/migrations/20260428124500_implement_cirqua_import_rpc.sql`

Implemented RPCs:

- `create_cirqua_project_link`
- `grant_cirqua_consent`
- `create_cirqua_import_run`
- `approve_cirqua_field_mapping`
- `reject_cirqua_field_mapping`
- `generate_project_evaluation_baseline_from_cirqua`

Not implemented for direct frontend use:

- `mark_cirqua_import_snapshot_received`
- `propose_cirqua_field_mappings`

These remain backend/service-only contract items in this phase.

## Key implementation choices

### 1. Raw-table direct writes are tightened

The migration revokes direct `insert/update/delete` from `authenticated` on:

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

This is intentional. Readdy should move toward RPC-only writes for CIRQUA flows.

### 2. Role checks happen inside every implemented RPC

Each implemented RPC checks `user_profiles.role` through existing helper functions:

- `app.has_role`
- `app.has_any_role`
- `app.current_profile_role`

This means:

- `shareholder_viewer` can technically reach the function endpoint but will fail authorization
- `analyst` can create import runs and review mappings
- `analyst` cannot grant consent
- `super_admin` has full control

### 3. Consent is enforced at service level

`create_cirqua_import_run` does not let analysts bypass consent.

Behavior:

- if consent is valid, import run becomes `ready_to_import`
- if consent is invalid, import run is created as `consent_required`

This preserves a clear audit trail without allowing real import execution.

### 4. Audit logging is mandatory

Every implemented RPC writes to `external_import_audit_logs` through:

- `app.write_cirqua_audit_log(...)`

The audit payload always includes:

- `source_system`
- `actor_role`

and each RPC adds context such as:

- previous/new status
- import run id
- mapping id
- note

### 5. Baseline generation is draft-only

`generate_project_evaluation_baseline_from_cirqua`:

- requires `import_status = 'approved'`
- requires no pending mappings
- creates a new `project_evaluations` draft
- does not update `projects`
- does not update `reports`

This matches the platform requirement that CIRQUA import may influence baselines but must not directly overwrite canonical project or formal reporting outputs.

### 6. Mapping lifecycle is strict

`approve_cirqua_field_mapping`:

- marks one mapping approved
- if no pending/rejected mappings remain, import run becomes `approved`

`reject_cirqua_field_mapping`:

- marks one mapping rejected
- sets the run to `rejected`

This is stricter than a more nuanced partial-approval model, but simpler and safer for MVP.

## Schema adjustments made by implementation

The implementation migration also updates audit event constraints to allow:

- `create_project_link`
- `propose_mapping`

This aligns the database constraint with the documented service contract, even though `propose_mapping` is still deferred.

## Security posture after implementation

### Readdy should call

- `create_cirqua_project_link`
- `grant_cirqua_consent`
- `create_cirqua_import_run`
- `approve_cirqua_field_mapping`
- `reject_cirqua_field_mapping`
- `generate_project_evaluation_baseline_from_cirqua`

### Readdy should not call

- `mark_cirqua_import_snapshot_received`
- `propose_cirqua_field_mappings`

### Readdy should not directly write

- any of the six CIRQUA raw tables

## Known limitations

- no real CIRQUA API integration
- no backend/service-only snapshot receive function implementation yet
- no mapping proposal generator implementation yet
- no dedicated baseline version table yet
- no project-scoped analyst visibility model yet

## Recommended next step

Next round should implement backend/service-only support for:

- `mark_cirqua_import_snapshot_received`
- `propose_cirqua_field_mappings`

and optionally tighten the architecture further by:

- exposing only RPC-driven write surfaces in documentation
- reducing even admin direct table-writing expectations
- adding project-scoped analyst assignment for CIRQUA access
