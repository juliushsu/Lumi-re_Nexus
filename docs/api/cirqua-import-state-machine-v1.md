# CIRQUA Import State Machine v1

## Purpose

This document defines the MVP import lifecycle for CIRQUA-linked data inside the Film Investment Platform.

The state machine applies to `external_import_runs.import_status`.

## Design goals

- block import when consent is missing
- keep imported snapshots separate from canonical `projects`
- require human-approved mappings before baseline generation
- make failures and rejections explicit
- keep the lifecycle understandable for backend operators and future Readdy UI work

## States

### `draft`

Meaning:

- import run exists but has not passed consent or readiness checks
- often created when an admin starts preparing a CIRQUA import for a linked project

Allowed entry conditions:

- `project_source_links` row exists
- source system is `cirqua`

### `consent_required`

Meaning:

- import cannot proceed because consent is not currently valid

Typical reasons:

- `consent_status = 'pending'`
- `consent_status = 'revoked'`
- `consent_status = 'expired'`
- requested import scope exceeds granted consent scope

### `ready_to_import`

Meaning:

- the project link exists
- consent is currently valid
- the run is eligible for snapshot ingestion

Required checks:

- `source_system = 'cirqua'`
- `consent_status = 'granted'`
- consent is not expired

### `imported`

Meaning:

- one or more CIRQUA snapshots were stored successfully
- raw import is present, but no approved canonical impact exists yet

Important:

- this state does not modify `projects`
- this state does not generate a baseline by itself

### `mapping_required`

Meaning:

- snapshots exist
- at least one imported field requires a human review or mapping decision

Typical examples:

- imported project title differs from canonical project title
- imported budget total differs from manually entered total budget
- imported field has no direct controlled mapping

### `approved`

Meaning:

- required mappings were approved
- the run is allowed to feed baseline generation

Important:

- approved does not mean baseline has already been generated unless that action also occurs
- baseline generation should still be logged separately

### `rejected`

Meaning:

- a human rejected the mapping package or the import result for business reasons

Effects:

- imported snapshots remain as historical evidence
- no baseline generation may occur from this run

### `failed`

Meaning:

- import or processing failed technically or structurally

Examples:

- malformed snapshot payload
- internal normalization failure
- unexpected schema mismatch

## Recommended transitions

### Primary transitions

`draft -> consent_required`

- when consent is missing or invalid

`draft -> ready_to_import`

- when valid consent already exists

`consent_required -> ready_to_import`

- when consent is granted and scope is sufficient

`ready_to_import -> imported`

- when project profile and/or budget snapshots are stored

`imported -> mapping_required`

- when snapshots are present and human decisions are needed before baseline use

`mapping_required -> approved`

- when human-approved mappings are complete

`mapping_required -> rejected`

- when admin or analyst rejects the mapping package

`approved -> imported`

- only when a later re-import supersedes the approved snapshot package and restarts review

`any active state -> failed`

- when technical handling breaks

## Recommended invalid transitions

These should be blocked by service logic:

- `consent_required -> imported`
- `draft -> approved`
- `imported -> approved` without mapping decisions
- `rejected -> generate_baseline`
- `failed -> approved` without a new successful import cycle

## Baseline generation rule

Baseline generation is not its own `import_status` in this MVP.

Instead:

- the import run reaches `approved`
- baseline generation is recorded separately through:
  - `baseline_generated_by`
  - `baseline_generated_at`
  - `baseline_project_evaluation_id`
- audit log event: `generate_baseline`

This keeps the state model compact while still showing whether an approved run actually produced a `project_evaluation` baseline.

## Human approval rule

Human approval is required before imported data may influence evaluation baselines.

Minimum review targets:

- imported project profile changes
- imported budget summary values
- mapping decisions in `external_import_field_mappings`

## Suggested operational logic

### Consent check logic

If any of the following are true, set `import_status = 'consent_required'`:

- no project link exists
- `consent_status != 'granted'`
- consent expired
- requested import scope exceeds granted scope

### Mapping check logic

Set `import_status = 'mapping_required'` when:

- snapshots imported successfully
- one or more `external_import_field_mappings.mapping_status = 'pending_review'`

Set `import_status = 'approved'` when:

- all required mappings are approved
- no blocking validation errors remain

## Audit event alignment

The following audit events should align with transitions:

- `create_import_run`
- `grant_consent`
- `import_snapshot`
- `approve_mapping`
- `reject_mapping`
- `generate_baseline`
- optional support events:
  - `revoke_consent`
  - `expire_consent`
  - `mark_failed`

## Role interaction

### `super_admin`

- can create runs
- can grant or revoke consent
- can import snapshots
- can approve or reject mappings
- can generate baseline

### `analyst`

- can read runs, snapshots, mappings, and audit logs
- can approve or reject mappings if workflow allows
- can participate in baseline generation decisions

### `shareholder_viewer`

- has no access to this state machine directly
- may only see approved downstream summaries, not run states or raw snapshots

## Future extension

Likely v2 states:

- `baseline_generated`
- `superseded`
- `partially_approved`

These are intentionally deferred to keep the MVP compact.
