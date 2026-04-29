# CIRQUA Stabilization Sprint 2I-A Projects Controlled Write RPC

## Scope
This round added controlled `projects` write RPCs on **staging only**.

Production was not touched.
Direct client-side table write was **not** restored.
No UI change was made in this round.

Applied staging migration:
- [supabase/migrations/20260428_sprint2ia_projects_controlled_write_rpc.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/migrations/20260428_sprint2ia_projects_controlled_write_rpc.sql)

Rollback draft:
- [supabase/scripts/20260428_sprint2ia_projects_controlled_write_rpc_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2ia_projects_controlled_write_rpc_rollback_draft.sql)

## RPC Design
Implemented functions:
- `public.create_project_controlled(p_payload jsonb, p_service_org_id uuid default null)`
- `public.update_project_controlled(p_project_id uuid, p_payload jsonb, p_service_org_id uuid default null)`

Design rules enforced:
- authenticated path must use `auth.uid()`
- authenticated org context comes from `public.current_user_org_id()`
- frontend cannot provide `org_id`
- create auto-writes `projects.org_id`
- update only works for same-org projects on authenticated path
- `anon` cannot execute
- `service_role` can execute for controlled admin/service usage

Security model:
- authenticated caller must have role:
  - `super_admin`
  - or `project_editor`
- authenticated caller must have an active `user_profiles.org_id`
- `service_role` path is detected from JWT role context, not from client-supplied payload
- direct `insert/update/delete` grants on `public.projects` remain closed for `authenticated`

Important server-managed fields rejected from payload:
- `id`
- `org_id`
- `created_at`
- `updated_at`

Create requirements:
- required fields:
  - `project_code`
  - `project_name_zh`
  - `project_name_en`
  - `project_type`
  - `genre`
  - `region`
  - `language`
  - `status`

Update behavior:
- partial update supported
- same required identity fields cannot be updated to blank values
- `org_id` cannot be changed through payload
- `updated_at` is server-managed

## Migration Summary
The staging migration added:
1. `app.is_service_role_context()`
2. `public.create_project_controlled(...)`
3. `public.update_project_controlled(...)`
4. execute grants for:
   - `authenticated`
   - `service_role`
5. revoke rules for:
   - `public`
   - `anon`

The migration did **not**:
- change the existing tenant-aware `SELECT` policy on `public.projects`
- reopen direct `insert/update/delete` table access
- add new RLS policies for `projects` writes

The RPCs are `security definer`, so write control lives in the function body rather than in reopened table DML grants.

## Verification Results
Verification was run against staging after applying the migration.

### Passed
- authenticated org A user could create an org A project
- authenticated org A user could update the same org A project
- authenticated org A user could **not** update an org B project
- frontend attempt to pass `org_id` was rejected
- `anon` could not execute the RPC
- `service_role` could create a shadow org project and audit-read the results

### Actual observed responses
Successful create:
- `200`
- response contained:
  - `action = created`
  - server-assigned `org_id`
  - full created project row

Successful same-org update:
- `200`
- response contained:
  - `action = updated`
  - unchanged `org_id`
  - updated `notes`

Cross-org update denied:
- `400`
- code: `P0001`
- message:
  - `Project <uuid> is outside current organization scope`

`org_id` override denied:
- `400`
- code: `P0001`
- message:
  - `Payload field org_id is server-managed and cannot be provided`

`anon` denied:
- `401`
- code: `42501`
- message:
  - `permission denied for function create_project_controlled`

### Test data handling
Temporary validation data was created and then cleaned up:
- `1` shadow org
- `2` temporary auth users
- `2` temporary `user_profiles`
- `2` temporary projects

Cleanup completed successfully.

## Readdy Frontend Contract
Readdy should stop using:
- `supabase.from('projects').insert(...)`
- `supabase.from('projects').update(...)`
- `supabase.from('projects').delete(...)`

### Create project call
Use:

```ts
const { data, error } = await supabase.rpc('create_project_controlled', {
  p_payload: {
    project_code,
    project_name_zh,
    project_name_en,
    project_type,
    genre,
    region,
    language,
    status,
    total_budget,
    marketing_budget,
    projected_revenue,
    notes,
    synopsis
  }
})
```

Do not send:
- `org_id`
- `id`
- `created_at`
- `updated_at`

### Update project call
Use:

```ts
const { data, error } = await supabase.rpc('update_project_controlled', {
  p_project_id: projectId,
  p_payload: {
    project_name_zh,
    project_name_en,
    status,
    total_budget,
    marketing_budget,
    projected_revenue,
    notes,
    synopsis
  }
})
```

Do not send:
- `org_id`
- `id`
- `created_at`
- `updated_at`

### Success response shape
Both RPCs return:

```json
{
  "action": "created or updated",
  "project_id": "uuid",
  "org_id": "uuid",
  "project": {
    "...": "full project row"
  }
}
```

### Error handling contract
Frontend should treat these as expected controlled-write outcomes:

- `401 / 42501`
  - unauthenticated or RPC execution not allowed
- `400 / P0001`
  - org scope violation
  - forbidden payload field such as `org_id`
  - missing org context
  - insufficient role
- table constraint errors such as `23514`
  - invalid business value for existing schema check constraint

Frontend should not:
- retry by writing the base table directly
- try to pass `org_id` from UI state
- silently swallow tenant-scoped write errors as generic save failures

Recommended UI handling:
- permission denied:
  - show access restriction state
- missing org context:
  - require re-login or admin correction
- invalid payload / constraint:
  - surface field validation message

## Rollback Plan
Rollback draft exists at:
- [supabase/scripts/20260428_sprint2ia_projects_controlled_write_rpc_rollback_draft.sql](/private/tmp/Lumi-re_Nexus_remote_inspect/supabase/scripts/20260428_sprint2ia_projects_controlled_write_rpc_rollback_draft.sql)

Rollback would:
1. revoke execute on the controlled write RPCs
2. drop `public.create_project_controlled(...)`
3. drop `public.update_project_controlled(...)`
4. drop `app.is_service_role_context()`

Rollback was **not** executed because staging validation passed.

## Can We Enter Sprint 2I-B?
Recommendation: yes.

Suggested next focus:
- tenant key hardening for project-scoped business tables
- especially:
  - `project_evaluations`
  - `reports`
  - selected child project tables after caller review

But one condition remains important:
- Readdy contract docs should now be updated to prefer the new RPC path before further frontend testing

## CTO Go / No-Go
### Go
- for Sprint 2I-B business tables tenant key hardening
- for replacing documented Readdy `projects` direct writes with RPC calls
- for keeping `projects` base-table write closed to normal authenticated clients

### No-Go
- for restoring direct `projects` DML
- for production rollout yet
- for assuming other business-table write paths are now safe without similar caller reconciliation
