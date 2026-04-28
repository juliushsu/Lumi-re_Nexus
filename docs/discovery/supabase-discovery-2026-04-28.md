# Supabase Connectivity and Structure Notes

Date: 2026-04-28
Project ref: `gyoiqrywhcufrsqgyjre`
REST URL: `https://gyoiqrywhcufrsqgyjre.supabase.co/rest/v1/`

## What was verified

- The Supabase project domain is reachable over HTTPS.
- The REST API is reachable and responds normally.
- The `service_role` key can read the PostgREST OpenAPI schema for the `public` profile.
- The following tables are exposed via PostgREST in the `public` schema:
  - `board_action_items`
  - `board_meetings`
  - `board_resolutions`
  - `festival_events`
  - `investment_plans`
  - `plan_kpi_snapshots`
  - `plan_projects`
  - `project_cast_costs`
  - `project_cost_items`
  - `project_costs`
  - `project_evaluations`
  - `project_festival_records`
  - `project_revenues`
  - `projects`
  - `reports`
  - `roi_model_change_logs`
  - `roi_model_weights`
  - `roi_models`
  - `user_profiles`
- The `anon` key can also read at least `projects` and `user_profiles` through REST under current settings.

## Important observations

- Core business tables currently appear to be structurally present but empty:
  - `projects`: `0`
  - `project_evaluations`: `0`
  - `investment_plans`: `0`
  - `reports`: `0`
  - `roi_models`: `0`
- `user_profiles` currently has `1` row.
- `user_profiles` being readable with the `anon` key likely needs a security review unless this is intentionally public.

## Public schema shape

### `projects`

Key columns:
`id`, `project_code`, `project_name_zh`, `project_name_en`, `project_type`, `genre`, `region`, `language`, `production_year`, `release_year`, `status`, `total_budget`, `marketing_budget`, `projected_revenue`, `actual_revenue`, `projected_roi`, `actual_roi`, `payback_period_month`, `script_score`, `package_score`, `cast_score`, `director_score`, `platform_fit_score`, `marketability_score`, `ip_strength_score`, `completion_risk_score`, `legal_risk_score`, `schedule_risk_score`, `synopsis`, `notes`, `created_at`, `updated_at`

### `project_evaluations`

Key columns:
`id`, `project_id`, `roi_model_id`, `evaluation_code`, `evaluation_status`, `investment_recommendation`, `investment_grade`, `investment_score`, `weighted_total_score`, `expected_roi`, `estimated_budget`, `estimated_marketing_budget`, `estimated_payback_period`, `completion_probability`, `recoup_probability`, `revenue_probability`, `revenue_security`, `risk_level`, `script_score`, `package_score`, `cast_score`, `platform_fit_score`, `genre_heat_score`, `festival_prestige`, `distribution_strength`, `cross_border_score`, `sponsorability_score`, `execution_feasibility_score`, `legal_risk_score`, `schedule_risk_score`, `analyst_comment`, `created_by`, `created_at`, `updated_at`

### `investment_plans`

Key columns:
`id`, `plan_code`, `plan_name`, `entity_name`, `plan_status`, `risk_tolerance`, `strategy_note`, `target_raise`, `actual_raise`, `target_roi`, `target_irr`, `target_payback_month`, `vintage_year`, `created_at`, `updated_at`

### `plan_projects`

Key columns:
`id`, `plan_id`, `project_id`, `evaluation_id`, `allocation_amount`, `allocation_ratio`, `allocation_note`, `expected_return`, `base_case_return`, `upside_case_return`, `downside_case_return`, `role_in_portfolio`, `created_at`, `updated_at`

### `plan_kpi_snapshots`

Key columns:
`id`, `plan_id`, `snapshot_date`, `total_allocated`, `weighted_expected_roi`, `weighted_actual_roi`, `capital_deployment_rate`, `cash_recovery_rate`, `revenue_realization_ratio`, `completion_probability`, `concentration_risk_index`, `portfolio_health_score`, `downside_exposure`, `created_at`

### `reports`

Key columns:
`id`, `report_code`, `report_name_zh`, `report_name_en`, `report_type`, `report_period`, `report_status`, `project_id`, `evaluation_id`, `plan_id`, `executive_summary`, `narrative_summary`, `portfolio_overview`, `project_progress`, `revenue_tracking`, `risk_analysis`, `next_step_recommendation`, `ai_summary_placeholder`, `generated_by`, `created_at`, `updated_at`

### `roi_models`

Key columns:
`id`, `model_name`, `model_version`, `description`, `market_region`, `is_active`, `created_by`, `created_at`, `updated_at`

Related tables:
- `roi_model_weights`
- `roi_model_change_logs`

### Supporting tables

- `festival_events`
- `project_festival_records`
- `project_costs`
- `project_cost_items`
- `project_cast_costs`
- `project_revenues`
- `board_meetings`
- `board_resolutions`
- `board_action_items`
- `user_profiles`

## Architecture interpretation

This looks like a film investment analysis data model with these main domains:

- Project master data and scoring: `projects`
- Investment evaluation layer: `project_evaluations`
- Portfolio construction and KPI tracking: `investment_plans`, `plan_projects`, `plan_kpi_snapshots`
- ROI methodology governance: `roi_models`, `roi_model_weights`, `roi_model_change_logs`
- Revenue, cost, cast, festival and reporting support tables
- Governance workflow through board meeting and resolution tables

## Gaps in the current local workspace

- The local project folder is empty right now.
- There is no application code, migration folder, ERD, README, or architecture document in this workspace to cross-check against the live Supabase structure.

## Recommended discussion points with CTO / Readdy

- Confirm whether `anon` access to `user_profiles` is intentional.
- Confirm whether RLS policies have been fully designed and enabled for all public tables.
- Decide whether schema ownership should remain in `public` or be split into clearer domains.
- Add migration files and seed data to source control so the live database structure is reproducible.
- Create a lightweight ERD and data dictionary from the current schema.
- Verify whether auth users are expected to map 1:1 to `user_profiles.user_id`.
- Confirm whether `roi_models` and related weights should be seeded by default.

## Not fully verified

- Direct Postgres login via the provided connection string was not fully validated in this environment because `psql` is not installed locally and raw DNS/TCP checks to the database host were unreliable from the execution environment.
- Despite that, HTTPS-level REST connectivity to the Supabase project is confirmed.
