# CIRQUA Stabilization Sprint 2E Org Lockdown & RLS Plan

## Scope
This round hardened `public.organizations` on **staging only**.

Production was not touched.

Preflight snapshot:
- [CIRQUA_SPRINT2E_PREFLIGHT_SECURITY_SNAPSHOT.md](/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_SPRINT2E_PREFLIGHT_SECURITY_SNAPSHOT.md)

Applied staging migration:
- [supabase/migrations/20260428213000_sprint2e_staging_organizations_lockdown.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428213000_sprint2e_staging_organizations_lockdown.sql)

Rollback draft:
- [supabase/scripts/20260428_sprint2e_staging_organizations_lockdown_rollback_draft.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2e_staging_organizations_lockdown_rollback_draft.sql)

## Organizations Lockdown Result
Before migration:
- RLS disabled
- no policies
- `anon` / `authenticated` / `service_role` all had direct table privileges

After migration:
- RLS enabled on `public.organizations`
- `anon` direct table access revoked
- `authenticated` reduced to `SELECT` only
- `service_role` retained full management privileges
- `authenticated` can only read the row whose `id = current_user_org_id()`

Verified final state:
- `anon -> organizations`: denied with `401 / 42501 permission denied for table organizations`
- `authenticated -> organizations`: returns only the caller org row
- `service_role -> organizations`: can read all org rows

Temporary verification method:
- created one temporary authenticated analyst in the default staging org
- created one temporary shadow org row
- verified the authenticated analyst only saw the default org, while `service_role` saw both
- cleaned up the temporary analyst and shadow org after verification

Final staging state after cleanup:
- `organizations` rows: `1`
- `projects_with_org_id`: `1`
- `projects_null_org_id`: `0`
- `user_profiles_with_org_id`: `5`
- `user_profiles_null_org_id`: `0`

## Helper Function Design
Implemented helper:
- `public.current_user_org_id()`

Behavior:
- security definer
- stable SQL function
- resolves `org_id` from `public.user_profiles`
- keyed by `auth.uid()`
- only active profiles are considered

Purpose:
- minimal trusted org lookup for tenant-aware RLS
- avoids relying on frontend-supplied headers
- keeps the current Supabase session model based on `auth.uid()`

## Verification Results
Verified:
- `organizations` RLS enabled: yes
- `organizations` policies present: yes
- `organizations` helper function present: yes
- `anon` cannot directly read organizations: yes
- `authenticated` only reads own org: yes
- `service_role` can read organizations: yes
- `projects` still readable for allowed roles: yes
- `user_profiles` self-read behavior still works: yes
- Sprint 2D backfill results remained intact: yes

Important remaining risk:
- `projects` and `user_profiles` are still governed by role-based policies, not tenant-scoped policies
- this is expected for Sprint 2E; tenant-scoped table expansion is deferred

## Staged RLS Plan
### Phase A

| table | RLS mode | helper needed | frontend context needed | breaking risk |
| --- | --- | --- | --- | --- |
| `organizations` | org-scoped self-org read, service-only write | `public.current_user_org_id()` | standard Supabase auth session only | low |
| `user_profiles` | self-read plus same-org / admin pattern | `public.current_user_org_id()` | standard Supabase auth session only | medium |
| `projects` | org-scoped root project access | `public.current_user_org_id()`, future `app.can_access_project()` | standard Supabase auth session only | high |

### Phase B

| table | RLS mode | helper needed | frontend context needed | breaking risk |
| --- | --- | --- | --- | --- |
| `project_evaluations` | project-scoped | `app.can_access_project()` | standard Supabase auth session only | medium |
| `project_costs` | project-scoped | `app.can_access_project()` | standard Supabase auth session only | high |
| `project_cost_items` | project-scoped | `app.can_access_project()` | standard Supabase auth session only | high |
| `project_cast_costs` | project-scoped | `app.can_access_project()` | standard Supabase auth session only | high |
| `project_festival_records` | project-scoped | `app.can_access_project()` | standard Supabase auth session only | medium |
| `project_revenues` | project-scoped | `app.can_access_project()` | standard Supabase auth session only | high |
| `reports` | project-scoped | `app.can_access_project()` | standard Supabase auth session only | medium |
| `plan_projects` | mixed plan/project scoped | `app.can_access_project()`, future `app.can_access_plan()` | standard Supabase auth session only | high |
| `investment_plans` | org-scoped or derived plan scope | future `app.can_access_plan()` | standard Supabase auth session only | medium |
| `plan_kpi_snapshots` | plan-scoped | future `app.can_access_plan()` | standard Supabase auth session only | medium |

### Phase C

| table | RLS mode | helper needed | frontend context needed | breaking risk |
| --- | --- | --- | --- | --- |
| `board_meetings` | admin-only | existing role helper | standard Supabase auth session only | low |
| `board_resolutions` | admin-only | existing role helper | standard Supabase auth session only | low |
| `board_action_items` | admin-only | existing role helper | standard Supabase auth session only | low |
| `roi_models` | admin-only or curated read RPC | existing role helper | standard Supabase auth session only | medium |
| `roi_model_weights` | admin-only | existing role helper | standard Supabase auth session only | low |
| `roi_model_change_logs` | admin-only | existing role helper | standard Supabase auth session only | low |
| `external_import_runs` | admin/system | existing role helper plus org-aware import linkage later | standard Supabase auth session only | medium |
| `external_project_snapshots` | admin/system | existing role helper plus org-aware import linkage later | standard Supabase auth session only | medium |
| `external_budget_snapshots` | admin/system | existing role helper plus org-aware import linkage later | standard Supabase auth session only | medium |
| `external_import_field_mappings` | admin/system | existing role helper plus org-aware import linkage later | standard Supabase auth session only | medium |
| `external_import_audit_logs` | admin/system append-only | existing role helper plus org-aware import linkage later | standard Supabase auth session only | low |
| `festival_events` | public-read-only or curated read RPC | none or existing role helper | possibly none if intentionally public | medium |

## Rollback Plan
Rollback draft exists at:
- [supabase/scripts/20260428_sprint2e_staging_organizations_lockdown_rollback_draft.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2e_staging_organizations_lockdown_rollback_draft.sql)

Rollback would:
1. drop the `organizations_authenticated_select_own_org_v1` policy
2. restore direct `anon` and `authenticated` table privileges
3. disable RLS on `public.organizations`
4. remove `public.current_user_org_id()`

Rollback was **not executed** because staging remained healthy.

## Can We Enter Sprint 2F?
Recommendation: yes.

Sprint 2F should target:
- staged `user_profiles` RLS refinement
- staged `projects` tenant-aware RLS refinement
- helper expansion:
  - `app.can_access_project()`
  - `app.can_access_plan()`
- smoke coverage for analyst / shareholder / super_admin by org

## CTO Go / No-Go
### Go
- for Sprint 2F `user_profiles` / `projects` RLS staging enable planning and controlled rollout
- for continuing tenant-aware hardening on staging

### No-Go
- for production rollout
- for project child-table tenant RLS before `projects` root policy is stabilized
- for assuming frontend custom headers are needed; current plan should continue to rely on Supabase auth session context first
