# CIRQUA Stabilization Sprint 2H Frontend / API Contract Reconciliation

## Scope
This round is contract reconciliation only.

No migration was applied.
No production system was touched.
No feature was added.
`projects` write access was **not** restored.

This reconciliation compares:
- current GitHub `main` repository contents
- current committed Readdy-facing contract documents
- current staging RLS posture established through Sprint 2E and Sprint 2F
- current committed RPC / helper definitions

## Source Availability
This check is about what is actually present in the current GitHub repo, not what may exist in another private repo or no-code workspace.

| source type | status | evidence | note |
| --- | --- | --- | --- |
| frontend source | missing | repo contains docs and `supabase/` SQL only | no `src/`, `app/`, `pages/`, `components/`, `package.json`, or frontend build structure is present |
| Readdy generated UI source | missing | no generated UI code or design-export code exists in repo | only Readdy-facing contract docs exist |
| API client source | missing | no TS/JS client module, SDK wrapper, or API adapter exists in repo | no executable client-side data layer is committed |
| Supabase client calls in source code | missing | there are markdown examples in docs, but no executable app source files | examples exist in `docs/api/readdy-supabase-query-map-v1.md` and `docs/api/project-evaluation-flow-v1.md` only |
| RPC wrapper source | missing | no dedicated wrapper module for `supabase.rpc(...)` exists | CIRQUA RPCs exist as SQL functions, not as application wrapper code |
| Edge Function source | missing | no `supabase/functions/` directory exists | only contract docs mention possible Edge Functions later |
| Railway backend source | missing | no server application source exists in repo | no Express / Fastify / Nest / worker code is committed |
| staging verification helpers | exists | `/tmp/lumiere-staging-verify/verify_staging.js`, `/tmp/lumiere-staging-verify/verify_via_mgmt_and_rest.js` | useful for validation, but they are not part of the GitHub repo |
| Supabase migrations and SQL RPC implementations | exists | `supabase/migrations/*.sql` | current backend behavior is primarily represented here |
| frontend repo outside this repo | unknown | not inspectable from this repository | may exist elsewhere, but cannot be treated as verified source |

## Contract Drift
The current drift is not one issue. It is a stack of mismatches between docs, staging RLS, and actual repo contents.

### Drift 1: Readdy docs still describe client-side `projects` writes
Committed docs still advertise:
- `supabase.from('projects').insert(payload)`
- `supabase.from('projects').update(payload).eq('id', projectId)`

Evidence:
- [docs/api/readdy-supabase-query-map-v1.md](/private/tmp/Lumi-re_Nexus_remote_inspect/docs/api/readdy-supabase-query-map-v1.md)
- [docs/api/project-evaluation-flow-v1.md](/private/tmp/Lumi-re_Nexus_remote_inspect/docs/api/project-evaluation-flow-v1.md)

But Sprint 2F changed staging to:
- revoke all `anon, authenticated` table privileges on `public.projects`
- grant only `SELECT` to `authenticated`
- enforce tenant-aware `SELECT` policy only

Evidence:
- [supabase/migrations/20260428223000_sprint2f_staging_user_profiles_projects_rls.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428223000_sprint2f_staging_user_profiles_projects_rls.sql)
- [CIRQUA_STABILIZATION_SPRINT2F_CORE_RLS_ENABLE.md](/private/tmp/Lumi-re_Nexus_remote_inspect/CIRQUA_STABILIZATION_SPRINT2F_CORE_RLS_ENABLE.md)

Impact:
- any real frontend still following the documented direct-write contract will fail immediately on staging

### Drift 2: Readdy docs still model `projects` access as role-based, but staging is now org-scoped
Older contract language centers on:
- `project_editor`
- `analyst`
- `report_viewer`
- `super_admin`

Current staging `projects` access is not primarily role-shaped anymore.
It is:
- authenticated caller
- same-org only
- `SELECT` only

Impact:
- role-only documentation is no longer sufficient for frontend integration
- org context and tenant-aware reads are now part of the real contract

### Drift 3: `user_profiles` visibility documented as self-only for most roles, but staging now allows same-org directory reads
Readdy query map says:
- `project_editor`: `user_profiles` self profile only
- `analyst`: `user_profiles` self profile only
- `report_viewer`: `user_profiles` self profile only

Sprint 2F policy actually allows:
- self profile
- active same-org profiles

Impact:
- UI assumptions based on “self-only” are now under-descriptive
- security review assumptions based on “self-only” are inaccurate

### Drift 4: Repo has no frontend / API client source to validate against the contract
The repo contains:
- docs
- SQL migrations
- SQL scripts

It does not contain:
- actual frontend callers
- actual API client implementation
- actual RPC wrapper
- actual backend service code

Impact:
- current Readdy contract cannot be validated against real application code in this repo
- any claim about “frontend compatibility” is document-level only, not source-proven

### Drift 5: No controlled `projects` write entrypoint exists yet
Current repo has:
- CIRQUA RPCs for import workflows
- `current_user_org_id()` helper

Current repo does not have:
- `create_project`
- `update_project`
- `delete_project`
- `app.can_access_project()`

Impact:
- once direct client-side `projects` writes were removed, no replacement write path was committed
- this is now a deliberate contract gap, not just a doc typo

### Drift 6: Readdy contract still assumes base-table usage where future tenant rollout likely needs mediated writes
For example:
- `project_evaluations` are still documented as direct `insert/update`
- Sprint 2G already identified this as the next likely break once project-scoped RLS is enabled

Impact:
- without a helper-backed policy or controlled RPC, the next tenant RLS wave will likely break evaluation drafting too

### Drift 7: Organization context is now backend-derived, not frontend-supplied
Current staging hardening depends on:
- `public.current_user_org_id()`
- active `user_profiles.org_id`
- authenticated Supabase session

