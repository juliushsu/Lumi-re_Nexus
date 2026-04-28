# CIRQUA Stabilization Sprint 2D Tenant Backfill

## Scope
This round completed a **staging-only** manual tenant mapping and backfill validation.

Production was not touched.

## Mapping Proposal
Proposal document:
- [CIRQUA_SPRINT2D_MANUAL_TENANT_MAPPING_PROPOSAL.md](/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_SPRINT2D_MANUAL_TENANT_MAPPING_PROPOSAL.md)

Staging-only tenant used for validation:
- `org_id`: `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a`
- `org_code`: `staging-default-org`
- `org_name`: `Staging Default Organization`

Proposal basis:
- `0` existing organizations in staging
- `1` project with `org_id is null`
- `5` active user profiles with `org_id is null`
- `1` unresolved mapping row in `app.project_org_backfill_manual_map`

This was explicitly treated as a **staging-only assumption**, not a production tenant inference.

## Applied Staging Update
Applied to staging:
- [supabase/migrations/20260428203000_sprint2d_staging_manual_tenant_backfill.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428203000_sprint2d_staging_manual_tenant_backfill.sql)

Rollback draft:
- [supabase/scripts/20260428_sprint2d_staging_manual_tenant_backfill_rollback_draft.sql](/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2d_staging_manual_tenant_backfill_rollback_draft.sql)

## Actual Backfill Result
Created / reused staging tenant:
- `public.organizations`: `1` row

Projects:
- `projects.org_id null count`: `0`
- mapped project:
  - `e39feb8d-9bfe-44a8-b83e-7adb33ad0ab8` -> `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a`

User profiles:
- `user_profiles.org_id null count`: `0`
- mapped active profiles: `5`

Mapping table:
- `mapping_rows`: `1`
- `mappings_with_proposed_org_id`: `1`
- `approved_mappings`: `1`
- mapping row now reflects:
  - `proposed_org_id = 8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a`
  - `confidence = medium`
  - `approved_for_backfill = true`
  - `reviewed_at` populated

## Unmapped Data
Still unmapped:
- no current `projects` rows remain unmapped
- no current `user_profiles` rows remain unmapped

Still unresolved conceptually:
- this mapping is valid only as a staging validation assumption
- no claim is made that the same tenant assignment should be used in production

## Verification
Verified after backfill:
- `projects.org_id null count = 0`
- `user_profiles.org_id null count = 0`
- existing project row still readable via `service_role`
- `anon -> projects` still blocked with `401 / 42501`
- `projects` and `user_profiles` RLS state unchanged

Additional permission observation:
- new `organizations` table currently has broad default grants for `anon`, `authenticated`, and `service_role`
- this did not break existing frontend behavior
- but it is a new security hardening item for Sprint 2E

## Data Risk
Low immediate staging risk:
- only `org_id` backfill fields were populated
- no `NOT NULL`
- no tenant FK
- no global RLS enable
- no production mutation

Open risk:
- `organizations` currently lacks lockdown / RLS and is more open than the intended final state
- `reviewed_by` in the mapping row remains `null`, because this run did not impersonate a human reviewer
- the backfill relies on a staging-only single-tenant assumption

## Can We Enter Sprint 2E?
Recommendation: yes, with a narrow scope.

Sprint 2E should focus on:
- `organizations` grants lockdown
- `organizations` RLS / admin-only policy plan
- staged tenant-aware RLS enable plan for project-root and child tables
- preserving current frontend behavior while tightening the new tenant model

Sprint 2E should still avoid:
- production rollout
- automatic tenant inference
- `NOT NULL` / FK enforcement until the production mapping workflow exists

## CTO Go / No-Go
### Go
- for Sprint 2E staged RLS enable planning on staging
- for organizations hardening
- for keeping production untouched until a separate approval round

### No-Go
- for production tenant backfill
- for claiming this staging tenant mapping is production-safe
- for enabling broad tenant RLS before `organizations` itself is locked down
