# Readdy Supabase Query Map v1

## Purpose

This document is the frontend integration map for Readdy. It does not change UI design. It only defines which Supabase resources are safe to call after RLS v1.

## Hard rules

- Do not use `anon` direct reads for core business data.
- Do not put `service_role` anywhere in frontend code.
- `shareholder_viewer` must only use RPC endpoints for dashboard summaries.
- Base table access must follow the role-specific contract below.

## Allowed query surfaces by role

### `super_admin`

Can use:

- direct table queries
- shareholder RPCs

Tables/RPC:

- `user_profiles`
- `projects`
- `project_evaluations`
- `investment_plans`
- `reports`
- `roi_models`
- `board_meetings`
- `board_resolutions`
- `board_action_items`
- `roi_model_change_logs`
- `rpc('get_projects_dashboard_summary')`
- `rpc('get_investment_plans_dashboard_summary')`
- `rpc('get_reports_dashboard_summary')`

### `project_editor`

Can use:

- direct table queries

Allowed direct tables:

- `projects`: `select`, `insert`, `update`
- `project_evaluations`: `select`
- `roi_models`: `select`
- `investment_plans`: `select`
- `user_profiles`: self profile only

Do not use:

- `reports`
- `board_meetings`
- `board_resolutions`
- `board_action_items`
- `roi_model_change_logs`
- shareholder RPCs as primary data source

### `analyst`

Can use:

- direct table queries

Allowed direct tables:

- `projects`: `select`
- `project_evaluations`: `select`, `insert`, `update`
- `roi_models`: `select`
- `investment_plans`: `select`
- `reports`: `select`
- `user_profiles`: self profile only

Do not use:

- `board_meetings`
- `board_resolutions`
- `board_action_items`
- `roi_model_change_logs`

### `report_viewer`

Can use:

- direct table queries

Allowed direct tables:

- `reports`: `select`
- `user_profiles`: self profile only

Do not use:

- `projects`
- `project_evaluations`
- `investment_plans`
- `roi_models`
- shareholder RPCs as primary data source

### `shareholder_viewer`

Can use:

- RPC only

Allowed RPCs:

- `rpc('get_projects_dashboard_summary')`
- `rpc('get_investment_plans_dashboard_summary')`
- `rpc('get_reports_dashboard_summary')`

Forbidden direct table access:

- `projects`
- `investment_plans`
- `reports`
- all other reviewed business tables

## Query map

### 1. Resolve signed-in user role

Use:

```ts
const { data, error } = await supabase
  .from('user_profiles')
  .select('user_id, email, full_name, role, status, department')
  .eq('user_id', user.id)
  .single()
```

Expected roles:

- `super_admin`
- `shareholder_viewer`
- `analyst`
- `project_editor`
- `report_viewer`

### 2. Project editor screens

Use:

```ts
supabase
  .from('projects')
  .select(`
    id,
    project_code,
    project_name_zh,
    project_name_en,
    project_type,
    genre,
    region,
    language,
    status,
    total_budget,
    marketing_budget,
    projected_revenue,
    actual_revenue,
    projected_roi,
    actual_roi,
    payback_period_month,
    synopsis,
    notes,
    created_at,
    updated_at
  `)
```

Write calls:

```ts
supabase.from('projects').insert(payload)
supabase.from('projects').update(payload).eq('id', projectId)
```

Do not use:

```ts
supabase.from('projects').delete()
```

### 3. Analyst evaluation screens

Use:

```ts
supabase
  .from('project_evaluations')
  .select(`
    id,
    evaluation_code,
    project_id,
    roi_model_id,
    project_name_zh,
    project_name_en,
    project_type,
    genre,
    region,
    language,
    estimated_budget,
    estimated_marketing_budget,
    expected_release_window,
    script_score,
    package_score,
    cast_score,
    genre_heat_score,
    platform_fit_score,
    cross_border_score,
    sponsorability_score,
    execution_feasibility_score,
    completion_probability,
    revenue_probability,
    recoup_probability,
    legal_risk_score,
    schedule_risk_score,
    weighted_total_score,
    expected_roi,
    estimated_payback_period,
    risk_level,
    investment_grade,
    investment_recommendation,
    analyst_comment,
    evaluation_status,
    created_at,
    updated_at
  `)
```

Write calls:

```ts
supabase.from('project_evaluations').insert(payload)
supabase.from('project_evaluations').update(payload).eq('id', evaluationId)
```

Reference queries:

```ts
supabase
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

supabase
  .from('projects')
  .select('id, project_code, project_name_zh, project_name_en, project_type, status')
  .order('updated_at', { ascending: false })
```

### 4. Report viewer screens

Use:

```ts
supabase
  .from('reports')
  .select(`
    id,
    report_code,
    report_type,
    report_name_zh,
    report_name_en,
    plan_id,
    project_id,
    evaluation_id,
    report_period,
    report_status,
    executive_summary,
    narrative_summary,
    next_step_recommendation,
    ai_summary_placeholder,
    created_at,
    updated_at
  `)
```

### 5. Shareholder dashboard screens

Use only:

```ts
const { data: projects, error: projectsError } =
  await supabase.rpc('get_projects_dashboard_summary')

const { data: plans, error: plansError } =
  await supabase.rpc('get_investment_plans_dashboard_summary')

const { data: reports, error: reportsError } =
  await supabase.rpc('get_reports_dashboard_summary')
```

Never use:

```ts
supabase.from('projects').select('*')
supabase.from('investment_plans').select('*')
supabase.from('reports').select('*')
```

## Quick matrix

| Surface | super_admin | project_editor | analyst | report_viewer | shareholder_viewer |
|---|---|---|---|---|---|
| `user_profiles` | self + admin management | self only | self only | self only | self only |
| `projects` direct | yes | yes | read only | no | no |
| `project_evaluations` direct | yes | read only | yes | no | no |
| `investment_plans` direct | yes | read only | read only | no | no |
| `reports` direct | yes | no | read only | read only | no |
| `roi_models` direct | yes | read only | read only | no | no |
| `board_*` direct | yes | no | no | no | no |
| `roi_model_change_logs` direct | yes | no | no | no | no |
| shareholder RPCs | yes | avoid | avoid | avoid | required |

## Error handling guidance

When a role hits a denied surface, expect a Supabase permission error or an empty result set depending on endpoint behavior. Readdy should:

- detect role first from `user_profiles`
- route to the matching query map
- avoid fallback retries on forbidden direct tables for `shareholder_viewer`

## Implementation note for Readdy

The UI can stay unchanged if the data hooks are swapped according to role:

- same cards and tables
- different query surface underneath

This is especially important for shareholder dashboards, where the UI may still look identical but the data source must be RPC-only.
