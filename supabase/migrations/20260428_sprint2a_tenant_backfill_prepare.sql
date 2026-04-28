-- CIRQUA Stabilization Sprint 2A
-- Draft only. Review-first, no destructive writes.
--
-- Sources used for this draft:
-- - Current GitHub main migrations and docs in this repository
-- - Read-only staging schema probe on 2026-04-28
--
-- Important:
-- - The requested Sprint 1 source files were not present in GitHub main at draft time:
--   - CIRQUA_STABILIZATION_SPRINT1_P0_REPORT.md
--   - supabase_sprint1_snapshot.json
--   - sprint1_readonly_audit.sql
-- - This file therefore avoids automatic tenant inference.
-- - As of the staging probe, public.projects does not have an org_id column yet.

select
  'Sprint 2A draft only: tenant backfill is not executable until projects.org_id and user/org linkage are formally introduced.' as draft_notice;

-- ---------------------------------------------------------------------------
-- 1. Current project status snapshot
-- ---------------------------------------------------------------------------
-- This is safe to run now.
select
  p.id as project_id,
  coalesce(
    nullif(p.project_name_zh, ''),
    nullif(p.project_name_en, ''),
    nullif(p.project_code, ''),
    p.id::text
  ) as project_name,
  case
    when exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'projects'
        and c.column_name = 'org_id'
    ) then to_jsonb(p) ->> 'org_id'
    else null
  end as current_org_id,
  case
    when exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'projects'
        and c.column_name = 'org_id'
    ) then 'org_id column present'
    else 'org_id column missing in current staging schema'
  end as org_id_status
from public.projects p
order by p.created_at nulls last, p.updated_at nulls last, p.id;

-- ---------------------------------------------------------------------------
-- 2. Project-linked tables that could help infer tenant ownership
-- ---------------------------------------------------------------------------
-- This is safe to run now.
select
  c.table_name,
  bool_or(c.column_name = 'project_id') as has_project_id,
  bool_or(c.column_name = 'org_id') as has_org_id
from information_schema.columns c
where c.table_schema = 'public'
group by c.table_name
having bool_or(c.column_name = 'project_id')
order by c.table_name;

-- Expected current staging result:
-- - several project-linked tables exist
-- - none currently expose both project_id and org_id
-- Therefore automatic tenant inference is blocked.

-- ---------------------------------------------------------------------------
-- 3. Manual mapping draft shape
-- ---------------------------------------------------------------------------
-- Do not automatically guess production tenant ownership.
-- Use the following structure for human review:
--
-- create schema if not exists app;
--
-- create table if not exists app.project_org_backfill_manual_map_draft (
--   project_id uuid primary key references public.projects(id) on delete cascade,
--   current_org_id uuid,
--   proposed_org_id uuid,
--   confidence text not null check (
--     confidence in (
--       'manual_review_required',
--       'low',
--       'medium',
--       'high'
--     )
--   ),
--   reason text not null,
--   evidence_json jsonb not null default '{}'::jsonb,
--   reviewed_by uuid,
--   reviewed_at timestamptz,
--   approved_for_backfill boolean not null default false,
--   created_at timestamptz not null default timezone('utc', now()),
--   updated_at timestamptz not null default timezone('utc', now())
-- );
--
-- Sample draft population pattern:
-- insert into app.project_org_backfill_manual_map_draft (
--   project_id,
--   current_org_id,
--   proposed_org_id,
--   confidence,
--   reason,
--   evidence_json
-- )
-- select
--   p.id,
--   null,
--   null,
--   'manual_review_required',
--   'projects.org_id column missing in staging schema; no org-bearing project-linked table exists in current public schema',
--   jsonb_build_object(
--     'project_name',
--     coalesce(nullif(p.project_name_zh, ''), nullif(p.project_name_en, ''), nullif(p.project_code, ''), p.id::text),
--     'inference_blocker',
--     'missing_projects_org_id_and_no_project_org_source_table'
--   )
-- from public.projects p
-- on conflict (project_id) do update
-- set
--   reason = excluded.reason,
--   evidence_json = excluded.evidence_json,
--   updated_at = timezone('utc', now());

-- ---------------------------------------------------------------------------
-- 4. Prerequisite tenant columns for Sprint 2B review
-- ---------------------------------------------------------------------------
-- These are intentionally commented out in Sprint 2A.
--
-- alter table public.user_profiles
--   add column if not exists org_id uuid;
--
-- alter table public.projects
--   add column if not exists org_id uuid;
--
-- comment on column public.user_profiles.org_id is
--   'Canonical tenant/org binding for authenticated users.';
--
-- comment on column public.projects.org_id is
--   'Canonical tenant/org ownership for project-scoped records.';

-- ---------------------------------------------------------------------------
-- 5. Current manual mapping draft, based on the staging probe
-- ---------------------------------------------------------------------------
-- This is safe to run now and should currently return unresolved rows only.
select
  p.id as project_id,
  null::uuid as current_org_id,
  null::uuid as proposed_org_id,
  'manual_review_required'::text as confidence,
  'projects.org_id column missing in staging schema; no org-bearing project-linked table exists in current public schema'::text as reason
from public.projects p
order by p.id;
