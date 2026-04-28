begin;

-- Sprint 2D staging-only assumption:
-- - current staging has zero organizations
-- - current staging has one project with null org_id
-- - current staging has only active unscoped user_profiles
-- - no production tenant inference is being made here
-- - this creates a single staging default tenant strictly for staging validation

insert into public.organizations (
  id,
  org_code,
  org_name,
  org_status
)
values (
  '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid,
  'staging-default-org',
  'Staging Default Organization',
  'active'
)
on conflict (org_code) do update
set
  org_name = excluded.org_name,
  org_status = excluded.org_status,
  updated_at = timezone('utc', now());

update app.project_org_backfill_manual_map
set
  proposed_org_id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid,
  confidence = 'medium',
  reason = 'Staging-only assumption approved for validation: single unscoped project, zero existing organizations, and no competing tenant signals in current staging baseline.',
  reviewed_at = timezone('utc', now()),
  approved_for_backfill = true,
  updated_at = timezone('utc', now())
where project_id in (
  select p.id
  from public.projects p
  where p.org_id is null
);

update public.projects p
set org_id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid
where p.org_id is null
  and exists (
    select 1
    from app.project_org_backfill_manual_map m
    where m.project_id = p.id
      and m.approved_for_backfill = true
      and m.proposed_org_id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid
  );

update public.user_profiles up
set org_id = '8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a'::uuid
where up.org_id is null
  and up.status = 'active';

commit;
