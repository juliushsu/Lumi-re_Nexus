# CIRQUA Service Permission Matrix v1

## Purpose

This document defines who may call each CIRQUA service-layer entrypoint in the MVP contract.

It exists so Readdy, backend implementers, and reviewers do not infer permissions from table RLS alone.

## Role summary

- `super_admin`: full service control
- `analyst`: import-run creation and mapping workflow participation, but never consent bypass
- `project_editor`: no CIRQUA service access in v1
- `report_viewer`: no CIRQUA service access in v1
- `shareholder_viewer`: no CIRQUA service access in v1

## Permission matrix

| Function | super_admin | analyst | project_editor | report_viewer | shareholder_viewer | Notes |
|---|---|---|---|---|---|---|
| `create_cirqua_project_link` | yes | no | no | no | no | creates source link and initializes consent as pending |
| `grant_cirqua_consent` | yes | no | no | no | no | consent lifecycle is admin-controlled |
| `create_cirqua_import_run` | yes | yes | no | no | no | must still fail when consent is not valid |
| `mark_cirqua_import_snapshot_received` | backend/service only | backend/service only | no | no | no | not a general frontend-callable function |
| `propose_cirqua_field_mappings` | backend/service only or admin | backend/service only | no | no | no | service-generated from imported snapshots |
| `approve_cirqua_field_mapping` | yes | yes | no | no | no | analyst may approve after review |
| `reject_cirqua_field_mapping` | yes | yes | no | no | no | analyst may reject after review |
| `generate_project_evaluation_baseline_from_cirqua` | yes | yes | no | no | no | only after approved mappings |

## Readdy-safe callable surface

From future admin/analyst UI, Readdy should only call:

- `create_cirqua_project_link`
- `grant_cirqua_consent`
- `create_cirqua_import_run`
- `approve_cirqua_field_mapping`
- `reject_cirqua_field_mapping`
- `generate_project_evaluation_baseline_from_cirqua`

Readdy should not call:

- `mark_cirqua_import_snapshot_received`
- `propose_cirqua_field_mappings`

These belong to backend workflow or privileged admin tooling.

## Consent enforcement rules

### `create_cirqua_import_run`

The function may be callable by `analyst`, but it must not succeed when:

- `consent_status != 'granted'`
- consent expired
- requested import scope exceeds granted scope

This is a business rule, not just a UI rule.

### `grant_cirqua_consent`

Only `super_admin` may grant or refresh consent.

Reason:

- consent creates legal and rights-related consequences
- analysts may review data but should not establish import authority

## Snapshot handling rules

`mark_cirqua_import_snapshot_received` and `propose_cirqua_field_mappings` are intentionally not open to generic client usage.

Reasons:

- raw payload processing must be tightly controlled
- state changes must be atomic
- audit log creation must be guaranteed
- future CIRQUA connector work will likely run in a service context

## Baseline generation rules

`generate_project_evaluation_baseline_from_cirqua` may be callable by:

- `super_admin`
- `analyst`

but only when:

- import run status is `approved`
- required mappings are fully approved
- consent remains valid at generation time

It must not:

- update `projects` directly
- update `reports` directly
- publish final investor-facing reports automatically

## Table access vs service access

Even though `analyst` can read certain CIRQUA raw tables through current RLS, write actions should still be driven by service entrypoints.

This keeps:

- state transitions consistent
- consent rules enforced
- audit logs complete

## Suggested future enforcement mechanisms

- RPC functions with internal role checks
- Edge Functions that validate JWT role and then call privileged SQL
- backend service wrapper for ingestion-only functions

## Security reminders

- `shareholder_viewer` must not reach any CIRQUA service function
- no token or connector secret belongs in repo
- generic frontend data hooks must not be reused for CIRQUA writes
