# CIRQUA Baseline Generation Contract v1

## Purpose

This document defines how an approved CIRQUA import run may generate a Film Investment Platform evaluation baseline without overwriting canonical project or report records.

## Scope

This contract applies to:

- `generate_project_evaluation_baseline_from_cirqua(import_run_id)`

It does not:

- publish final reports
- overwrite `projects`
- overwrite `reports`
- execute real CIRQUA API calls

## Preconditions

Baseline generation may proceed only when all conditions are true:

- import run exists
- `source_system = 'cirqua'`
- linked project exists
- consent is still valid
- `external_import_runs.import_status = 'approved'`
- no required mapping remains `pending_review`
- the run is not `rejected`
- the run is not `failed`

## Inputs

### Primary function input

```json
{
  "import_run_id": "uuid"
}
```

### Required source records

- `project_source_links`
- `external_import_runs`
- `external_project_snapshots`
- `external_budget_snapshots`
- `external_import_field_mappings`

## Baseline generation goals

- create a draft investment baseline from approved imported data
- preserve canonical ownership of `projects`
- improve cost precision using approved imported budget inputs
- support later ROI and Monte Carlo modeling

## Output target

The baseline generator should create one of these:

- a new `project_evaluations` draft row, or
- a future baseline version record that references a `project_evaluations` draft

For MVP, the preferred output is:

- a new `project_evaluations` draft row

## Suggested baseline mapping targets

Imported CIRQUA-approved fields may influence:

- `project_evaluations.project_id`
- `project_evaluations.project_name_zh`
- `project_evaluations.project_name_en`
- `project_evaluations.project_type`
- `project_evaluations.genre`
- `project_evaluations.region`
- `project_evaluations.language`
- `project_evaluations.estimated_budget`
- `project_evaluations.expected_roi`
- `project_evaluations.estimated_payback_period`
- `project_evaluations.completion_probability`
- `project_evaluations.schedule_risk_score`
- `project_evaluations.analyst_comment`
- `project_evaluations.evaluation_status`

Not every field must be set by CIRQUA import. Only approved mapped fields should be applied.

## Recommended generation behavior

### 1. Resolve linked project

From `external_import_runs.import_run_id`, resolve:

- `project_source_link_id`
- `project_id`

### 2. Collect approved mappings

Load all `external_import_field_mappings` for the run where:

- `mapping_status = 'approved'`

### 3. Build baseline value set

Compose a baseline payload from:

- approved project profile mappings
- approved budget summary mappings
- canonical fallback values from `projects` when a field is not approved from import

### 4. Create draft evaluation

Insert a new `project_evaluations` row with:

- `evaluation_status = 'draft'`
- `created_by = auth.uid()` or service actor
- project identity fields
- approved imported baseline values

### 5. Mark import run baseline outputs

Update `external_import_runs`:

- `baseline_generated_by`
- `baseline_generated_at`
- `baseline_project_evaluation_id`

### 6. Write audit row

Insert `external_import_audit_logs` event:

- `event_type = 'generate_baseline'`

## What baseline generation must not do

- must not update `projects`
- must not update `reports`
- must not auto-approve investment recommendation
- must not auto-publish any shareholder-facing output
- must not bypass mapping approval

## Suggested response

```json
{
  "import_run_id": "uuid",
  "project_id": "uuid",
  "project_evaluation_id": "uuid",
  "evaluation_status": "draft",
  "baseline_fields_applied": [
    "project_name_zh",
    "project_name_en",
    "estimated_budget"
  ],
  "baseline_source": "cirqua_import"
}
```

## Failure cases

The function should fail when:

- consent is no longer valid
- import run status is not `approved`
- approved mappings are empty for required baseline fields
- linked project cannot be resolved
- the run already has a baseline and policy forbids regeneration

Recommended error classes:

- `consent_invalid`
- `invalid_import_status`
- `no_approved_mappings`
- `project_not_found`
- `baseline_already_generated`

## Regeneration policy

For MVP, choose one of these and document it in implementation:

- strict single baseline generation per import run, or
- allow regeneration and update `baseline_generated_at` plus audit trail

Recommended MVP default:

- strict single baseline generation per import run

Reason:

- simpler audit trail
- less risk of accidental repeated draft creation

## Audit rules

On success:

- write `generate_baseline`

On blocked attempt:

- write `mark_failed` or a dedicated baseline failure event in future versions

Recommended audit payload keys:

- `import_run_id`
- `project_id`
- `project_evaluation_id`
- `applied_field_count`
- `baseline_source`
- `generation_mode`

## Permission model

Callable by:

- `super_admin`
- `analyst`

Blocked for:

- `project_editor`
- `report_viewer`
- `shareholder_viewer`

## Readdy usage rule

Readdy may eventually present a button such as:

- `Generate Evaluation Baseline`

But the UI must call only the controlled service function:

- `generate_project_evaluation_baseline_from_cirqua`

It must never:

- insert directly into `project_evaluations` using imported snapshot data
- mutate raw import tables as a substitute for the service flow
