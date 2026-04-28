# Project Evaluation Flow v1

## Purpose

This document defines the backend contract for project evaluation workflows without changing the current UI.

## Actors

- `super_admin`
- `project_editor`
- `analyst`
- `report_viewer`
- `shareholder_viewer`

## Core tables in the flow

- `projects`
- `project_evaluations`
- `roi_models`
- `investment_plans`
- `reports`

## Flow

### 1. Project creation

Actor:
`project_editor` or `super_admin`

Table:
`public.projects`

Allowed operations:

- `insert`
- `update`
- `select`

Expected minimum fields:

- `project_code`
- `project_name_zh`
- `project_name_en`
- `project_type`
- `genre`
- `region`
- `language`
- `status`

Optional finance/scoring fields may be null at creation time.

### 2. Evaluation drafting

Actor:
`analyst` or `super_admin`

Table:
`public.project_evaluations`

Allowed operations:

- `insert`
- `update`
- `select`

Expected references:

- `project_id`
- `roi_model_id`

Recommended fields for first save:

- `evaluation_code`
- `project_name_zh`
- `project_name_en`
- `project_type`
- `genre`
- `region`
- `language`
- `evaluation_status`
- `expected_roi`
- `estimated_payback_period`
- `risk_level`
- `investment_recommendation`

### 3. ROI model lookup

Actors:

- `analyst`
- `project_editor`
- `super_admin`

Table:
`public.roi_models`

Allowed operation:

- `select`

Recommended filter:

```sql
select *
from public.roi_models
where status = 'active'
order by model_name asc;
```

### 4. Report consumption

Actors:

- `report_viewer`
- `analyst`
- `super_admin`

Table:
`public.reports`

Allowed operation:

- `select`

### 5. Shareholder dashboard consumption

Actor:
`shareholder_viewer`

Do not query base tables directly. Use these RPCs:

- `rpc('get_projects_dashboard_summary')`
- `rpc('get_investment_plans_dashboard_summary')`
- `rpc('get_reports_dashboard_summary')`

These return summary-safe fields only.

## Readdy frontend contract

### Project editor screens

Use:

- `from('projects').select(...)`
- `from('projects').insert(...)`
- `from('projects').update(...).eq('id', projectId)`

Avoid:

- delete flows for now

Suggested select columns:

`id, project_code, project_name_zh, project_name_en, project_type, genre, region, language, status, total_budget, marketing_budget, projected_revenue, projected_roi, payback_period_month, created_at, updated_at`

### Analyst evaluation screens

Use:

- `from('project_evaluations').select(...)`
- `from('project_evaluations').insert(...)`
- `from('project_evaluations').update(...).eq('id', evaluationId)`
- `from('roi_models').select(...)`
- `from('projects').select(...)`

Suggested select columns for evaluations:

`id, evaluation_code, project_id, roi_model_id, project_name_zh, project_name_en, project_type, genre, region, language, estimated_budget, estimated_marketing_budget, expected_release_window, script_score, package_score, cast_score, genre_heat_score, platform_fit_score, cross_border_score, sponsorability_score, execution_feasibility_score, completion_probability, revenue_probability, recoup_probability, legal_risk_score, schedule_risk_score, weighted_total_score, expected_roi, estimated_payback_period, risk_level, investment_grade, analyst_comment, investment_recommendation, evaluation_status, created_at, updated_at`

### Report viewer screens

Use:

- `from('reports').select(...)`

Suggested select columns:

`id, report_code, report_type, report_name_zh, report_name_en, plan_id, project_id, evaluation_id, report_period, report_status, executive_summary, narrative_summary, next_step_recommendation, created_at, updated_at`

### Shareholder dashboard screens

Use only:

- `rpc('get_projects_dashboard_summary')`
- `rpc('get_investment_plans_dashboard_summary')`
- `rpc('get_reports_dashboard_summary')`

Do not use:

- `from('projects')`
- `from('investment_plans')`
- `from('reports')`

## Example Supabase client snippets

### Load active ROI models

```ts
const { data, error } = await supabase
  .from('roi_models')
  .select(`
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
  `)
  .eq('status', 'active')
  .order('model_name', { ascending: true })
```

### Create evaluation draft

```ts
const { data, error } = await supabase
  .from('project_evaluations')
  .insert({
    evaluation_code,
    project_id,
    roi_model_id,
    project_name_zh,
    project_name_en,
    project_type,
    genre,
    region,
    language,
    evaluation_status: 'draft'
  })
  .select()
  .single()
```

### Load shareholder dashboard cards

```ts
const { data: projects } = await supabase.rpc('get_projects_dashboard_summary')
const { data: plans } = await supabase.rpc('get_investment_plans_dashboard_summary')
const { data: reports } = await supabase.rpc('get_reports_dashboard_summary')
```

## Risks for frontend integration

- Existing UI code may currently query base tables with the `anon` key. Those requests will fail after RLS v1.
- `shareholder_viewer` must switch to RPC-based reads before that role is tested.
- If the app assumes `reports` or `investment_plans` are writable by analysts, that will need a v2 role expansion.
