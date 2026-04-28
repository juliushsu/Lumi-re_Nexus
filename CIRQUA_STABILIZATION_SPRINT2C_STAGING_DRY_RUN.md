# CIRQUA Stabilization Sprint 2C Staging Dry Run

## Scope
This round applied a tenant-preparation migration to **staging only**.

Production was not touched.

## Applied Migration
Applied to staging:
- [supabase/migrations/20260428193000_sprint2c_staging_tenant_schema_prep.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428193000_sprint2c_staging_tenant_schema_prep.sql)

Rollback draft prepared but **not executed**:
- [supabase/scripts/20260428_sprint2c_staging_tenant_schema_rollback_draft.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2c_staging_tenant_schema_rollback_draft.sql)

## Preflight Summary
Preflight snapshot:
- [CIRQUA_SPRINT2C_PREFLIGHT_SNAPSHOT.md](/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_SPRINT2C_PREFLIGHT_SNAPSHOT.md)

Starting state before apply:
- `public.organizations`: absent
- `public.projects.org_id`: absent
- `public.user_profiles.org_id`: absent
- `app.project_org_backfill_manual_map`: absent
- `projects` rows: `1`
- `user_profiles` rows: `5`
- `auth.users` rows: `7`

## Post-Migration Summary
Verified after staging apply:
- `public.organizations`: created
- `public.projects.org_id`: created as nullable `uuid`
- `public.user_profiles.org_id`: created as nullable `uuid`
- `app.project_org_backfill_manual_map`: created

Post-migration data state:
- `organizations` rows: `0`
- `projects` rows: `1`
- `projects` with non-null `org_id`: `0`
- `user_profiles` rows: `5`
- `user_profiles` with non-null `org_id`: `0`
- `app.project_org_backfill_manual_map` rows: `1`
- `app.project_org_backfill_manual_map` rows with `proposed_org_id`: `0`
- `app.project_org_backfill_manual_map` approved rows: `0`

Known project after apply:
- `e39feb8d-9bfe-44a8-b83e-7adb33ad0ab8` / `API 驗證專案` / `org_id = null`

## Data Mutation Assessment
Changes introduced:
- new table `public.organizations`
- new nullable column `public.projects.org_id`
- new nullable column `public.user_profiles.org_id`
- new table `app.project_org_backfill_manual_map`
- `1` staging draft mapping row inserted for the existing project

No changes introduced:
- no `NOT NULL` constraint added
- no tenant FK added
- no new RLS enabled
- no broad grant changes
- no project or profile row was backfilled with org ownership
- no production change

## Frontend Safety Verification
Immediate read-surface verification after apply:
- `anon -> projects` still blocked:
  - `401`
  - `42501 permission denied for table projects`
- `service_role -> projects` still readable:
  - `200`
  - existing project row still available

Additional compatibility conclusion:
- the migration did not alter existing RLS state
- the migration did not alter existing grants
- the migration did not remove or rename existing RPCs / functions

This indicates the frontend’s necessary reads were not immediately interrupted by the staging dry run.

## Errors
Migration SQL errors:
- none

Policy / grant errors introduced by the migration:
- none observed

Tooling note:
- the first combined dry-run collector returned incomplete read-only arrays for some management API queries
- this was corrected by re-running the trusted post-migration probe and separate count verification
- the staging migration itself still applied successfully with `200`

## Rollback Plan
Rollback SQL draft exists at:
- [supabase/scripts/20260428_sprint2c_staging_tenant_schema_rollback_draft.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2c_staging_tenant_schema_rollback_draft.sql)

Rollback would:
1. drop `app.project_org_backfill_manual_map`
2. drop `public.projects.org_id`
3. drop `public.user_profiles.org_id`
4. drop `public.organizations`

Rollback was **not executed** because the staging migration did not block the environment.

## Can We Enter Sprint 2D?
Recommendation: yes.

Sprint 2D can proceed for:
- manual tenant mapping
- review of `app.project_org_backfill_manual_map`
- controlled backfill planning

Sprint 2D should still avoid:
- automatic tenant inference
- `NOT NULL` on `projects.org_id` / `user_profiles.org_id`
- FK enforcement before mapping approval
- production migration

## CTO Go / No-Go
### Go
- for Sprint 2D manual tenant mapping / backfill preparation on staging
- for continued staging-only verification

### No-Go
- for production tenant migration
- for automatic backfill
- for tenant RLS rollout across project-financial tables before org mapping is approved
