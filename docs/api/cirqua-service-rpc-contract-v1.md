# CIRQUA Service RPC Contract v1

## Purpose

This document defines the controlled service-layer contract for CIRQUA Integration MVP.

This phase does not implement real CIRQUA connectivity and does not store any CIRQUA token or secret. It only defines the backend entrypoints that future RPCs, Edge Functions, or backend services must enforce.

## Why service entrypoints are required

Readdy must not directly write these raw CIRQUA tables:

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

Reasons:

- consent must be checked consistently
- `import_status` transitions must be controlled
- audit log entries must be guaranteed
- imported snapshots must not overwrite `projects`
- `shareholder_viewer` must have zero raw import surface

## Recommended implementation mode

Use service entrypoints rather than direct table writes:

- Postgres RPC for internal workflow actions
- Edge Functions for actions that will later talk to CIRQUA
- server-side orchestration for status transitions and audit writing

## Canonical function list

### 1. `create_cirqua_project_link(project_id, external_project_id, consent_scope_json)`

Purpose:

- create a CIRQUA link for an internal project
- initialize consent state as `pending`
- prevent direct table insertion from frontend

Input:

```json
{
  "project_id": "uuid",
  "external_project_id": "string",
  "consent_scope_json": {
    "project_profile": true,
    "budget_summary": true
  }
}
```

Required behavior:

- assert caller role is `super_admin`
- create `project_source_links` row
- force `source_system = 'cirqua'`
- force `consent_status = 'pending'`
- write audit event `create_project_link`

Response:

```json
{
  "project_source_link_id": "uuid",
  "project_id": "uuid",
  "source_system": "cirqua",
  "consent_status": "pending",
  "link_status": "active"
}
```

### 2. `grant_cirqua_consent(project_source_link_id, consent_scope_json, expires_at)`

Purpose:

- grant or refresh consent for CIRQUA import scope

Required behavior:

- assert caller role is `super_admin`
- set `consent_status = 'granted'`
- set `consent_granted_by`
- set `consent_granted_at`
- set `consent_expires_at`
- clear revoked markers if previously revoked
- write audit event `grant_consent`

Response:

```json
{
  "project_source_link_id": "uuid",
  "consent_status": "granted",
  "consent_granted_at": "timestamp",
  "consent_expires_at": "timestamp"
}
```

### 3. `create_cirqua_import_run(project_source_link_id)`

Purpose:

- create a controlled import run record

Required behavior:

- allow `super_admin` and `analyst`
- verify linked source exists and is `cirqua`
- verify consent is currently `granted`
- if consent missing or expired, do not create an active import run; either:
  - return an error, or
  - create a run with `import_status = 'consent_required'`
- otherwise create a run with `import_status = 'ready_to_import'`
- write audit event `create_import_run`

Response:

```json
{
  "import_run_id": "uuid",
  "project_source_link_id": "uuid",
  "import_status": "ready_to_import"
}
```

### 4. `mark_cirqua_import_snapshot_received(import_run_id, project_snapshot_json, budget_snapshot_json)`

Purpose:

- record imported snapshot payloads after the service layer receives CIRQUA data

Important:

- this is service-only
- Readdy must not call this directly from client code

Required behavior:

- allow backend service execution only, or `super_admin` through a privileged admin path
- verify import run exists
- verify import run status is `ready_to_import`
- insert into:
  - `external_project_snapshots`
  - `external_budget_snapshots`
- set `external_import_runs.import_status = 'imported'`
- set `started_at` if null
- set `completed_at`
- write audit event `import_snapshot`
- never update `projects` directly

Response:

```json
{
  "import_run_id": "uuid",
  "import_status": "imported",
  "project_snapshot_created": true,
  "budget_snapshot_created": true
}
```

### 5. `propose_cirqua_field_mappings(import_run_id)`

Purpose:

- generate mapping candidates from imported snapshots into `external_import_field_mappings`

Required behavior:

- allow backend service execution and optionally `super_admin`
- verify import run status is `imported`
- inspect project and budget snapshots
- create rows in `external_import_field_mappings` with `mapping_status = 'pending_review'`
- set `external_import_runs.import_status = 'mapping_required'`
- write audit event `propose_mapping`

Response:

