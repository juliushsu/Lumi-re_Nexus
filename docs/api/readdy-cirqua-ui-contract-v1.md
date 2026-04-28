# Readdy CIRQUA UI Contract v1

## Purpose

This document defines the future UI-facing data contract for the CIRQUA Integration MVP without changing the current frontend UI in this phase.

The goal is to tell Readdy exactly which pages, tables, fields, and role restrictions will matter once CIRQUA integration screens are added.

## Hard rules

- no direct CIRQUA API calls from frontend code
- no CIRQUA secrets or tokens in frontend code
- no raw snapshot access for `shareholder_viewer`
- imported snapshots must not directly overwrite `projects`
- baseline generation must happen only after human-approved mapping

## Target roles

- `super_admin`
- `analyst`
- `shareholder_viewer`

In this MVP contract:

- `super_admin` gets full CIRQUA import UI
- `analyst` gets read/review/approval-oriented CIRQUA import UI
- `shareholder_viewer` gets no CIRQUA import UI

## Recommended future pages

### 1. Project Source Link Panel

Purpose:

- show whether a Film Investment Platform project is linked to CIRQUA
- manage consent state
- show latest import readiness

Primary data source:

- `project_source_links`

Suggested fields:

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
- `last_imported_at`
- `created_at`
- `updated_at`

Role access:

- `super_admin`: full panel
- `analyst`: read-only panel
- `shareholder_viewer`: no access

### 2. Consent Management Drawer

Purpose:

- grant, revoke, or inspect CIRQUA data consent

Primary data source:

- `project_source_links`

Suggested fields:

- `consent_status`
- `consent_scope_json`
- `consent_note`
- `consent_granted_by`
- `consent_granted_at`
- `consent_expires_at`
- `consent_revoked_by`
- `consent_revoked_at`

Write behavior:

- `super_admin` only

### 3. Import Runs List

Purpose:

- show import lifecycle history for a linked project

Primary data source:

- `external_import_runs`

Suggested fields:

- `id`
- `project_source_link_id`
- `source_system`
- `import_status`
- `snapshot_version`
- `requested_by`
- `started_at`
- `completed_at`
- `failure_reason`
- `approved_by`
- `approved_at`
- `baseline_generated_by`
- `baseline_generated_at`
- `baseline_project_evaluation_id`
- `created_at`
- `updated_at`

Role access:

- `super_admin`: full read
- `analyst`: read
- `shareholder_viewer`: no access

### 4. Project Snapshot Review Tab

Purpose:

- inspect imported CIRQUA project profile payload after normalization

Primary data source:

- `external_project_snapshots`

Suggested fields:

- `id`
- `import_run_id`
- `project_source_link_id`
- `snapshot_type`
- `normalized_payload_json`
- `captured_at`
- `created_at`

Do not expose by default in UI:

- `external_payload_json`

Reason:

- keep raw payload access limited even inside admin workflows unless specifically needed

Role access:

- `super_admin`: full read
- `analyst`: read
- `shareholder_viewer`: no access

### 5. Budget Snapshot Review Tab

Purpose:

- inspect imported budget summary for approval

Primary data source:

- `external_budget_snapshots`

Suggested fields:

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

Role access:

- `super_admin`: full read
- `analyst`: read
- `shareholder_viewer`: no access

### 6. Mapping Approval Workspace

Purpose:

- compare imported values against current canonical values
- approve or reject field-level mapping

Primary data source:

- `external_import_field_mappings`

Suggested fields:

- `id`
- `import_run_id`
- `project_id`
- `snapshot_type`
- `source_field`
- `target_table`
- `target_field`
- `proposed_value_json`
- `current_value_json`
- `mapping_status`
- `approval_note`
- `approved_by`
- `approved_at`
- `rejected_by`
- `rejected_at`
- `created_at`
- `updated_at`

Actions:

- approve mapping
- reject mapping
- filter pending items
- filter approved / rejected history

