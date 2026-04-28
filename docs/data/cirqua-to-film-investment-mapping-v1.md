# CIRQUA to Film Investment Mapping v1

## Purpose

This document defines how CIRQUA data should map into Film Investment Platform structures without directly overwriting human-maintained canonical records.

## Mapping principles

- CIRQUA is the source for imported operational detail, not canonical project ownership.
- Imported records first land in snapshot tables.
- Human-approved mappings determine what becomes baseline input.
- If a CIRQUA field has no safe canonical destination, keep it in a snapshot or dedicated import table rather than forcing it into JSON on core business tables.

## Recommended source layers

- project profile
- budget summary
- cost actuals
- shooting schedule
- revenue assumptions
- crew/vendor cost categories

## Canonical project ownership rule

`projects` remains the canonical investment project record.

Imported CIRQUA values may:

- enrich missing project data
- create approved cost/schedule baselines
- drive evaluation recalculation

Imported CIRQUA values may not:

- silently overwrite manually curated project identity fields
- bypass consent
- bypass analyst or super admin approval when mapping is required

## Table mapping overview

| CIRQUA layer | Primary landing table | Canonical or baseline target | Notes |
|---|---|---|---|
| project profile | `external_project_snapshots` | `projects` plus approved baseline fields | preserve canonical ownership in Film Investment Platform |
| budget summary | `external_budget_snapshots` | budget baseline layer and selected `projects` / `project_evaluations` budget fields | use approved aggregate values |
| cost actuals | `external_cost_actual_snapshots` | `project_costs`, `project_cost_items`, baseline cost aggregates | do not expose raw detail to shareholder viewers |
| shooting schedule | `external_schedule_snapshots` | schedule baseline layer and evaluation risk inputs | may affect completion probability and schedule risk |
| revenue assumptions | `external_revenue_assumption_snapshots` | evaluation revenue assumptions and ROI scenario inputs | only if explicitly authorized |
| crew/vendor categories | `external_cost_actual_snapshots` and category mapping tables | `project_cast_costs`, `project_cost_items`, cost category baselines | requires normalized category mapping |

## Detailed field mapping

### 1. Project profile

| CIRQUA concept | Landing field | Target field | Mapping notes |
|---|---|---|---|
| external project id | `project_source_links.external_project_id` | none | linkage only |
| production title local | `external_project_snapshots.normalized_payload_json.project_name_zh` | `projects.project_name_zh` | do not auto-overwrite if manually curated |
| production title english | `external_project_snapshots.normalized_payload_json.project_name_en` | `projects.project_name_en` | approval required if changed |
| format/type | `external_project_snapshots.normalized_payload_json.project_type` | `projects.project_type` | map to controlled project types |
| genre | `external_project_snapshots.normalized_payload_json.genre` | `projects.genre` | normalization may be required |
| language | `external_project_snapshots.normalized_payload_json.language` | `projects.language` | safe enrichment candidate |
| region/territory | `external_project_snapshots.normalized_payload_json.region` | `projects.region` | normalize to platform region taxonomy |
| synopsis/logline | `external_project_snapshots.normalized_payload_json.synopsis` | `projects.synopsis` | manual approval preferred |
| production status | `external_project_snapshots.normalized_payload_json.production_status` | `projects.status` | do not overwrite evaluation workflow status blindly |

### 2. Budget summary

| CIRQUA concept | Landing field | Target field | Mapping notes |
|---|---|---|---|
| total budget | `external_budget_snapshots.budget_total` | `projects.total_budget` and/or approved cost baseline | baseline-first, not direct overwrite |
| marketing budget | normalized snapshot payload | `projects.marketing_budget` | only if CIRQUA explicitly carries this concept |
| above-the-line total | `external_budget_snapshots.above_the_line_total` | baseline cost analytics | add dedicated baseline field later if operationally needed |
| below-the-line total | `external_budget_snapshots.below_the_line_total` | baseline cost analytics | same as above |
| contingency | `external_budget_snapshots.contingency_total` | baseline cost analytics | may affect downside scenario modeling |
| currency | `external_budget_snapshots.currency` | baseline metadata | enforce single-project currency normalization |

