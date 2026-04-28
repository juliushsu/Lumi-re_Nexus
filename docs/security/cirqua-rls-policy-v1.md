# CIRQUA RLS Policy v1

## Purpose

This document defines the Row Level Security posture for the CIRQUA Integration MVP tables.

Covered tables:

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

## Security goals

- keep CIRQUA as an external source, not a public data surface
- block `anon` from all access
- prevent `shareholder_viewer` from reading raw CIRQUA snapshots
- allow `analyst` to read snapshots and mappings
- allow `super_admin` full access to the CIRQUA MVP layer
- preserve auditability without storing secrets in repo

## Role posture

### `super_admin`

- full CRUD on:
  - `project_source_links`
  - `external_import_runs`
  - `external_project_snapshots`
  - `external_budget_snapshots`
  - `external_import_field_mappings`
- read and insert on:
  - `external_import_audit_logs`

Note:

Audit logs are intentionally treated as append-oriented. The MVP migration grants insert/select only for this table even to admins, which is stricter than general CRUD and better aligned with audit expectations.

### `analyst`

- read on:
  - `project_source_links`
  - `external_import_runs`
  - `external_project_snapshots`
  - `external_budget_snapshots`
  - `external_import_field_mappings`
  - `external_import_audit_logs`
- insert/update on:
  - `external_import_field_mappings`
- insert on:
  - `external_import_audit_logs`

### `shareholder_viewer`

- no access to any CIRQUA MVP raw tables

### `project_editor`

- no access to CIRQUA MVP raw tables in v1

### `report_viewer`

- no access to CIRQUA MVP raw tables in v1

## Table-by-table summary

### `project_source_links`

- `anon`: no access
- `authenticated`: gated by role
- `super_admin`: full CRUD
- `analyst`: select only
- all other app roles: no access

### `external_import_runs`

- `anon`: no access
- `super_admin`: full CRUD
- `analyst`: select only
- all other app roles: no access

### `external_project_snapshots`

- `anon`: no access
- `super_admin`: full CRUD
- `analyst`: select only
- `shareholder_viewer`: no access

### `external_budget_snapshots`

- `anon`: no access
- `super_admin`: full CRUD
- `analyst`: select only
- `shareholder_viewer`: no access

### `external_import_field_mappings`

- `anon`: no access
- `super_admin`: full CRUD
- `analyst`: select, insert, update
- delete reserved to `super_admin`

### `external_import_audit_logs`

- `anon`: no access
- `super_admin`: select, insert
- `analyst`: select, insert
- no update or delete policy in MVP

## Why shareholder access is blocked

The imported CIRQUA layer can contain:

- raw imported project payloads
- imported budget internals
- approval and rejection metadata
- diagnostics and operational history

This is not shareholder-safe data. Shareholder-facing visibility should come only from already-approved investment summaries exposed elsewhere in the platform.

## Relation to existing RLS design

This policy extends the current RLS design rather than replacing it.

No changes are made here to:

- `projects`
- `project_evaluations`
- `investment_plans`
- `reports`
- existing shareholder summary RPCs

The CIRQUA MVP layer is additive and isolated.

## Policy implementation summary

The migration uses the existing helper functions:

- `app.has_role(text)`
- `app.has_any_role(text[])`

These are already part of the platform security foundation and are reused here to avoid duplicating role logic.

## Consent and state machine interaction

RLS does not enforce business consent by itself. Consent is represented in:

- `project_source_links.consent_status`
- `project_source_links.consent_scope_json`

Service logic or controlled admin workflows must still prevent import actions when:

- consent is pending
- consent is revoked
- consent is expired
- consent scope is insufficient

RLS is a visibility and mutation boundary, not a full workflow engine.

## Audit event expectations

Expected event types stored in `external_import_audit_logs`:

- `create_import_run`
- `grant_consent`
- `revoke_consent`
- `expire_consent`
- `import_snapshot`
- `approve_mapping`
- `reject_mapping`
- `generate_baseline`
- `mark_failed`

## Operational cautions

- do not surface CIRQUA raw tables in generic frontend data hooks
- do not allow fallback to broad `select *` helpers for shareholder pages
- do not store CIRQUA credentials in SQL files, docs, or client code
- keep baseline generation separate from raw snapshot ingestion

## Suggested v2 enhancements

- add project-scoped analyst assignment if the team wants narrower analyst visibility
- add dedicated admin or import operator role if super_admin becomes too broad
- add diagnostic RPCs instead of direct table reads if frontend needs stricter isolation
