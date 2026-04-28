# CIRQUA Stabilization Sprint 2G Business Tables & Write Path Audit

## Scope
This round is a read-focused staging audit only.

No new migration was applied in Sprint 2G.
Production was not touched.

Evidence used for this audit:
- current GitHub `main` schema and migration history
- latest verified staging hardening state from Sprint 2E and Sprint 2F
- Readdy integration contracts under `docs/api/`
- staging verification helpers under `/tmp/lumiere-staging-verify/`

Important limitation:
- this repository does **not** contain the real frontend or backend application source
- therefore, the write-path audit below is based on committed contracts, SQL migrations, and staging helper scripts
- any off-repo UI, Edge Function, or backend service caller remains unverified

## Business Tables Classification
Current staging baseline for this round is the Sprint 2F post-state:
- `organizations` tenant root exists
- `user_profiles.org_id` is backfilled
- `projects.org_id` is backfilled
- tenant-aware `SELECT` RLS is already enabled on `organizations`, `user_profiles`, and `projects`

| category | table | key columns | org_id | project_id | current RLS | suggested RLS mode | backfill need |
| --- | --- | --- | --- | --- | --- | --- | --- |
| org-scoped | `organizations` | `id`, `org_code`, `org_name` | no | no | yes | org-scoped self-org read, service/admin write | no |
| user-scoped | `user_profiles` | `id`, `user_id`, `email`, `role`, `status`, `org_id` | yes | no | yes | user-scoped self read plus same-org directory read | no |
| org-scoped | `projects` | `id`, `project_code`, `status`, `org_id` | yes | no | yes | org-scoped root project access | no |
| project-scoped | `project_evaluations` | `id`, `project_id`, `roi_model_id`, `evaluation_status` | no | yes | yes | project-scoped via `app.can_access_project()` | verify legacy `project_id` completeness |
| project-scoped | `project_costs` | `id`, `project_id`, `cost_type` | no | yes | no | project-scoped via `app.can_access_project()` | verify only |
| project-scoped | `project_cost_items` | `id`, `project_id`, `cost_phase`, `cost_category` | no | yes | no | project-scoped via `app.can_access_project()` | verify only |
| project-scoped | `project_cast_costs` | `id`, `project_id`, `cast_name` | no | yes | no | project-scoped via `app.can_access_project()` | verify only |
| project-scoped | `project_revenues` | `id`, `project_id`, `revenue_type` | no | yes | no | project-scoped via `app.can_access_project()` | verify only |
| project-scoped | `project_festival_records` | `id`, `project_id`, `festival_event_id` | no | yes | no | project-scoped via `app.can_access_project()` | verify only |
| system/admin-only | `project_source_links` | `id`, `project_id`, `source_system`, `consent_status` | no | yes | yes | project-bound but RPC/service-only | no |
| system/admin-only | `external_import_runs` | `id`, `project_source_link_id`, `import_status` | no | no | yes | system/admin-only with project-derived checks later | no |
| system/admin-only | `external_project_snapshots` | `id`, `import_run_id`, `project_source_link_id` | no | no | yes | system/admin-only | no |
| system/admin-only | `external_budget_snapshots` | `id`, `import_run_id`, `project_source_link_id` | no | no | yes | system/admin-only | no |
| system/admin-only | `external_import_field_mappings` | `id`, `import_run_id`, `project_id`, `mapping_status` | no | yes | yes | system/admin-only review workspace | no |
| system/admin-only | `external_import_audit_logs` | `id`, `project_id`, `import_run_id`, `event_type` | no | yes | yes | append-only admin/system | no |
| org-scoped | `investment_plans` | `id`, `plan_code`, `plan_status` | no | no | yes | org-scoped or plan-scoped after tenant linkage | yes, tenant linkage still missing |
| org-scoped | `plan_kpi_snapshots` | `id`, `plan_id`, `snapshot_date` | no | no | no | plan-scoped via future `app.can_access_plan()` | depends on `investment_plans` tenant linkage |
| project-scoped | `plan_projects` | `id`, `plan_id`, `project_id`, `evaluation_id` | no | yes | no | project plus plan scoped junction | verify `plan_id` and `project_id` completeness |
| project-scoped | `reports` | `id`, `plan_id`, `project_id`, `evaluation_id`, `report_status` | no | yes | yes | project-scoped read, service/admin write | verify legacy linkage completeness |
| reference/public-read-only | `roi_models` | `id`, `model_name`, `model_type`, `status` | no | no | yes | authenticated reference read-only | no |
| system/admin-only | `roi_model_weights` | `id`, `model_id`, `factor_name` | no | no | no | admin-only or service-only internal reference | no |
| system/admin-only | `roi_model_change_logs` | `id`, `roi_model_id`, `resolution_id` | no | no | yes | admin-only audit log | no |
| system/admin-only | `board_meetings` | `id`, `meeting_code`, `status` | no | no | yes | admin-only | no |
| system/admin-only | `board_resolutions` | `id`, `meeting_id`, `target_type`, `target_id` | no | no | yes | admin-only | no |
| system/admin-only | `board_action_items` | `id`, `resolution_id`, `action_status` | no | no | yes | admin-only | no |
| reference/public-read-only | `festival_events` | `id`, `festival_code`, `festival_group`, `is_active` | no | no | no | public-read-only or curated authenticated read | no |

