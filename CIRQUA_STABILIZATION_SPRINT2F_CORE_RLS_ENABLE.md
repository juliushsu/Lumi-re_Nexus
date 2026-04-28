# CIRQUA Stabilization Sprint 2F Core RLS Enable

## Scope
This round enabled minimal tenant-aware RLS for `public.user_profiles` and `public.projects` on **staging only**.

Production was not touched.

Preflight snapshot:
- [CIRQUA_SPRINT2F_PREFLIGHT_SNAPSHOT.md](/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_SPRINT2F_PREFLIGHT_SNAPSHOT.md)

Applied staging migration:
- [supabase/migrations/20260428223000_sprint2f_staging_user_profiles_projects_rls.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428223000_sprint2f_staging_user_profiles_projects_rls.sql)

Rollback draft:
- [supabase/scripts/20260428_sprint2f_staging_user_profiles_projects_rls_rollback_draft.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2f_staging_user_profiles_projects_rls_rollback_draft.sql)

## Migration Summary
The migration did three things:
1. removed prior role-based policies on `user_profiles` and `projects`
2. replaced them with tenant-aware `SELECT` policies based on `current_user_org_id()`
3. reduced `authenticated` table access on `projects` to `SELECT` only

No `NOT NULL` was added.
No production migration was run.
No business child tables were enabled in this round.

## user_profiles RLS Result
Final policy:
- `user_profiles_authenticated_select_same_org_v2`

Behavior:
- authenticated user can read:
  - own profile
  - active profiles in the same org
- authenticated user cannot read cross-org profiles
- `anon` cannot read `user_profiles`
- `service_role` keeps full visibility

## projects RLS Result
Final policy:
- `projects_authenticated_select_same_org_v2`

Behavior:
- authenticated user can read projects in the same org only
- authenticated user cannot read cross-org projects
- `anon` cannot read `projects`
- `service_role` keeps full visibility

Important temporary decision:
- authenticated `projects` `insert/update/delete` access was removed in this round
- this matches the Sprint 2F instruction to avoid opening writes unless required by current smoke

## Verification Scenarios
Temporary verification data created:
- `1` shadow org
- `1` shadow project in shadow org
- `2` temporary analyst users:
  - org A user in default staging org
  - org B user in shadow org

Verified:
- org A user can read org A profiles
- org A user can read org A project
- org A user cannot see org B shadow project
- org B user can read org B shadow project only
- `anon` cannot read `user_profiles`
- `anon` cannot read `projects`
- `service_role` can read all profiles and all projects

Cleanup:
- temporary shadow org removed
- temporary shadow project removed
- temporary verification profiles removed
- temporary auth users removed

Final staging counts after cleanup:
- `organizations_count = 1`
- `projects_count = 1`
- `user_profiles_count = 5`
- `user_profiles_null_org_id = 0`
- `projects_null_org_id = 0`

## Breaking Change Assessment
Read behavior:
- existing read surfaces remained healthy
- `anon -> projects` stayed blocked
- authenticated tenant-scoped reads worked as expected
- `service_role` reads remained healthy

Potential breaking change:
- authenticated write access to `projects` is now blocked
- if any staging UI path still expects direct project edits through client-side authenticated sessions, that path will now fail
- this was intentional for the minimal safe rollout, but should be called out before broader staging user testing

## Rollback Plan
Rollback draft exists at:
- [supabase/scripts/20260428_sprint2f_staging_user_profiles_projects_rls_rollback_draft.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2f_staging_user_profiles_projects_rls_rollback_draft.sql)

Rollback would:
1. drop tenant-aware `user_profiles` / `projects` policies
2. restore prior role-based policies
3. restore authenticated project DML grants

Rollback was **not executed** because staging verification succeeded.

## Can We Enter Sprint 2G?
Recommendation: yes.

Sprint 2G should focus on:
- project-scoped business tables RLS plan
- helper expansion:
  - `app.can_access_project()`
  - `app.can_access_plan()`
- deciding which write paths should remain client-side and which should move to service/RPC entrypoints

## CTO Go / No-Go
### Go
- for Sprint 2G project-scoped business tables RLS planning on staging
- for continued staged tenant hardening

### No-Go
- for production rollout
- for enabling child-table tenant RLS before the project root policy is considered stable
- for assuming project write flows are still safe through authenticated direct table access without explicit re-approval
