# CIRQUA Sprint 2D Manual Tenant Mapping Proposal

## Decision Basis
This proposal is for **staging only**.

Observed current state before backfill:
- `public.organizations`: `0` rows
- `public.projects` with `org_id is null`: `1`
- `public.user_profiles` with `org_id is null`: `5`
- `app.project_org_backfill_manual_map`: `1` unresolved row

Because staging currently has:
- no existing organizations
- a single project requiring ownership
- only active, unscoped user profiles

the proposal below uses a **staging-only assumption**:
- create one staging default tenant
- attach the single project to that tenant
- attach current active user profiles to that same tenant for staging validation only

This is **not** a production tenant inference.

## Proposed Staging Tenant
- `proposed_org_id`: `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a`
- `proposed_org_name`: `Staging Default Organization`
- `org_code`: `staging-default-org`

## Project Mapping Proposal

| project_id | project_name | current_org_id | proposed_org_id | proposed_org_name | confidence | reason | requires_human_approval |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `e39feb8d-9bfe-44a8-b83e-7adb33ad0ab8` | `API 驗證專案` | `null` | `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a` | `Staging Default Organization` | `medium` | `Staging-only assumption: single unscoped project, zero existing organizations, and no competing tenant signals in current staging baseline.` | `yes` |

## User Profile Mapping Proposal

| user_id | role | current_org_id | proposed_org_id | proposed_org_name | confidence | reason | requires_human_approval |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `74a7098b-a2e4-4b85-9b80-5a4261107966` | `super_admin` | `null` | `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a` | `Staging Default Organization` | `medium` | `Staging-only assumption: active profile in a single-tenant staging environment with no existing org model.` | `yes` |
| `3ff9bf5f-0f3a-42eb-b4dc-66b3c53fa831` | `shareholder_viewer` | `null` | `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a` | `Staging Default Organization` | `medium` | `Staging-only assumption: active profile in a single-tenant staging environment with no existing org model.` | `yes` |
| `1253b378-9126-4fe3-803f-1a47d9d35e97` | `super_admin` | `null` | `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a` | `Staging Default Organization` | `medium` | `Staging-only assumption: active profile in a single-tenant staging environment with no existing org model.` | `yes` |
| `d9136947-ce04-42c5-af64-cf1008799901` | `analyst` | `null` | `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a` | `Staging Default Organization` | `medium` | `Staging-only assumption: active profile in a single-tenant staging environment with no existing org model.` | `yes` |
| `eff78e7a-68fe-44fe-a1d3-b5a75b190865` | `shareholder_viewer` | `null` | `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a` | `Staging Default Organization` | `medium` | `Staging-only assumption: active profile in a single-tenant staging environment with no existing org model.` | `yes` |

## Proposal Limits
- no `NOT NULL`
- no FK enforcement
- no full-table RLS rollout
- no production implication
- no claim that this tenant mapping is valid outside staging