## Write Path Audit
### What is actually verifiable
Verifiable in repo:
- SQL migrations and RPC implementations
- Readdy integration contracts
- staging verification helpers

Not verifiable in repo:
- real frontend components
- real API server routes
- real Edge Functions
- any upload / OCR / AI analysis worker that lives outside this repo

### Known write surfaces
| target data | source artifact | inferred UI / API path | role used | would current staging RLS block it? | recommendation |
| --- | --- | --- | --- | --- | --- |
| `projects` | `docs/api/readdy-supabase-query-map-v1.md`, `docs/api/project-evaluation-flow-v1.md` | project editor screens using direct `supabase.from('projects').insert/update/delete` | authenticated `project_editor` | yes for `insert/update/delete` after Sprint 2F | move to RPC or service backend; do not reopen blind client DML |
| `projects` | `/tmp/lumiere-staging-verify/verify_via_mgmt_and_rest.js`, `supabase/scripts/cirqua-import-mvp-smoke-test.sql` | staging verification / smoke inserts | `service_role` or privileged SQL | no | keep as test/admin path only |
| `user_profiles` | `/tmp/lumiere-staging-verify/verify_via_mgmt_and_rest.js`, `verify_staging.js` | auth-admin provisioning + service insert | `service_role` | no | keep profile creation in admin/service path |
| `user_profiles` | `supabase/migrations/20260428101500_sample_role_assignment_staging.sql`, `20260428203000_sprint2d_staging_manual_tenant_backfill.sql` | migration-time role / org assignment | privileged SQL | no | keep out of client path |
| `project_evaluations` | `docs/api/readdy-supabase-query-map-v1.md`, `docs/api/project-evaluation-flow-v1.md` | analyst evaluation draft screens using direct `insert/update` | authenticated `analyst` | not blocked today by tenant RLS because tenant scoping is not enabled yet | before enabling project-scoped RLS, either add helper-backed policy or move writes to RPC |
| CIRQUA link / consent / import run / mapping review / baseline | `docs/api/cirqua-service-rpc-contract-v1.md`, `docs/api/cirqua-rpc-implementation-notes-v1.md` | RPC-driven admin/analyst flows | authenticated `super_admin` or `analyst` depending on function | no for allowed RPCs | keep RPC-only |
| CIRQUA raw snapshot ingest | `supabase/migrations/20260428133000_implement_cirqua_service_only_pipeline.sql` | service-only functions `mark_cirqua_import_snapshot_received`, `propose_cirqua_field_mappings` | `service_role` or privileged admin path | frontend call is blocked by execute grants and role checks | keep service-only |
| `reports` | `docs/api/project-evaluation-flow-v1.md` | read-only report viewer contract | authenticated reads only documented | no write path documented | if future writes are needed, prefer service/API path |
| `investment_plans`, `plan_projects`, `plan_kpi_snapshots` | `docs/api/readdy-supabase-query-map-v1.md` and dashboard RPC docs | reads are documented, writes are not | mostly authenticated read / shareholder RPC | unknown because no committed writer exists | inventory real caller before RLS rollout |
| `project_costs`, `project_cost_items`, `project_cast_costs`, `project_revenues`, `project_festival_records` | no UI code or committed API contract found | unknown | unknown | unknown | treat as undocumented write surfaces until proven otherwise |
| upload / OCR / AI analysis related tables | no current table or code artifact found in repo | unknown | unknown | unknown | complete discovery before any tenant RLS wave touches future AI tables |

### Current audit conclusion
The only clearly documented direct client writes today are:
- `projects`
- `project_evaluations`