Role access:

- `super_admin`: full access
- `analyst`: read and review workflow access
- `shareholder_viewer`: no access

### 7. Audit Timeline

Purpose:

- show accountability for import lifecycle and approvals

Primary data source:

- `external_import_audit_logs`

Suggested fields:

- `id`
- `project_id`
- `project_source_link_id`
- `import_run_id`
- `event_type`
- `actor_user_id`
- `event_payload_json`
- `created_at`

Role access:

- `super_admin`: full read
- `analyst`: read
- `shareholder_viewer`: no access

## Allowed direct query surfaces

### `super_admin`

Allowed direct queries:

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

### `analyst`

Allowed direct queries:

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`
- `external_import_audit_logs`

Write expectation:

- mapping approval workflow only where backend/RLS allows it

### `shareholder_viewer`

Allowed direct queries:

- none of the CIRQUA MVP tables

## Suggested route structure for Readdy

- `/projects/:projectId/integrations/cirqua`
- `/projects/:projectId/integrations/cirqua/consent`
- `/projects/:projectId/integrations/cirqua/import-runs`
- `/projects/:projectId/integrations/cirqua/import-runs/:runId/snapshots`
- `/projects/:projectId/integrations/cirqua/import-runs/:runId/mappings`
- `/projects/:projectId/integrations/cirqua/import-runs/:runId/audit`

These are only route suggestions, not a required implementation.

## Suggested UI states

### Project Source Link Panel

- not linked
- linked / consent pending
- linked / consent granted
- linked / consent revoked
- linked / consent expired

### Import Run List

- draft
- consent required
- ready to import
- imported
- mapping required
- approved
- rejected
- failed

### Mapping Workspace

- no mapping items
- pending review items
- partially reviewed
- all approved
- rejected items present

## Suggested derived badges

- `Consent Pending`
- `Consent Granted`
- `Consent Revoked`
- `Consent Expired`
- `Mapping Required`
- `Baseline Ready`
- `Baseline Generated`
- `Import Failed`

## Query examples for future Readdy implementation

### Load CIRQUA project link

```ts
const { data, error } = await supabase
  .from('project_source_links')
  .select(`
    id,
    project_id,
    source_system,
    external_project_id,
    link_status,
    consent_status,
    consent_scope_json,
    consent_granted_by,
    consent_granted_at,
    consent_expires_at,
    last_imported_at,
    created_at,
    updated_at
  `)
  .eq('project_id', projectId)
  .eq('source_system', 'cirqua')
  .order('created_at', { ascending: false })
```

### Load import runs

```ts
const { data, error } = await supabase
  .from('external_import_runs')
  .select(`
    id,
    project_source_link_id,
    source_system,
    import_status,
    snapshot_version,
    requested_by,
    started_at,
    completed_at,
    failure_reason,
    approved_by,
    approved_at,
    baseline_generated_by,
    baseline_generated_at,
    baseline_project_evaluation_id,
    created_at,
    updated_at
  `)
  .eq('project_source_link_id', projectSourceLinkId)
  .order('created_at', { ascending: false })
```

### Load pending mappings

```ts
const { data, error } = await supabase
  .from('external_import_field_mappings')
  .select(`
    id,
    import_run_id,
    project_id,
    snapshot_type,
    source_field,
    target_table,
    target_field,
    proposed_value_json,
    current_value_json,
    mapping_status,
    approval_note,
    approved_by,
    approved_at,
    rejected_by,
    rejected_at,
    created_at,
    updated_at
  `)
  .eq('import_run_id', importRunId)
  .eq('mapping_status', 'pending_review')
  .order('created_at', { ascending: true })
```

## Shareholder restriction reminder

`shareholder_viewer` must not have:

- CIRQUA link panel
- consent drawer
- import runs page
- snapshot review tab
- mapping workspace
- audit timeline

If future product wants shareholder visibility, it must come from already-approved project summaries, not from CIRQUA MVP tables.
