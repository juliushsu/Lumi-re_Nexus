# ROI Model Schema v1

## Context

`roi_models` existed in the live Supabase schema, but it only carried:

- `model_name`
- `market_region`
- `model_version`
- `description`
- `is_active`
- audit columns

That structure is not enough to support seeded investment models across multiple deal types. The v1 migration extends `roi_models` with first-class business fields instead of hiding core logic in a large JSON blob.

## Canonical fields

The business requirement asked for each ROI model to include at least:

- name
- model_type
- budget_min
- budget_max
- expected_roi_min
- expected_roi_max
- payback_months_min
- payback_months_max
- risk_level
- assumptions_json
- formula_version
- status

In v1, `name` is satisfied by the existing `model_name` column to avoid a risky rename.

## Final column set

### Existing columns retained

- `id uuid`
- `model_name text`
- `market_region text`
- `model_version text`
- `description text`
- `is_active boolean`
- `created_by uuid`
- `created_at timestamptz`
- `updated_at timestamptz`

### New columns added in migration

- `model_type text not null`
- `budget_min numeric(18,2) not null`
- `budget_max numeric(18,2) not null`
- `expected_roi_min numeric(8,4) not null`
- `expected_roi_max numeric(8,4) not null`
- `payback_months_min integer not null`
- `payback_months_max integer not null`
- `risk_level text not null`
- `assumptions_json jsonb not null default '{}'::jsonb`
- `formula_version text not null`
- `status text not null default 'draft'`

## Constraints

The migration adds guardrails:

- `budget_min <= budget_max`
- `expected_roi_min <= expected_roi_max`
- `payback_months_min <= payback_months_max`
- `status in ('draft', 'active', 'archived')`

## Design rationale

### Why keep `model_name` instead of renaming to `name`

- The live schema already exposes `model_name`.
- Renaming would create avoidable API churn for Readdy and any existing admin tooling.
- API consumers can map `model_name` to display name directly.

### Why keep `assumptions_json`

Structured assumptions still matter, but only for variable groups that are naturally nested:

- capital stack
- distribution mix
- scenario probabilities

The migration does not place core searchable ranges inside JSON. Budget, ROI, payback, type, risk, and lifecycle status are all first-class columns.

### Why keep both `model_version` and `formula_version`

They represent different concerns:

- `model_version`: catalog or product-facing version of the ROI template
- `formula_version`: scoring logic version used by evaluators or automation

This split helps when business labels stay stable but the calculation logic changes.

## Seeded models

The v1 seed file creates five baseline models:

- `micro_feature_film`
- `commercial_video_project`
- `streaming_series`
- `international_coproduction`
- `experimental_high_risk`

Each seed row includes explicit budget, ROI, payback, risk, and assumptions.

## Example read shape

```sql
select
  id,
  model_name,
  model_type,
  budget_min,
  budget_max,
  expected_roi_min,
  expected_roi_max,
  payback_months_min,
  payback_months_max,
  risk_level,
  formula_version,
  status
from public.roi_models
where status = 'active';
```

## Follow-up candidates

Consider these in v2 after staging validation:

- enum types for `model_type`, `risk_level`, and `status`
- unique constraint on `(model_name, formula_version)`
- separate `roi_model_scenarios` child table if scenario assumptions become operational data instead of reference data
