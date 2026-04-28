-- Draft only. Do not execute automatically.
-- Use only if the Sprint 2D staging manual tenant backfill needs to be reverted.

begin;

update public.projects
set org_id = null
where org_id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid;

update public.user_profiles
set org_id = null
where org_id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid;

update app.project_org_backfill_manual_map
set
  current_org_id = null,
  proposed_org_id = null,
  confidence = 'manual_review_required',
  reason = 'Rollback draft executed. Reset to unresolved staging mapping state.',
  reviewed_by = null,
  reviewed_at = null,
  approved_for_backfill = false,
  updated_at = timezone('utc', now())
where proposed_org_id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid
   or project_id in (
     select p.id
     from public.projects p
     where p.org_id is null
   );

delete from public.organizations
where id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid
  and org_code = 'staging-default-org';

commit;
