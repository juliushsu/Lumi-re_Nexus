# CIRQUA Canonical Baseline 2026-04-28

This baseline is derived from:
- GitHub `main`
- read-only staging Supabase probe on `2026-04-28`

This document is the canonical reference for Sprint 2B reconciliation. It supersedes any assumption that was not revalidated against the current staging database.

## Existence Checks
- `organizations` table: no
- `projects` table: yes
- `projects.org_id` column: no
- `profiles` table: no
- `get_org_usage` function: no

## Public Tables
| table | has org_id | has project_id |
| --- | --- | --- |
| `board_action_items` | no | no |
| `board_meetings` | no | no |
| `board_resolutions` | no | no |
| `external_budget_snapshots` | no | no |
| `external_import_audit_logs` | no | yes |
| `external_import_field_mappings` | no | yes |
| `external_import_runs` | no | no |
| `external_project_snapshots` | no | no |
| `festival_events` | no | no |
| `investment_plans` | no | no |
| `plan_kpi_snapshots` | no | no |
| `plan_projects` | no | yes |
| `project_cast_costs` | no | yes |
| `project_cost_items` | no | yes |
| `project_costs` | no | yes |
| `project_evaluations` | no | yes |
| `project_festival_records` | no | yes |
| `project_revenues` | no | yes |
| `project_source_links` | no | yes |
| `projects` | no | no |
| `reports` | no | yes |
| `roi_model_change_logs` | no | no |
| `roi_model_weights` | no | no |
| `roi_models` | no | no |
| `user_profiles` | no | no |

