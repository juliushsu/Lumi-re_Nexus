# CIRQUA Stabilization Sprint 2N Phase A RLS Apply-Wave

## Scope
This round is a helper and apply-wave draft only.

No migration was applied.
No production system was touched.
No new feature was introduced.

Artifacts produced:
- [supabase/migrations/20260428_sprint2n_phase_a_project_tables_rls_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2n_phase_a_project_tables_rls_draft.sql)
- [supabase/queries/20260428_sprint2n_phase_a_rls_verification.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/queries/20260428_sprint2n_phase_a_rls_verification.sql)

## Helper Design
### `public.current_user_org_id()`
Current state:
- already exists in staging
- should remain the canonical org-context resolver

Required behavior:
- authenticated users resolve org from server-side profile binding
- `service_role` may bypass normal client tenant checks through privileged backend paths
- `anon` must not gain tenant context
- no helper should trust caller-provided `org_id`

### `public.can_access_project(project_id uuid)`
Current state:
- not present in staging yet

Recommended behavior:
- return `true` for `service_role`
- return `false` for `anon`
- for authenticated users:
  - look up `projects.id = project_id`
  - compare `projects.org_id` with `current_user_org_id()`
- no dependency on frontend-passed org context

Use case:
- Phase A SELECT policies
- later project-scoped report / evaluation policies

### `public.can_write_project(project_id uuid)`
Current state:
- not present in staging yet

Recommendation:
- optional helper, not mandatory for Wave 1
- if introduced, it should be stricter than read
- suggested rule:
  - `service_role` passes
  - authenticated user must both:
    - pass `can_access_project(project_id)`
    - hold an active write-capable role such as `super_admin`, `analyst`, or `project_editor`

Why keep it optional:
- current repo does not contain verified write callers for the five Phase A tables
- Wave 1 should stay read-only first

## Phase A Audit
Live staging read-only audit on `2026-04-29` confirms:

### Current table state
All five target tables currently have:
- `RLS enabled = false`
- no existing policies

Target tables:
- `project_costs`
- `project_cost_items`
- `project_cast_costs`
- `project_revenues`
- `project_festival_records`

### Row counts
- `project_costs`: `0`
- `project_cost_items`: `0`
- `project_cast_costs`: `0`
- `project_revenues`: `0`
- `project_festival_records`: `0`

### `project_id` integrity
All five tables currently show:
- `project_id null count = 0`
- `project_id orphan count = 0`

Because row counts are all zero, this means:
- the schema is currently clean for a staged read-only rollout
- but real data edge cases are not yet represented

### Current grants
For every target table, live staging currently shows:
- `anon`: `select/insert/update/delete = true`
- `authenticated`: `select/insert/update/delete = true`
- `service_role`: `select/insert/update/delete = true`

This is the key Phase A risk.

### Existing write paths
Current status from repo evidence:
- no verified frontend or backend source code for these five tables exists in this repo
- Sprint 2G already marked these write paths as undocumented
- therefore current write callers are **not explicit**

Implication:
- do not turn on direct authenticated write policies in Wave 1
- prefer read-only first, then either controlled write or service path later

## Migration Draft Summary
The Phase A draft includes:
1. helper draft for `public.can_access_project(project_id uuid)`
2. optional helper draft for `public.can_write_project(project_id uuid)`
3. SELECT policy skeleton for all five tables
4. commented INSERT / UPDATE / DELETE policy skeleton for all five tables
5. explicit service-role preservation note

The draft intentionally does not:
- enable RLS
- revoke grants in-place
- restore any `anon` path
- enable high-risk write policies

## Apply-Wave Recommendation
### Wave 1 — read-only first
Recommended first-wave table:
- `project_festival_records`

Why this table first:
- lower financial sensitivity than cost or revenue tables
- project-root lineage is straightforward
- likely lowest blast radius if a reader flow breaks

Wave 1 recommendation:

| table | risk | verification method | rollback trigger |
| --- | --- | --- | --- |
| `project_festival_records` | medium | helper existence check, same-org authenticated read, anon denied, service-role read intact | any same-org read regression or unexpected service-role failure |

Optional second Wave 1 candidate after first verification:
- `project_cast_costs`

### Wave 2 — low-risk controlled write
Recommended scope:
- no direct generic table writes yet
- only after caller inventory is explicit

Preferred option:
- introduce controlled RPC/service path for whichever table first proves to need user write

Wave 2 candidates:

| table | risk | verification method | rollback trigger |
| --- | --- | --- | --- |
| `project_cast_costs` | medium | controlled write smoke with same-org project and cross-org denial | any unexpected cross-org write success |
| `project_festival_records` | medium | controlled insert/update smoke if real caller is found | any denial for intended same-org writer or any anon leak |

### Wave 3 — service / RPC required
Recommended tables:
- `project_costs`
- `project_cost_items`
- `project_revenues`

Why Wave 3:
- higher financial sensitivity
- unknown caller inventory
- higher likelihood of needing validation, derived values, or audit

Wave 3 recommendation:

| table | risk | verification method | rollback trigger |
| --- | --- | --- | --- |
| `project_costs` | high | service/API smoke plus same-org/cross-org permission checks | any client-side direct writer discovered unexpectedly |
| `project_cost_items` | high | service/API smoke plus parent-child consistency checks | any write path ambiguity or missing auditability |
| `project_revenues` | high | service/API smoke plus financial data integrity checks | any cross-org visibility or write regression |

## Can We Enter Sprint 2O?
Recommendation: yes.

Sprint 2O should be narrow:
- implement helper function(s)
- choose one Wave 1 table only
- enable read-only RLS on that single table in staging
- verify before touching the rest of Phase A

Best first candidate:
- `project_festival_records`

## CTO Go / No-Go
### Go
- for Sprint 2O Wave 1 staging enable on one low-blast-radius table
- for adding `can_access_project(...)` before broader Phase A rollout
- for keeping write policies commented until caller inventory is explicit

### No-Go
- for enabling all five Phase A tables together
- for enabling direct authenticated writes on cost or revenue tables now
- for production rollout before one-table staging wave is verified end-to-end
