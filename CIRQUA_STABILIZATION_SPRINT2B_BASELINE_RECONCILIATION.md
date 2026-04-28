# CIRQUA Stabilization Sprint 2B Baseline Reconciliation

## Scope
This round reconciles mismatches between:
- the missing Sprint 1 references
- GitHub `main`
- the Sprint 2A draft
- the current staging Supabase read-only probe

No migration was applied in this task.

## Source Reconciliation
### Files present locally but not in GitHub main
- None of the requested Sprint 1 source artifacts were found in the local workspace or the GitHub clone:
  - `CIRQUA_STABILIZATION_SPRINT1_P0_REPORT.md`
  - `supabase_sprint1_snapshot.json`
  - `sprint1_readonly_audit.sql`

Operational local-only probe files do exist under `/private/tmp`, but they are tooling artifacts, not repository baseline documents.

### Sprint 1 style conclusions that are overturned by the Sprint 2A / 2B probe
- `projects.org_id = null` as the current tenant issue:
  - overturned
  - canonical staging fact is that `public.projects.org_id` does not exist
- `profiles` is a current verified table exposure:
  - overturned
  - canonical staging fact is that `public.profiles` does not exist
- `get_org_usage` is a current verified exposed function:
  - overturned
  - canonical staging fact is that `public.get_org_usage` does not exist

### Historical risks
These may have existed in an earlier environment or report, but were not verified in the current staging baseline:
- `public.profiles` exposure
- `public.get_org_usage` exposure
- any finding that assumes tenant keys already exist on `projects`

### Current staging actual risks
- `public.projects` has no `org_id`
- `public.user_profiles` has no `org_id`
- `public.organizations` does not exist
- no current public table exposes both `project_id` and `org_id`
- several project-financial tables have direct `anon` privileges and no RLS:
  - `plan_kpi_snapshots`
  - `plan_projects`
  - `project_cast_costs`
  - `project_cost_items`
  - `project_costs`
  - `project_festival_records`
  - `project_revenues`
- `festival_events` is still fully open to `anon`
- broad `authenticated` table grants still exist on many tables, while only part of the schema is actually RLS-protected

## Canonical Baseline Summary
Canonical baseline document:
- [CIRQUA_CANONICAL_BASELINE_20260428.md](/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_CANONICAL_BASELINE_20260428.md)

Headline facts:
- `organizations` table: absent
- `projects` table: present
- `projects.org_id`: absent
- `profiles` table: absent
- `get_org_usage`: absent
- current known project rows: `1`
- tenant RLS cannot be validated meaningfully yet because the project root has no tenant key

## Migration Draft Corrections
Updated draft files:
- [20260428_sprint2a_tenant_backfill_prepare.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2a_tenant_backfill_prepare.sql)
- [20260428_sprint2a_rls_policy_skeleton.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2a_rls_policy_skeleton.sql)
- [20260428_sprint2a_grants_lockdown.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2a_grants_lockdown.sql)
- [20260428_sprint2a_verification_queries.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2a_verification_queries.sql)

Key correction:
- the tenant draft is no longer framed as a null backfill
- it is now explicitly staged as:
  1. add `public.organizations`
  2. add `user_profiles.org_id`
  3. add `projects.org_id`
  4. create manual mapping / backfill review table
  5. backfill only after human approval
  6. only then consider FK, `NOT NULL`, and tenant RLS

## Updated Risk Register
### P0 current risks
- `public.projects` has no tenant key
- `public.user_profiles` has no tenant key
- there is no canonical `organizations` table
- no verified automatic project-to-org inference path exists
- several sensitive project-financial tables still have no RLS while retaining broad privileges

### P1 current risks
- `festival_events` is completely open and may not need full write privileges for `anon`
- `authenticated` still has broad grants beyond the already RLS-protected subset
- tenant parent/child consistency between plans and projects is not yet modeled
- there is no immutable tenant backfill audit workflow yet

### Historical risks
- `profiles` direct exposure
- `get_org_usage` execution exposure
- any prior conclusion assuming `projects.org_id` already existed

### Unknown / cannot verify
- the original Sprint 1 claims because the referenced files are absent
- whether prior environments had a different schema than current staging
- whether any non-public schemas already hold an org model

## Should We Enter Sprint 2C?
Recommendation: yes, but only as a schema-introduction round.

Sprint 2C should be limited to:
- introducing `organizations`
- adding `user_profiles.org_id`
- adding `projects.org_id`
- creating the manual backfill review table
- adding verification queries

Sprint 2C should not yet do:
- production backfill
- `NOT NULL` on tenant keys
- final tenant FK enforcement
- broad RLS rollout across project-financial tables

## Production Migration Policy
Production migration remains prohibited at this stage.

Reason:
- the canonical baseline still shows missing tenant root columns
- there is no approved source-of-truth mapping for project ownership
- several historical claims remain unverified because Sprint 1 source artifacts are missing

## CTO Go / No-Go
### Go
- for Sprint 2C schema preparation only
- for adding tenant primitives and review workflow tables
- for continuing staged read-only verification

### No-Go
- for production tenant migration
- for automatic org backfill
- for project-root `NOT NULL` / FK enforcement
- for claiming historical risks remain present without revalidation
