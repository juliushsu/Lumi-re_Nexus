# RLS Smoke Test Checklist v1

## Purpose

This checklist is the operator runbook for validating the Film Investment Platform staging security baseline after migrations and seed scripts are applied.

## Required inputs

- staging Supabase project with latest schema
- authenticated test users for:
  - `super_admin`
  - `shareholder_viewer`
  - `analyst`
  - `project_editor`
  - `report_viewer`
- `juliushsu@gmail.com` present and intended to remain `super_admin`

## Execution order

1. Apply migration `20260428093000_staging_security_and_roi_foundation.sql`
2. Apply seed `20260428094500_roi_models_seed.sql`
3. Apply migration `20260428101500_sample_role_assignment_staging.sql`
4. Run `supabase/scripts/staging-rls-smoke-test.sql`
5. Execute API-level role tests below

## Structure checks

- Confirm RLS is enabled on all reviewed tables.
- Confirm helper functions exist:
  - `app.current_profile_role`
  - `app.has_role`
  - `app.has_any_role`
- Confirm shareholder RPCs exist:
  - `get_projects_dashboard_summary`
  - `get_investment_plans_dashboard_summary`
  - `get_reports_dashboard_summary`
- Confirm `roi_models` contains all v1 columns.
- Confirm all five ROI seed rows exist.

## Identity and role checks

- Confirm `juliushsu@gmail.com` still has exactly one active `super_admin` profile.
- Confirm sample staging assignments only attach to users that already exist in `auth.users`.
- Confirm there are no unexpected `anon` data paths left in frontend config.

## Role-by-role smoke tests

### `super_admin`

Expected:

- can read own `user_profiles` row
- can read all reviewed base tables
- can insert/update/delete where admin policy exists
- can call all shareholder RPCs successfully

Smoke actions:

- select from `projects`
- insert a draft `investment_plans` row, then delete it
- select from `board_meetings`
- call `rpc('get_projects_dashboard_summary')`

### `project_editor`

Expected:

- can read own `user_profiles` row
- can select, insert, update `projects`
- can select `project_evaluations`
- cannot insert/update `project_evaluations`
- cannot read `reports`
- should not rely on shareholder RPCs

Smoke actions:

- create a test project
- edit the test project
- try inserting a `project_evaluations` row and confirm denial
- try selecting `reports` and confirm denial

### `analyst`

Expected:

- can read own `user_profiles` row
- can select `projects`
- can select/insert/update `project_evaluations`
- can select `roi_models`
- can select `investment_plans`
- can select `reports`
- cannot update `projects`

Smoke actions:

- select one ROI model
- create a draft `project_evaluations` row
- update that evaluation
- try updating a `projects` row and confirm denial

### `report_viewer`

Expected:

- can read own `user_profiles` row
- can select `reports`
- cannot read `projects`
- cannot read `project_evaluations`
- should not use shareholder RPCs as main data path

Smoke actions:

- select from `reports`
- try selecting from `projects` and confirm denial
- try selecting from `project_evaluations` and confirm denial

### `shareholder_viewer`

Expected:

- can read own `user_profiles` row
- can call shareholder RPCs
- cannot directly query `projects`
- cannot directly query `investment_plans`
- cannot directly query `reports`

Smoke actions:

- call `rpc('get_projects_dashboard_summary')`
- call `rpc('get_investment_plans_dashboard_summary')`
- call `rpc('get_reports_dashboard_summary')`
- try direct `from('projects').select(...)` and confirm denial or unusable result

## Readdy integration checks

- confirm role resolution reads from `user_profiles` using `user_id = auth.uid()`
- confirm shareholder dashboard hooks use RPC-only
- confirm no screen uses `anon` to hit protected business tables
- confirm project editor screens do not use delete-by-default
- confirm analyst flow reads `roi_models` from active records only

## Pass criteria

- all structural checks pass
- five ROI seeds exist
- `juliushsu@gmail.com` remains active `super_admin`
- `shareholder_viewer` succeeds only through RPC path
- forbidden direct table queries fail for the restricted roles above

## Failure guidance

- If `super_admin` cannot read `user_profiles`, stop and inspect role linkage first.
- If shareholder direct table reads succeed, stop and review frontend query surface immediately.
- If ROI seeds are missing, rerun the seed file before debugging UI behavior.
- If sample role assignments are skipped, confirm the target staging users exist in `auth.users`.