The current frontend contract does not clearly require:
- authenticated session before tenant reads
- no manual org header override
- tenant-scoped error handling expectations

Impact:
- frontend contract is missing a now-critical rule: org context comes from auth session and server-side lookup, not client-selected context

## Projects Write Path Decision
This is the formal CTO decision point for `projects.create / update / delete`.

### Option A: authenticated RLS policy direct writes
Security:
- weakest of the viable options
- pushes complex tenant and mutation rules into table policies
- easier to regress into cross-org write exposure

Development cost:
- lowest short-term change if a real frontend already exists

Impact on Readdy:
- smallest UI change if existing screens already call direct table writes

Impact on future production:
- higher long-term audit and policy complexity
- weaker separation between read contract and write contract

### Option B: RPC controlled write
Security:
- stronger than direct table DML
- centralizes org assignment, validation, audit, and guardrails
- keeps `projects` as canonical data without reopening generic table writes

Development cost:
- moderate
- requires new SQL function(s) plus Readdy contract update

Impact on Readdy:
- manageable
- Readdy changes from `from('projects').insert/update` to `rpc(...)`

Impact on future production:
- good path for staged hardening
- easier to layer additional validation, defaults, and audit later

### Option C: service backend / Edge Function write
Security:
- strongest and most extensible
- best for orchestration, enrichment, audit, async jobs, and future integrations

Development cost:
- highest for current phase
- requires backend code that is not currently present in this repo

Impact on Readdy:
- larger contract shift
- frontend must call backend service instead of direct Supabase write

Impact on future production:
- very strong long-term architecture
- but blocked by missing backend repo/source in current workspace

### Option D: temporarily forbid UI writes
Security:
- safest immediate posture

Development cost:
- lowest if the team accepts a frozen editor

Impact on Readdy:
- high product friction
- no project create/edit path available

Impact on future production:
- useful only as a temporary freeze, not a durable operating model

## Single Recommendation
Recommended mode: **B. RPC controlled write**

Why this is the best fit now:
- Sprint 2F intentionally removed direct authenticated `projects` writes
- the repo already uses RPC as the preferred control surface for CIRQUA-sensitive workflows
- there is no committed backend / Edge Function source in this repo, so Option C is strategically strong but not the next executable step
- Option A would reopen risk before the tenant model for child tables is stable
- Option D is acceptable only as a temporary fallback, not as a platform contract

Formal CTO recommendation:
- keep `projects` base table read-only to authenticated clients
- do not restore direct authenticated `insert/update/delete`
- add controlled `projects` create/update RPCs as the next write path
- keep `delete` disabled unless there is a strong business requirement and explicit archive / audit semantics

## Required Frontend Contract
This is the contract Readdy should follow from now on.

### `projects` read
- allowed surface: `public.projects`
- method: direct `select`
- auth requirement: authenticated Supabase session required
- scope: same organization only
- org context source: server-derived from `public.current_user_org_id()` and `user_profiles.org_id`
- frontend must not assume role-only filtering is enough

### `projects` create
- direct `from('projects').insert(...)`: forbidden
- required mode: controlled RPC once provided
- until that RPC exists: treat create as unavailable in staging

### `projects` update
- direct `from('projects').update(...)`: forbidden
- required mode: controlled RPC once provided
- until that RPC exists: treat update as unavailable in staging

### `projects` delete
- direct `from('projects').delete(...)`: forbidden
- delete should remain disabled unless a dedicated archive/delete workflow is explicitly designed

### organization context
- frontend must not send its own org selection as authoritative write scope
- authoritative org context comes from authenticated session plus backend lookup
- if UI shows org information, that is display state only, not permission state

### auth session
- tenant-aware reads now require a valid authenticated Supabase session
- frontend must handle unauthenticated and expired-session states before attempting tenant reads
- `anon` should never be used for core business data reads

### error handling
- treat `401 / 42501` and empty denied result sets as permission outcomes, not generic network failures
- show a clear access-state message:
  - sign-in required
  - no access to this organization
  - write path not available in current staging contract

### RLS error handling
- when direct write to `projects` returns permission error, frontend should not retry with alternate client-side behavior
- frontend should route the error to:
  - disabled edit state
  - “contact admin / backend write path pending” state
  - or future RPC path once implemented

## Sprint 2I Recommendation
### Candidate evaluation
#### 2I-A: add controlled `projects` write RPC
Pros:
- directly resolves the highest-impact current contract gap
- aligns with recommended write model
- enables future tenant-safe editing without reopening raw DML

Cons:
- still does not solve missing frontend repo visibility

#### 2I-B: backfill more business tables first
Pros:
- advances tenant data model

Cons:
- does not resolve the currently broken `projects` write contract
- risks more drift before the root write path is stabilized

#### 2I-C: obtain full frontend repo first
Pros:
- gives better certainty before more contract hardening

Cons:
- does not unblock the data-layer contract decision already needed now

#### 2I-D: production migration planning
Pros:
- none at this stage

Cons:
- clearly premature
- contract and source visibility are still incomplete

## Recommended next step
Recommendation: **2I-A first**, with a follow-on request to obtain the real frontend repo as soon as possible.

Interpretation:
- next executable technical step: add controlled `projects` write RPC
- next visibility step: get the actual frontend / API client repo so later RLS rollout can be source-validated, not doc-inferred

## CTO Go / No-Go
### Go
- for Sprint 2I-A: controlled `projects` write RPC design and implementation
- for updating Readdy contract docs so they stop advertising direct `projects` writes
- for obtaining the real frontend repo before further business-table RLS rollout

### No-Go
- for restoring direct authenticated `projects` DML
- for proceeding to production migration planning
- for enabling more business-table RLS based only on current document assumptions without frontend source verification