## Columns By Table
- `board_action_items`: `id`, `resolution_id`, `action_title`, `owner_name`, `due_date`, `action_status`, `completed_at`, `notes`, `created_at`, `updated_at`
- `board_meetings`: `id`, `meeting_code`, `meeting_date`, `title`, `summary`, `minutes_url`, `status`, `created_at`, `updated_at`
- `board_resolutions`: `id`, `meeting_id`, `resolution_code`, `resolution_title`, `resolution_summary`, `target_type`, `target_id`, `effective_date`, `approval_status`, `created_at`, `updated_at`
- `external_budget_snapshots`: `id`, `import_run_id`, `project_source_link_id`, `source_system`, `snapshot_type`, `currency`, `budget_total`, `above_the_line_total`, `below_the_line_total`, `contingency_total`, `normalized_payload_json`, `captured_at`, `imported_by`, `created_at`, `updated_at`
- `external_import_audit_logs`: `id`, `project_id`, `project_source_link_id`, `import_run_id`, `source_system`, `event_type`, `actor_user_id`, `event_payload_json`, `created_at`
- `external_import_field_mappings`: `id`, `import_run_id`, `project_id`, `source_system`, `snapshot_type`, `source_field`, `target_table`, `target_field`, `proposed_value_json`, `current_value_json`, `mapping_status`, `approval_note`, `approved_by`, `approved_at`, `rejected_by`, `rejected_at`, `created_by`, `created_at`, `updated_at`
- `external_import_runs`: `id`, `project_source_link_id`, `source_system`, `import_status`, `snapshot_version`, `requested_by`, `started_at`, `completed_at`, `diagnostics_json`, `failure_reason`, `approved_by`, `approved_at`, `baseline_generated_by`, `baseline_generated_at`, `baseline_project_evaluation_id`, `created_at`, `updated_at`
- `external_project_snapshots`: `id`, `import_run_id`, `project_source_link_id`, `source_system`, `snapshot_type`, `external_payload_json`, `normalized_payload_json`, `captured_at`, `imported_by`, `created_at`, `updated_at`
- `festival_events`: `id`, `festival_code`, `festival_name_zh`, `festival_name_en`, `festival_group`, `region`, `prestige_score`, `market_impact_score`, `award_season_score`, `is_active`, `notes`, `created_at`, `updated_at`
- `investment_plans`: `id`, `plan_code`, `plan_name`, `entity_name`, `vintage_year`, `target_raise`, `actual_raise`, `target_irr`, `target_roi`, `target_payback_month`, `risk_tolerance`, `plan_status`, `strategy_note`, `created_at`, `updated_at`
- `plan_kpi_snapshots`: `id`, `plan_id`, `snapshot_date`, `total_allocated`, `capital_deployment_rate`, `cash_recovery_rate`, `weighted_expected_roi`, `weighted_actual_roi`, `completion_probability`, `revenue_realization_ratio`, `concentration_risk_index`, `portfolio_health_score`, `downside_exposure`, `created_at`
- `plan_projects`: `id`, `plan_id`, `project_id`, `evaluation_id`, `allocation_amount`, `allocation_ratio`, `expected_return`, `downside_case_return`, `base_case_return`, `upside_case_return`, `role_in_portfolio`, `allocation_note`, `created_at`, `updated_at`
- `project_cast_costs`: `id`, `project_id`, `cast_name`, `cast_role_type`, `billing_order`, `projected_fee`, `actual_fee`, `payment_type`, `star_power_score`, `notes`, `created_at`, `updated_at`
- `project_cost_items`: `id`, `project_id`, `cost_phase`, `cost_category`, `cost_item_name`, `vendor_or_person_name`, `projected_amount`, `actual_amount`, `notes`, `created_at`, `updated_at`, `currency`
- `project_costs`: `id`, `project_id`, `cost_type`, `projected_amount`, `actual_amount`, `created_at`, `updated_at`
- `project_evaluations`: `id`, `evaluation_code`, `project_name_zh`, `project_name_en`, `project_type`, `genre`, `region`, `language`, `estimated_budget`, `estimated_marketing_budget`, `expected_release_window`, `script_score`, `package_score`, `cast_score`, `genre_heat_score`, `platform_fit_score`, `cross_border_score`, `sponsorability_score`, `execution_feasibility_score`, `completion_probability`, `revenue_probability`, `recoup_probability`, `legal_risk_score`, `schedule_risk_score`, `weighted_total_score`, `expected_roi`, `estimated_payback_period`, `risk_level`, `investment_grade`, `analyst_comment`, `investment_recommendation`, `evaluation_status`, `created_at`, `updated_at`, `project_id`, `created_by`, `roi_model_id`, `investment_score`, `budget_efficiency`, `festival_prestige`, `distribution_strength`, `ott_signal`, `revenue_security`
- `project_festival_records`: `id`, `project_id`, `festival_event_id`, `festival_year`, `section_name`, `participation_type`, `award_name`, `result_rank`, `premiere_status`, `exposure_score`, `prestige_weight`, `roi_influence_score`, `notes`, `created_at`, `updated_at`
- `project_revenues`: `id`, `project_id`, `revenue_type`, `projected_amount`, `actual_amount`, `recognized_date`, `created_at`, `updated_at`, `revenue_source_name`, `notes`
- `project_source_links`: `id`, `project_id`, `source_system`, `external_project_id`, `link_status`, `consent_status`, `consent_scope_json`, `consent_note`, `consent_granted_by`, `consent_granted_at`, `consent_expires_at`, `consent_revoked_by`, `consent_revoked_at`, `last_imported_at`, `created_by`, `created_at`, `updated_at`
- `projects`: `id`, `project_code`, `project_name_zh`, `project_name_en`, `project_type`, `genre`, `region`, `language`, `production_year`, `release_year`, `status`, `total_budget`, `marketing_budget`, `projected_revenue`, `actual_revenue`, `projected_roi`, `actual_roi`, `payback_period_month`, `script_score`, `package_score`, `cast_score`, `director_score`, `platform_fit_score`, `marketability_score`, `ip_strength_score`, `completion_risk_score`, `legal_risk_score`, `schedule_risk_score`, `notes`, `created_at`, `updated_at`, `synopsis`
- `reports`: `id`, `report_code`, `report_type`, `report_name_zh`, `report_name_en`, `plan_id`, `project_id`, `evaluation_id`, `report_period`, `executive_summary`, `portfolio_overview`, `project_progress`, `risk_analysis`, `revenue_tracking`, `next_step_recommendation`, `ai_summary_placeholder`, `narrative_summary`, `generated_by`, `report_status`, `created_at`, `updated_at`
- `roi_model_change_logs`: `id`, `roi_model_id`, `resolution_id`, `factor_name`, `old_weight`, `new_weight`, `change_reason`, `changed_by`, `changed_at`
- `roi_model_weights`: `id`, `model_id`, `factor_name`, `weight`, `created_at`, `updated_at`
- `roi_models`: `id`, `model_name`, `market_region`, `model_version`, `description`, `is_active`, `created_by`, `created_at`, `updated_at`, `model_type`, `budget_min`, `budget_max`, `expected_roi_min`, `expected_roi_max`, `payback_months_min`, `payback_months_max`, `risk_level`, `assumptions_json`, `formula_version`, `status`
- `user_profiles`: `id`, `user_id`, `email`, `full_name`, `role`, `status`, `created_at`, `updated_at`, `department`

