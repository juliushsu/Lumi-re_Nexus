# CIRQUA Data Consent and Access Control v1

## Purpose

This document defines the consent, access control, and audit posture for importing CIRQUA data into the Film Investment Platform.

## Non-negotiable rules

- No CIRQUA import without explicit production crew or rights-holder consent.
- No CIRQUA token, API secret, or sensitive connector detail may be committed to the repository.
- `shareholder_viewer` may not see CIRQUA raw detail.
- Only `super_admin` and `analyst` may inspect import diagnostics.
- All import, consent, approval, and rejection actions must be audit logged.

## Consent model

Consent should be stored at the project-source link level so the same canonical project can have different consent states for different external systems.

Recommended consent fields:

- `consent_status`
- `consent_scope_json`
- `consent_granted_by`
- `consent_granted_at`
- `consent_expires_at`
- `consent_revoked_by`
- `consent_revoked_at`
- `consent_note`

Recommended statuses:

- `pending`
- `granted`
- `denied`
- `revoked`
- `expired`

## Consent scope

Consent should be able to distinguish which layers are authorized:

- project profile
- budget summary
- cost actuals
- shooting schedule
- revenue assumptions
- crew/vendor cost categories

This avoids assuming that approval for cost actuals also permits revenue or rights-sensitive data import.

## Access model

### `super_admin`

May:

- create and manage CIRQUA project links
- grant or revoke consent when supported by business process
- trigger imports
- review raw snapshots
- review diagnostics
- approve or reject mappings
- view audit logs

### `analyst`

May:

- view linked CIRQUA project metadata
- view imported snapshots when consent is granted
- view diagnostics
- approve or reject mappings when workflow allows
- use approved baselines in evaluation work

May not:

- bypass consent
- expose raw imported detail to shareholder-facing outputs

### `project_editor`

May:

- see high-level linked-source status if product needs it

May not:

- access raw CIRQUA snapshots
- access import diagnostics
- manage consent

### `report_viewer`

May:

- see only final approved report outputs

May not:

- access raw CIRQUA data
- access diagnostics
- manage consent

### `shareholder_viewer`

May:

- see only approved summary outputs after import approval and baseline materialization

May not:

- access raw CIRQUA snapshots
- access vendor or crew detail
- access diagnostics
- access consent administration

## RLS implications

Current RLS design can be extended with new protected tables.

Recommended policy posture:

- `project_source_links`
  - `super_admin`: full CRUD
  - `analyst`: read, limited approval workflow if desired
  - others: no raw access

- `external_import_runs`
  - `super_admin`: full CRUD
  - `analyst`: read
  - others: no access

- `external_*_snapshots`
  - `super_admin`: full read/write
  - `analyst`: read after consent is granted
  - others: no access

- `external_import_field_mappings`
  - `super_admin`: full CRUD
  - `analyst`: read/update approval fields
  - others: no access

- `external_import_audit_logs`
  - `super_admin`: full read
  - `analyst`: read for assigned or permitted projects if desired
  - others: no access

## Shareholder-safe summary rule

If imported CIRQUA data contributes to dashboard summaries, it must first be transformed into approved aggregate fields inside the Film Investment Platform.

Allowed examples for shareholder-facing output:

- approved project total budget
- approved aggregate actual spend
- approved completion percentage summary
- approved variance to budget

Forbidden examples for shareholder-facing output:

- raw vendor names
- individual crew compensation lines
- raw schedule notes
- import diagnostics
- rejected or pending mappings

## Audit logging

Audit log events should include:

- consent granted
- consent revoked
- import requested
- import completed
- import failed
- mapping approved
- mapping rejected
- baseline generated
- baseline superseded

Recommended audit payload attributes:

- project id
- source link id
- import run id
- actor user id
- event type
- changed fields or decision summary
- timestamp

## Operational controls

- CIRQUA credentials should live only in secure environment secrets, not source control.
- Import jobs should use least-privilege backend credentials.
- Diagnostic payloads should be scrubbed for secrets and PII where possible.
- Revenue assumptions should be imported only when consent scope explicitly allows them.

## Readdy future UI implications

Readdy will eventually need:

- consent status indicators
- import eligibility state
- import diagnostics screen for admin/analyst only
- baseline approval UI
- shareholder-safe summary screens that consume only approved aggregates

## Risks

- legal exposure if consent language is ambiguous
- privacy/commercial sensitivity around crew and vendor details
- accidental leakage if raw snapshot tables are queried directly in frontend code
- confusion between operational actuals and investor-approved reporting numbers
- stale consent if expiration and revocation are not enforced

## Recommended migration names

- `20260428xxxx_add_project_source_link_consent_fields.sql`
- `20260428xxxx_add_cirqua_snapshot_rls.sql`
- `20260428xxxx_add_external_import_audit_logs.sql`
