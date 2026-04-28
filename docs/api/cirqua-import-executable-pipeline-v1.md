# CIRQUA Import Executable Pipeline v1

## Purpose

This document describes the first executable MVP pipeline for CIRQUA import inside the Film Investment Platform.

The pipeline is executable in staging without using any real CIRQUA API token. Snapshot payloads are supplied manually to the service-only function layer.

## Scope

This MVP covers:

- link creation
- consent grant
- import run creation
- service-only snapshot receipt
- service-only mapping proposal
- human mapping approval or rejection
- baseline generation into `project_evaluations` draft

This MVP does not cover:

- real CIRQUA API authentication
- real external connector runtime
- shareholder-facing CIRQUA UI
- automatic report publication

## Implemented functions

### User-callable RPCs

- `create_cirqua_project_link`
- `grant_cirqua_consent`
- `create_cirqua_import_run`
- `approve_cirqua_field_mapping`
- `reject_cirqua_field_mapping`
- `generate_project_evaluation_baseline_from_cirqua`

### Service-only functions

- `mark_cirqua_import_snapshot_received`
- `propose_cirqua_field_mappings`

## Why the pipeline is now executable

Before this round, the CIRQUA import path stopped at contracts and did not have working ingestion-side functions.

After this round:

- snapshot receipt is implemented
- mapping proposal is implemented
- smoke test can exercise the full pipeline order

This means staging can validate the operational flow even though CIRQUA is still mocked by manually supplied JSON payloads.

## End-to-end pipeline

### Step 1. Create project link

Function:

- `create_cirqua_project_link`

Outcome:

- `project_source_links` row created
- `consent_status = 'pending'`
- audit event `create_project_link`

### Step 2. Grant consent

Function:

- `grant_cirqua_consent`

Outcome:

- `consent_status = 'granted'`
- consent metadata stored
- audit event `grant_consent`

### Step 3. Create import run

Function:

- `create_cirqua_import_run`

Outcome:

- if consent valid: `ready_to_import`
- if consent invalid: `consent_required`
- audit event `create_import_run`

### Step 4. Receive snapshots

Function:

- `mark_cirqua_import_snapshot_received`

Execution mode:

- service-only
- `service_role` or privileged admin execution path

Outcome:

- writes `external_project_snapshots`
- writes `external_budget_snapshots`
- sets import run to `imported`
- updates `last_imported_at`
- audit event `import_snapshot`

### Step 5. Propose mappings

Function:

- `propose_cirqua_field_mappings`

Execution mode:

- service-only
- `service_role` or privileged admin execution path

Outcome:

- generates `pending_review` rows in `external_import_field_mappings`
- sets import run to `mapping_required`
- audit event `propose_mapping`

### Step 6. Approve or reject mappings

Functions:

- `approve_cirqua_field_mapping`
- `reject_cirqua_field_mapping`

Outcome:

- approvals advance the mapping lifecycle
- all-required-approved can move the run to `approved`
- rejections move the run to `rejected`
- audit events:
  - `approve_mapping`
  - `reject_mapping`

### Step 7. Generate baseline

Function:

- `generate_project_evaluation_baseline_from_cirqua`

Outcome:

- creates a new `project_evaluations` draft
- marks import run baseline metadata
- marks approved mappings as `applied_to_baseline`
- audit event `generate_baseline`

## Status transitions

- `pending consent link` -> not yet importable
- `create_cirqua_import_run` before valid consent -> `consent_required`
- after consent -> `ready_to_import`
- after snapshot receipt -> `imported`
- after mapping proposal -> `mapping_required`
- after approvals complete -> `approved`
- after rejection -> `rejected`
- after baseline generation -> run remains `approved` but has baseline metadata populated

## Snapshot payload expectations

### Project snapshot example

```json
{
  "project_name_zh": "示範片名",
  "project_name_en": "Demo Title",
  "project_type": "feature_film",
  "genre": "drama",
  "region": "TW",
  "language": "Mandarin"
}
```

### Budget snapshot example

```json
{
  "currency": "TWD",
  "budget_total": 18000000,
  "above_the_line_total": 3500000,
  "below_the_line_total": 12000000,
  "contingency_total": 2500000
}
```

## Safety guarantees

- snapshots never overwrite `projects`
- mapping proposal only creates `pending_review`
- baseline generation only creates draft evaluation records
- `shareholder_viewer` gets no access to raw pipeline functions
- no CIRQUA token is stored in repo

## Readdy implication

Readdy may eventually surface the user-callable RPC layer, but must still avoid:

- direct writes to CIRQUA raw tables
- direct calls to service-only functions

These ingestion-side functions belong to backend automation or privileged admin execution only.