Of those two:
- `projects` client writes are already intentionally broken by Sprint 2F
- `project_evaluations` still depends on pre-tenant role-based access and is the next likely breaking point once project-scoped RLS is introduced

Everything else is either:
- already mediated by RPC/service layers
- migration-only / admin-only
- undocumented because the real application code is not in this repo

## Projects Write Strategy
### Current state
After Sprint 2F:
- authenticated users can `SELECT` `projects`
- authenticated direct `insert/update/delete` on `projects` is intentionally removed

This means any staging UI that still follows the earlier Readdy query map for direct `projects` writes will now fail.

### Options considered
#### Option A
Re-open authenticated direct `projects` `insert/update`

Pros:
- fastest way to unbreak a client-side editor

Cons:
- tenant checks become policy-heavy
- easy to regress into cross-org write risk
- weak audit posture

#### Option B
Introduce controlled `projects` RPCs

Pros:
- centralizes org assignment and validation
- easier to audit
- aligns with CIRQUA hardening direction

Cons:
- requires Readdy contract update and backend implementation work

#### Option C
Move project writes to service backend / Edge Function

Pros:
- strongest control over validation, enrichment, and audit
- easiest future place to enforce project assignment and side effects

Cons:
- more backend work than a small RPC

## CTO recommendation
Recommended path: **Option B first, Option C later if orchestration grows**.

Reasoning:
- `projects` is now the tenant root for most business data
- reopening raw client-side DML before child-table RLS is designed would reintroduce avoidable cross-org risk
- a small RPC layer for create/update is the best next compromise between safety and delivery speed

Recommendation detail:
- do **not** restore client-side `delete`
- do **not** restore generic authenticated `insert/update`
- add a narrow create/update RPC once real UI requirements are confirmed
- update Readdy query docs to stop advertising direct `projects` DML

## Sprint 2H Recommended Scope
### First batch that can move next
- `project_evaluations`
  - high-value root child table
  - already has a documented writer
  - should use `app.can_access_project()` before tenant RLS rollout
- `reports`
  - mostly read-oriented in current contracts
  - can likely become project-scoped after linkage completeness check
- `project_festival_records`
  - project-bound and lower write criticality than finance tables

### Tables that should wait
- `project_costs`
- `project_cost_items`
- `project_cast_costs`
- `project_revenues`
- `plan_projects`
- `plan_kpi_snapshots`
- `investment_plans`

Why wait:
- either financial sensitivity is high
- or plan/org linkage is still incomplete
- or no verified writer path exists in repo

### Tables that need data model work first
- `investment_plans`
  - needs tenant linkage before reliable org RLS
- `plan_kpi_snapshots`
  - depends on plan-scoped helper
- `plan_projects`
  - depends on both project and plan access helpers

### Tables that need write-path rewrite first
- `projects`
- `project_evaluations`
- any future upload / OCR / AI analysis tables once discovered

## Risk Register
### P0 current risks
- `projects` direct client write paths are still documented in Readdy contracts, but Sprint 2F intentionally blocks them. Any staging UI still using those calls will fail immediately.
- several project-financial tables remain without tenant RLS:
  - `project_costs`
  - `project_cost_items`
  - `project_cast_costs`
  - `project_revenues`
  - `project_festival_records`
  If broad grants still exist, these remain the most likely cross-org exposure surface in the next phase.

### P1 current risks
- `project_evaluations` is still role-scoped, not tenant-scoped. Once more tenant RLS is enabled, this table becomes the next likely break or leak point unless a project helper or RPC path lands first.
- `investment_plans` and downstream plan tables still lack tenant-root modeling. RLS on those tables should not be rushed before plan ownership is explicit.
- write-path audit coverage is incomplete because the actual application source is not present in this repo.

### P2 current risks
- upload / OCR / AI analysis data paths were requested for audit, but no corresponding current tables or code were found in this repository.
- `festival_events` and `roi_models` still need a final decision between true public read and authenticated curated read.

## CTO Go / No-Go
### Go
- for Sprint 2H planning around `project_evaluations` and selected low-risk project child tables
- for designing `app.can_access_project()`
- for replacing documented direct `projects` writes with RPC or service-backed writes

### No-Go
- for restoring generic authenticated `projects` DML now
- for enabling tenant RLS on project-financial child tables before write callers are known
- for enabling plan-table tenant RLS before `investment_plans` ownership is modeled
- for assuming upload / OCR / AI paths are covered by this repo audit
