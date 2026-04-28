# RLS Policy v1

## Scope

This document covers the staging-first security baseline for:

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

## Security goals

- Enable RLS on all reviewed business tables.
- Block `anon` from all direct CRUD access.
- Keep access on `authenticated`, but gate every table through `user_profiles.role`.
- Preserve `super_admin` as the only full-management role.
- Provide a constrained summary-read path for `shareholder_viewer`.
- Avoid storing privileged keys in the repository.

## Role model

Roles are resolved from `public.user_profiles.role` for the active `auth.uid()`.

Supported roles in v1:

- `super_admin`
- `shareholder_viewer`
- `analyst`
- `project_editor`
- `report_viewer`

`user_profiles.status = 'active'` is required for role resolution.

## Helper functions

Migration `20260428093000_staging_security_and_roi_foundation.sql` adds:

- `app.current_profile_role()`
- `app.is_authenticated()`
- `app.has_role(required_role text)`
- `app.has_any_role(required_roles text[])`

These are `stable`, and the role helpers are `security definer` so policies can resolve the caller role safely from `user_profiles`.

## Direct table access matrix

### `user_profiles`

- `anon`: no access
- `authenticated`: can read own row only
- `super_admin`: full CRUD

### `projects`

- `anon`: no access
- `project_editor`: select, insert, update
- `analyst`: select
- `super_admin`: full CRUD
- `shareholder_viewer`: no direct table access path in v1
- `report_viewer`: no direct table access path in v1

### `project_evaluations`

- `anon`: no access
- `analyst`: select, insert, update
- `project_editor`: select
- `super_admin`: full CRUD

### `investment_plans`

- `anon`: no access
- `analyst`: select
- `project_editor`: select
- `super_admin`: full CRUD
- `shareholder_viewer`: no direct table access path in v1

### `reports`

- `anon`: no access
- `report_viewer`: select
- `analyst`: select
- `super_admin`: full CRUD
- `shareholder_viewer`: no direct table access path in v1

### `roi_models`

- `anon`: no access
- `analyst`: select
- `project_editor`: select
- `super_admin`: full CRUD

### `board_meetings`

- `anon`: no access
- `super_admin`: full CRUD

### `board_resolutions`

- `anon`: no access
- `super_admin`: full CRUD

### `board_action_items`

- `anon`: no access
- `super_admin`: full CRUD

### `roi_model_change_logs`

- `anon`: no access
- `super_admin`: full CRUD

## Shareholder summary access

Postgres RLS controls rows, not field-level summaries for app roles sharing the same database role. Because Supabase app users connect as `authenticated`, RLS alone cannot safely enforce "summary columns only" on base tables.

To avoid exposing full rows to `shareholder_viewer`, v1 introduces summary RPCs instead of direct base-table reads:

- `public.get_projects_dashboard_summary()`
- `public.get_investment_plans_dashboard_summary()`
- `public.get_reports_dashboard_summary()`

These functions:

- run as `security definer`
- return only preselected summary columns
- return rows only for `super_admin` or `shareholder_viewer`

Frontends should treat these RPCs as the only allowed read surface for shareholder dashboards.

## Why this does not break current super_admin login

- Auth itself is untouched.
- Existing `super_admin` sign-in continues to work as long as the user has an active `user_profiles` row with `role = 'super_admin'`.
- `user_profiles` self-read remains available so the application can resolve its own role after login.

## Staging rollout notes

Recommended rollout order:

1. Apply migration in staging.
2. Verify the existing `super_admin` can still sign in and read `user_profiles`.
3. Seed ROI models.
4. Test each role with JWT-backed requests.
5. Update frontend data calls to use shareholder summary RPCs before giving `shareholder_viewer` access.

## Known limitations

- `investment_plans` and `reports` are read-only for most roles in v1. If product needs editor flows, add explicit writer roles in v2.
- Board tables are currently locked to `super_admin` only.
- Column-level security is intentionally handled through RPC contracts, not direct table access, for shareholder summaries.
