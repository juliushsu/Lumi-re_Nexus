# CIRQUA Import Contract v1

## Purpose

This document defines the backend contract for future CIRQUA import workflows. It is intentionally frontend-agnostic for this phase.

## Scope

The import contract covers:

- project linking
- consent verification
- import run initiation
- snapshot storage
- mapping approval
- baseline generation
- evaluation baseline creation

It does not include:

- CIRQUA token management details
- frontend UI implementation
- direct shareholder data access

## Contract principles

- CIRQUA is an external source system.
- Film Investment Platform keeps canonical project ownership.
- Imports are snapshot-based, not overwrite-based.
- Consent is required before any import run.
- Baseline generation is approval-driven.

## Recommended backend resources

### Tables

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_cost_actual_snapshots`
- `external_schedule_snapshots`
- `external_revenue_assumption_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

### RPC or service actions

- `link_external_project`
- `request_cirqua_import`
- `approve_import_mapping`
- `reject_import_mapping`
- `generate_project_evaluation_baseline_from_import`

These may later be implemented as Edge Functions, backend services, or controlled RPC layers depending on the final platform design.

## Proposed request and response shapes

### 1. Link CIRQUA project

Purpose:
Create a canonical link between a Film Investment Platform project and a CIRQUA project.

Input:

```json
{
  "project_id": "uuid",
  "source_system": "cirqua",
  "external_project_id": "string",
  "link_note": "optional string"
}
```

Expected response:

```json
{
  "project_source_link_id": "uuid",
  "project_id": "uuid",
  "source_system": "cirqua",
  "external_project_id": "string",
  "link_status": "linked",
  "consent_status": "pending"
}
```

Access:

- `super_admin`

### 2. Record or update consent

Purpose:
Store explicit permission to import defined CIRQUA data scopes.

Input:

```json
{
  "project_source_link_id": "uuid",
  "consent_status": "granted",
  "consent_scope_json": {
    "project_profile": true,
    "budget_summary": true,
    "cost_actuals": true,
    "shooting_schedule": true,
    "revenue_assumptions": false,
    "crew_vendor_cost_categories": true
  },
  "consent_note": "Approved by rights holder"
}
```

Expected response:

```json
{
  "project_source_link_id": "uuid",
  "consent_status": "granted",
  "consent_granted_by": "uuid",
  "consent_granted_at": "timestamp"
}
```

Access:

- `super_admin`

### 3. Request CIRQUA import

Purpose:
Start an import run after consent is verified.

Input:

```json
{
  "project_source_link_id": "uuid",
  "requested_layers": [
    "project_profile",
    "budget_summary",
    "cost_actuals",
    "shooting_schedule"
  ]
}
```

Expected response:

```json
{
  "import_run_id": "uuid",
  "project_source_link_id": "uuid",
  "source_system": "cirqua",
  "import_status": "queued",
  "started_at": null
}
```

Validation rules:

- fail if `source_system != 'cirqua'`
- fail if consent is not `granted`
- fail if requested layer is outside consent scope

Access:

- `super_admin`
- optionally `analyst` if product approves analyst-triggered imports

### 4. Import run result

Purpose:
Represent the result after the backend importer fetches and normalizes CIRQUA data.

Expected result shape:

```json
{
  "import_run_id": "uuid",
  "import_status": "completed",
  "snapshot_version": "string",
  "captured_at": "timestamp",
  "snapshot_counts": {
    "project_profile": 1,
    "budget_summary": 1,
    "cost_actuals": 148,
    "shooting_schedule": 24,
    "revenue_assumptions": 0,
    "crew_vendor_cost_categories": 53
  },
  "diagnostic_summary": {
    "warnings": 2,
    "errors": 0
  }
}
```

Access:

- `super_admin`
- `analyst`

### 5. Approve field mapping

Purpose:
Allow a human to approve how imported CIRQUA values influence canonical or baseline fields.

Input:

```json
{
  "import_run_id": "uuid",
  "mappings": [
    {
      "snapshot_type": "budget_summary",
      "source_field": "budget_total",
      "target_table": "projects",
      "target_field": "total_budget",
      "mapping_status": "approved_for_baseline",
      "approval_note": "Use CIRQUA budget as cost baseline source"
    }
  ]
}
```

Expected response:

```json
{
  "import_run_id": "uuid",
  "approved_mapping_count": 1,
  "rejected_mapping_count": 0,
  "status": "approved"
}
```

Access:

- `super_admin`
- `analyst`

### 6. Generate project evaluation baseline

Purpose:
Create or refresh a baseline `project_evaluations` draft using approved imported cost and schedule inputs.

Input:

```json
{
  "project_id": "uuid",
  "import_run_id": "uuid",
  "roi_model_id": "uuid",
  "generation_mode": "create_or_refresh_baseline"
}
```

Expected response:

```json
{
  "project_evaluation_id": "uuid",
  "baseline_source": "cirqua_import",
  "import_run_id": "uuid",
  "status": "draft",
  "baseline_fields_applied": [
    "estimated_budget",
    "completion_probability",
    "schedule_risk_score"
  ]
}
```

Access:

- `super_admin`
- `analyst`

## Readdy integration rules

### Direct frontend access that should not exist

Readdy should not directly query:

- `external_import_runs`
- `external_*_snapshots`
- `external_import_audit_logs`

unless the future UI is explicitly role-gated for `super_admin` or `analyst`.

### Shareholder restriction

`shareholder_viewer` must never query CIRQUA raw tables or import diagnostics.

If imported data contributes to dashboard output, the frontend must use approved summary surfaces only.

### Suggested future UI endpoints

For Readdy, the likely future UI-facing surfaces are:

- link summary endpoint
- consent status endpoint
- import diagnostics endpoint for admin/analyst
- baseline comparison endpoint
- approved imported summary endpoint

## Audit expectations

Each contract action should emit audit log events for:

- link created
- consent changed
- import requested
- import completed
- import failed
- mapping approved or rejected
- baseline generated

## Failure cases

Reject import or baseline generation when:

- no consent exists
- consent scope does not cover requested layers
- external project link is missing or inactive
- snapshot validation errors exceed allowed threshold
- project is already linked to a conflicting active CIRQUA project

## Suggested migration names

- `20260428xxxx_add_project_source_links.sql`
- `20260428xxxx_add_cirqua_import_snapshot_tables.sql`
- `20260428xxxx_add_external_import_mapping_and_audit_tables.sql`

## Security note

This contract intentionally excludes CIRQUA connector secrets, tokens, or service credentials. Those belong in secure runtime configuration only.