### 3. Cost actuals

| CIRQUA concept | Landing field | Target field | Mapping notes |
|---|---|---|---|
| cost line id | `external_cost_actual_snapshots.source_line_item_id` | none | traceability key |
| cost category | `external_cost_actual_snapshots.cost_category` | `project_costs.cost_type` or `project_cost_items.cost_category` | category normalization required |
| vendor/crew name | `external_cost_actual_snapshots.vendor_or_crew_name` | `project_cost_items.vendor_or_person_name` | shareholder viewers must never see raw names unless policy changes |
| actual amount | `external_cost_actual_snapshots.cost_amount` | `project_costs.actual_amount` / `project_cost_items.actual_amount` | import to baseline or mirrored detail table |
| incurred date | `external_cost_actual_snapshots.incurred_on` | future actual cost timeline analytics | useful for burn-rate analysis |

### 4. Shooting schedule

| CIRQUA concept | Landing field | Target field | Mapping notes |
|---|---|---|---|
| planned start | `external_schedule_snapshots.planned_start_date` | schedule baseline | do not overwrite project identity |
| planned end | `external_schedule_snapshots.planned_end_date` | schedule baseline | affects payback and release timing assumptions |
| actual start | `external_schedule_snapshots.actual_start_date` | schedule progress baseline | may feed completion probability |
| actual end | `external_schedule_snapshots.actual_end_date` | schedule progress baseline | same |
| completion percent | `external_schedule_snapshots.completion_percent` | evaluation completion and schedule risk inputs | analyst approval recommended |
| schedule phase | `external_schedule_snapshots.schedule_phase` | phase analytics | may need controlled taxonomy |

### 5. Revenue assumptions

| CIRQUA concept | Landing field | Target field | Mapping notes |
|---|---|---|---|
| assumption name | `external_revenue_assumption_snapshots.assumption_name` | scenario assumption layer | never auto-merge into approved investor forecast |
| projected amount | `external_revenue_assumption_snapshots.projected_amount` | `projects.projected_revenue` or evaluation baseline | only after approval |
| confidence score | `external_revenue_assumption_snapshots.confidence_score` | Monte Carlo input calibration | more appropriate for scenario engine than direct UI display |
| assumption type | `external_revenue_assumption_snapshots.assumption_type` | revenue taxonomy layer | controlled mapping needed |

### 6. Crew/vendor cost categories

| CIRQUA concept | Landing field | Target field | Mapping notes |
|---|---|---|---|
| crew role or vendor type | normalized import payload | `project_cast_costs.cast_role_type` or `project_cost_items.cost_category` | may require split mapping |
| crew or vendor name | normalized import payload | `project_cast_costs.cast_name` or `project_cost_items.vendor_or_person_name` | restrict visibility under RLS |
| contracted/projected fee | normalized import payload | `project_cast_costs.projected_fee` or `project_cost_items.projected_amount` | use only when business meaning matches |
| actual fee | normalized import payload | `project_cast_costs.actual_fee` or `project_cost_items.actual_amount` | same |

## Human approval states

Recommended mapping statuses:

- `pending_review`
- `approved_for_baseline`
- `approved_for_reference_only`
- `rejected`
- `superseded`

## Baseline generation output

After approval, the import pipeline should generate:

- approved project profile enrichments
- approved budget baseline
- approved cost baseline
- approved schedule baseline
- approved revenue assumption baseline
- initial or refreshed `project_evaluation` draft

## Suggested future schema additions

If this architecture proceeds, consider these dedicated tables in addition to snapshot storage:

- `project_budget_baselines`
- `project_schedule_baselines`
- `project_revenue_assumption_baselines`
- `project_import_baseline_versions`

These are preferable to stuffing baseline history into `projects` or `project_evaluations`.

## Data quality risks

- one CIRQUA field may map to multiple investment meanings depending on project type
- vendor categories may not match investment reporting categories
- imported actuals may include accounting states not suitable for investor reporting
- revenue assumptions from operations may be too optimistic or not rights-cleared
- schedule completion percentages may be operationally useful but not audit-grade