## RLS Enabled Status
- RLS enabled: `board_action_items`, `board_meetings`, `board_resolutions`, `external_budget_snapshots`, `external_import_audit_logs`, `external_import_field_mappings`, `external_import_runs`, `external_project_snapshots`, `investment_plans`, `project_evaluations`, `project_source_links`, `projects`, `reports`, `roi_model_change_logs`, `roi_models`, `user_profiles`
- RLS not enabled: `festival_events`, `plan_kpi_snapshots`, `plan_projects`, `project_cast_costs`, `project_cost_items`, `project_costs`, `project_festival_records`, `project_revenues`, `roi_model_weights`

## Policies
- `board_action_items`: `board_action_items_manage_super_admin_v1`, `board_action_items_select_super_admin_v1`
- `board_meetings`: `board_meetings_manage_super_admin_v1`, `board_meetings_select_super_admin_v1`
- `board_resolutions`: `board_resolutions_manage_super_admin_v1`, `board_resolutions_select_super_admin_v1`
- `external_budget_snapshots`: `external_budget_snapshots_manage_super_admin_v1`, `external_budget_snapshots_select_admin_analyst_v1`
- `external_import_audit_logs`: `external_import_audit_logs_insert_admin_analyst_v1`, `external_import_audit_logs_select_admin_analyst_v1`
- `external_import_field_mappings`: `external_import_field_mappings_delete_super_admin_v1`, `external_import_field_mappings_insert_admin_analyst_v1`, `external_import_field_mappings_select_admin_analyst_v1`, `external_import_field_mappings_update_admin_analyst_v1`
- `external_import_runs`: `external_import_runs_manage_super_admin_v1`, `external_import_runs_select_admin_analyst_v1`
- `external_project_snapshots`: `external_project_snapshots_manage_super_admin_v1`, `external_project_snapshots_select_admin_analyst_v1`
- `investment_plans`: `investment_plans_manage_super_admin_v1`, `investment_plans_select_roles_v1`
- `project_evaluations`: `project_evaluations_delete_super_admin_v1`, `project_evaluations_insert_analyst_v1`, `project_evaluations_select_roles_v1`, `project_evaluations_update_analyst_v1`
- `project_source_links`: `project_source_links_manage_super_admin_v1`, `project_source_links_select_admin_analyst_v1`
- `projects`: `projects_delete_super_admin_v1`, `projects_manage_project_editor_v1`, `projects_select_roles_v1`, `projects_update_project_editor_v1`
- `reports`: `reports_manage_super_admin_v1`, `reports_select_roles_v1`
- `roi_model_change_logs`: `roi_model_change_logs_manage_super_admin_v1`, `roi_model_change_logs_select_super_admin_v1`
- `roi_models`: `roi_models_manage_super_admin_v1`, `roi_models_select_roles_v1`
- `user_profiles`: `user_profiles_manage_super_admin_v1`, `user_profiles_select_self_or_super_admin_v1`

## Grants Summary
Current direct `anon` table privileges still open:
- `festival_events`
- `plan_kpi_snapshots`
- `plan_projects`
- `project_cast_costs`
- `project_cost_items`
- `project_costs`
- `project_festival_records`
- `project_revenues`

Current direct `anon` access blocked:
- `projects`
- `project_evaluations`
- `investment_plans`
- `reports`
- `roi_models`
- `user_profiles`

Current `authenticated` pattern:
- broad table privileges still exist on many tables
- effective access is partly controlled by existing RLS on protected tables
- several project-financial tables still have no RLS despite broad grants

Current `service_role` pattern:
- broad operational access remains available across the inspected core tables

## RPC / Functions
- `approve_cirqua_field_mapping(uuid, text)`
- `create_cirqua_import_run(uuid)`
- `create_cirqua_project_link(uuid, text, jsonb)`
- `generate_project_evaluation_baseline_from_cirqua(uuid)`
- `get_investment_plans_dashboard_summary()`
- `get_projects_dashboard_summary()`
- `get_reports_dashboard_summary()`
- `grant_cirqua_consent(uuid, jsonb, timestamptz)`
- `mark_cirqua_import_snapshot_received(uuid, jsonb, jsonb)`
- `propose_cirqua_field_mappings(uuid)`
- `reject_cirqua_field_mapping(uuid, text)`
- `update_project_cast_costs_updated_at()`
- `update_project_cost_items_updated_at()`
- `update_project_costs_updated_at()`
- `update_project_revenues_updated_at()`

## Triggers
- `project_cast_costs.trigger_update_project_cast_costs_updated_at`
- `project_cost_items.trigger_update_project_cost_items_updated_at`
- `project_costs.trigger_update_project_costs_updated_at`
- `project_revenues.trigger_update_project_revenues_updated_at`

## Canonical Interpretation
- Current staging is not tenant-ready.
- The first tenant migration must introduce canonical org identity before any backfill logic.
- `profiles` and `get_org_usage` are not part of the verified current staging baseline.
