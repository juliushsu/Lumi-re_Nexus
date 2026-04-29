# CIRQUA Stabilization Sprint 2P Project Cast Costs RLS Wave 1B

## Scope
This round applied a single-table Wave 1B RLS rollout to **staging only**.

Target table:
- `public.project_cast_costs`

Production was not touched.
No UI change was made.
No write policy was enabled.

Applied staging migration:
- [supabase/migrations/20260428_sprint2p_project_cast_costs_rls_wave1b.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2p_project_cast_costs_rls_wave1b.sql)

Rollback draft:
- [supabase/scripts/20260428_sprint2p_project_cast_costs_rls_wave1b_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2p_project_cast_costs_rls_wave1b_rollback_draft.sql)

## Preflight Summary
Live staging preflight on `2026-04-29` showed:
- `project_cast_costs` row count: `0`
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
  - `can_access_project()` exists

Preflight interpretation:
- the table was clean enough for a staged single-table rollout
- the main risk was broad direct access, not data integrity

## Migration Result
Migration apply response:
- status: `200`
- migration name:
  - `codex_1777448170717_sprint2p_project_cast_costs_rls_wave1b`

What the migration changed:
1. reused existing `public.can_access_project(project_id uuid)`
2. enabled RLS on `public.project_cast_costs`
3. revoked all table access from `anon`
4. revoked direct DML from `authenticated`
5. granted `SELECT` only to `authenticated`
6. kept `service_role` full table access
7. added one read-only policy:
   - `project_cast_costs_select_same_org_project_v1`

What the migration did not do:
- no new helper creation
- no `INSERT` / `UPDATE` / `DELETE` policy
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
- `2` temporary `project_cast_costs`
  - one per org

### Read isolation results
Org A authenticated user:
- `200`
- saw exactly `1` row
- saw only org A cast cost row

Org B authenticated user:
- `200`
- saw exactly `1` row
- saw only org B cast cost row

Anon:
- `401`
- `42501 permission denied for table project_cast_costs`

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
  - `project_cast_costs_select_same_org_project_v1`
- helpers:
  - `current_user_org_id()` exists
  - `can_access_project()` exists

### Cleanup result
Temporary verification data was cleaned up successfully:
- temporary cast cost rows deleted
- temporary projects deleted
- temporary user profiles deleted
- temporary auth users deleted
- shadow org deleted

Post-cleanup confirmation:
- `project_cast_costs` row count returned to `0`
- `project_id null count = 0`
- `orphan project_id count = 0`
- RLS remains enabled
- helper remains present
- policy remains present

## Breaking Change Assessment
No breaking change was observed for the intended Wave 1B read path:
- same-org authenticated reads worked
- cross-org reads were blocked
- service-role verification access remained intact

Intentional behavior changes:
- `anon` direct read now fails
- `authenticated` direct write now fails because no write grants or policies are present

That means any hidden caller still expecting:
- public read, or
- direct client insert/update/delete on `project_cast_costs`

will now fail on staging.

Given current repo evidence, that is acceptable for this controlled read-only wave because no verified writer path for this table was found.

## Rollback Plan
Rollback draft exists at:
- [supabase/scripts/20260428_sprint2p_project_cast_costs_rls_wave1b_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2p_project_cast_costs_rls_wave1b_rollback_draft.sql)

Rollback would:
1. drop the Wave 1B SELECT policy
2. disable RLS on `project_cast_costs`
3. restore broad table grants to `anon`, `authenticated`, and `service_role`
4. preserve `public.can_access_project(uuid)` because it is now a shared helper

Rollback was not executed because staging verification passed.

## Can This Pattern Be Reused?
Recommendation: yes.

The Phase A Wave pattern now appears reusable across low-blast-radius project-scoped child tables, provided each rollout keeps the same discipline:
1. one table at a time
2. read-only first
3. helper-backed tenant scope
4. temporary same-org / cross-org verification
5. explicit cleanup confirmation

Best next copy candidates:
- `project_cost_items`

More caution needed before:
- `project_costs`
- `project_revenues`

because those carry higher financial sensitivity.

## CTO Go / No-Go
### Go
- for continuing the single-table Phase A pattern on another low-blast-radius table
- for reusing `can_access_project()` as the shared helper
- for keeping direct writes disabled until caller inventory is explicit

### No-Go
- for batching remaining Phase A tables together
- for restoring `anon` read
- for enabling direct authenticated writes on finance-heavy tables before RPC or service-path review
