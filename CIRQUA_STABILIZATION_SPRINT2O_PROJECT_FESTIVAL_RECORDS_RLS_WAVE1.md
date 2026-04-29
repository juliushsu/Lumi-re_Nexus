# CIRQUA Stabilization Sprint 2O Project Festival Records RLS Wave 1

## Scope
This round applied a single-table Wave 1 RLS rollout to **staging only**.

Target table:
- `public.project_festival_records`

Production was not touched.
No UI change was made.
No write policy was enabled.

Applied staging migration:
- [supabase/migrations/20260428_sprint2o_project_festival_records_rls_wave1.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2o_project_festival_records_rls_wave1.sql)

Rollback draft:
- [supabase/scripts/20260428_sprint2o_project_festival_records_rls_wave1_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2o_project_festival_records_rls_wave1_rollback_draft.sql)

## Preflight Summary
Live staging preflight on `2026-04-29` showed:
- `project_festival_records` row count: `0`
- `project_id null count`: `0`
- `orphan project_id count`: `0`
- current grants before apply:
  - `anon`: full DML
  - `authenticated`: full DML
  - `service_role`: full DML
- current RLS state before apply:
  - `rls_enabled = false`
- current policies before apply:
  - none
- helper status before apply:
  - `current_user_org_id()` exists
  - `can_access_project()` does not exist

Preflight interpretation:
- the table was a clean single-wave candidate because it had no live rows
- but it was also a real exposure surface because `anon` and `authenticated` still had broad DML

## Migration Result
Migration apply response:
- status: `200`
- migration name:
  - `codex_1777447590622_sprint2o_project_festival_records_rls_wave1`

What the migration changed:
1. created `public.can_access_project(project_id uuid)`
2. enabled RLS on `public.project_festival_records`
3. revoked all table access from `anon`
4. revoked direct DML from `authenticated`
5. granted `SELECT` only to `authenticated`
6. kept `service_role` full table access
7. added one read-only policy:
   - `project_festival_records_select_same_org_project_v1`

What the migration did not do:
- no `INSERT` / `UPDATE` / `DELETE` policy
- no `FORCE RLS`
- no tenant write helper enforcement
- no production change

## Verification Results
Because the table had `0` rows, temporary staging test data was created:
- `1` shadow org
- `2` temporary projects
  - one in org A
  - one in org B
- `2` temporary auth users
  - one bound to org A
  - one bound to org B
- `2` temporary `project_festival_records`
  - one per org

### Read isolation results
Org A authenticated user:
- `200`
- saw exactly `1` row
- saw only org A project record

Org B authenticated user:
- `200`
- saw exactly `1` row
- saw only org B project record

Anon:
- `401`
- `42501 permission denied for table project_festival_records`

Service role:
- `200`
- saw both rows

### Post-migration state
Immediately after apply and before cleanup:
- row count: `2`
- `project_id null count`: `0`
- `orphan project_id count`: `0`
- grants:
  - `anon`: no access
  - `authenticated`: `SELECT` only
  - `service_role`: full DML
- RLS:
  - `enabled = true`
- policies:
  - `project_festival_records_select_same_org_project_v1`
- helpers:
  - `current_user_org_id()` exists
  - `can_access_project()` exists

### Cleanup result
Temporary verification data was cleaned up successfully:
- temporary festival records deleted
- temporary projects deleted
- temporary user profiles deleted
- temporary auth users deleted
- shadow org deleted

Post-cleanup confirmation:
- `project_festival_records` row count returned to `0`
- `project_id null count = 0`
- `orphan project_id count = 0`
- RLS remains enabled
- helper remains present
- policy remains present

## Breaking Change Assessment
No breaking change was observed for the intended Wave 1 read path:
- same-org authenticated reads worked
- cross-org reads were blocked
- service-role verification access remained intact

However, there is an intentional behavior change:
- `anon` direct read now fails
- `authenticated` direct write now fails because no write grants or policies are present

That means any hidden caller that still expects:
- public read, or
- direct client insert/update/delete on `project_festival_records`

will now break on staging.

Given the repo evidence, that is acceptable for this controlled Wave 1 because no verified writer path for this table was found.

## Rollback Plan
Rollback draft exists at:
- [supabase/scripts/20260428_sprint2o_project_festival_records_rls_wave1_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2o_project_festival_records_rls_wave1_rollback_draft.sql)

Rollback would:
1. drop the Wave 1 SELECT policy
2. disable RLS on `project_festival_records`
3. restore broad table grants to `anon`, `authenticated`, and `service_role`
4. drop `public.can_access_project(uuid)`

Rollback was not executed because staging verification passed.

## Can This Pattern Be Reused?
Recommendation: yes, with the same narrow discipline.

This Wave 1 pattern is reusable for:
- `project_cast_costs`
- later selected Phase A read-only tables

But only if each table gets:
1. fresh preflight snapshot
2. helper compatibility check
3. one-table staging rollout
4. explicit same-org / cross-org / anon / service-role verification

Do not copy this pattern directly yet to:
- `project_costs`
- `project_cost_items`
- `project_revenues`

Those are higher financial sensitivity and should likely move through RPC or service-backed write design first.

## Can We Enter Sprint 2P?
Recommendation: yes.

Suggested next scope:
- reuse `can_access_project()` for one more low-blast-radius Phase A read-only table
- or design `can_write_project()` only if a real caller needs controlled write

Best next candidate:
- `project_cast_costs`

## CTO Go / No-Go
### Go
- for Sprint 2P on one more read-only Phase A table
- for reusing `can_access_project()` as the common project-scope helper
- for keeping direct writes disabled until caller inventory is explicit

### No-Go
- for enabling all remaining Phase A tables in one batch
- for restoring `anon` read
- for opening direct authenticated writes on finance-heavy tables before RPC or service-path review