```json
{
  "import_run_id": "uuid",
  "import_status": "mapping_required",
  "proposed_mapping_count": 4
}
```

### 6. `approve_cirqua_field_mapping(mapping_id, approval_note)`

Purpose:

- approve a single mapping item

Required behavior:

- allow `super_admin` and `analyst`
- update mapping row:
  - `mapping_status = 'approved'`
  - `approved_by`
  - `approved_at`
  - `approval_note`
- write audit event `approve_mapping`
- if all required mappings for the run are approved, set:
  - `external_import_runs.import_status = 'approved'`

Response:

```json
{
  "mapping_id": "uuid",
  "mapping_status": "approved",
  "import_run_status": "approved"
}
```

### 7. `reject_cirqua_field_mapping(mapping_id, approval_note)`

Purpose:

- reject a single mapping item

Required behavior:

- allow `super_admin` and `analyst`
- update mapping row:
  - `mapping_status = 'rejected'`
  - `rejected_by`
  - `rejected_at`
  - `approval_note`
- set import run status to `rejected` if the rejection is blocking
- write audit event `reject_mapping`

Response:

```json
{
  "mapping_id": "uuid",
  "mapping_status": "rejected",
  "import_run_status": "rejected"
}
```

### 8. `generate_project_evaluation_baseline_from_cirqua(import_run_id)`

Purpose:

- generate a `project_evaluations` draft baseline from approved imported snapshots

Required behavior:

- allow `super_admin` and `analyst`
- verify import run status is `approved`
- verify no required mappings remain `pending_review`
- create a new `project_evaluations` draft or baseline-target record
- set:
  - `baseline_generated_by`
  - `baseline_generated_at`
  - `baseline_project_evaluation_id`
- write audit event `generate_baseline`
- do not update:
  - `projects`
  - `reports`
  directly

Response:

```json
{
  "import_run_id": "uuid",
  "project_evaluation_id": "uuid",
  "evaluation_status": "draft",
  "baseline_source": "cirqua_import"
}
```

## Recommended visibility model

### Client-callable from Readdy

Only these should be exposed to authenticated admin/analyst flows:

- `create_cirqua_project_link`
- `grant_cirqua_consent`
- `create_cirqua_import_run`
- `approve_cirqua_field_mapping`
- `reject_cirqua_field_mapping`
- `generate_project_evaluation_baseline_from_cirqua`

### Service-only or privileged backend

These should not be called directly from general frontend code:

- `mark_cirqua_import_snapshot_received`
- `propose_cirqua_field_mappings`

Reason:

- they operate on raw imported payloads
- they must guarantee audit trail and state transitions
- they are closer to ingestion pipeline behavior than human UI actions

## Raw table write prohibition

Readdy should never call direct writes against:

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

Service functions are the write surface.

## Status transition rules

### Allowed

- `draft -> consent_required`
- `draft -> ready_to_import`
- `consent_required -> ready_to_import`
- `ready_to_import -> imported`
- `imported -> mapping_required`
- `mapping_required -> approved`
- `mapping_required -> rejected`
- `ready_to_import -> failed`
- `imported -> failed`
- `mapping_required -> failed`

### Blocked

- `consent_required -> imported`
- `draft -> imported`
- `imported -> approved` without mapping review
- `rejected -> generate_baseline`
- `approved -> import_snapshot`

## Audit log rules

Every service action must write at least one `external_import_audit_logs` row.

Recommended event types:

- `create_project_link`
- `create_import_run`
- `grant_consent`
- `import_snapshot`
- `propose_mapping`
- `approve_mapping`
- `reject_mapping`
- `generate_baseline`
- `mark_failed`

Recommended audit payload keys:

- `source_system`
- `project_id`
- `project_source_link_id`
- `import_run_id`
- `mapping_id` when relevant
- `previous_status`
- `new_status`
- `actor_role`
- `note`

## Security rules

- `shareholder_viewer` may not call any CIRQUA service entrypoint
- `analyst` may create import runs and approve/reject mappings
- `analyst` may not bypass consent
- `super_admin` has full control
- raw snapshot processing functions should prefer backend-only execution

## Implementation note

This document is a contract draft. A future migration is still required if these RPCs will be implemented as database functions, plus likely Edge Functions if snapshot ingestion will be service-orchestrated.
