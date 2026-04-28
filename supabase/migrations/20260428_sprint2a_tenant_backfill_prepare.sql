-- CIRQUA Stabilization Sprint 2A
-- Corrected in Sprint 2B baseline reconciliation.
-- Draft only. Review-first, no production or staging apply in this task.
--
-- Canonical baseline on 2026-04-28:
-- - public.projects exists
-- - public.projects.org_id does not exist
-- - public.user_profiles.org_id does not exist
-- - public.organizations does not exist
-- - no current public table exposes both project_id and org_id
--
-- Therefore this file is NOT a "null org_id backfill" migration.
-- It is a staged tenant-preparation skeleton:
--   1. add tenant key columns
--   2. create manual mapping / backfill review table
--   3. backfill only after human approval
--   4. only then consider NOT NULL, FK, and tenant RLS

select
  'Sprint 2A corrected skeleton: projects.org_id is missing, so tenant hardening must begin with column introduction rather than null backfill.' as draft_notice;

-- ---------------------------------------------------------------------------
-- Phase 0. Current baseline snapshot
-- Safe to run now.
-- ---------------------------------------------------------------------------
select
  p.id as project_id,
  coalesce(
    nullif(p.project_name_zh, ''),
    nullif(p.project_name_en, ''),
    nullif(p.project_code, ''),
    p.id::text
  ) as project_name,
  'org_id missing'::text as org_id_status
from public.projects p
order by p.created_at nulls last, p.updated_at nulls last, p.id;

select
  exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'projects'
      and c.column_name = 'org_id'
  ) as projects_has_org_id,
  exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'user_profiles'
      and c.column_name = 'org_id'
  ) as user_profiles_has_org_id,
  exists (
    select 1
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_name = 'organizations'
  ) as organizations_table_exists;

-- ---------------------------------------------------------------------------
-- Phase 1. Introduce tenant key columns
-- Keep commented until Sprint 2C review.
-- ---------------------------------------------------------------------------
-- create extension if not exists pgcrypto;
--
-- create table if not exists public.organizations (
--   id uuid primary key default gen_random_uuid(),
--   org_code text unique,
--   org_name text not null,
--   org_status text not null default 'active',
--   created_at timestamptz not null default timezone('utc', now()),
--   updated_at timestamptz not null default timezone('utc', now())
-- );
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
-- Phase 2. Manual mapping / backfill review table
-- Keep commented until organization model is approved.
-- ---------------------------------------------------------------------------
-- create schema if not exists app;
--
-- create table if not exists app.project_org_backfill_manual_map (
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
-- insert into app.project_org_backfill_manual_map (
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
--   'No canonical org source exists in current staging baseline. Manual tenant assignment required.',
--   jsonb_build_object(
--     'project_name',
--     coalesce(nullif(p.project_name_zh, ''), nullif(p.project_name_en, ''), nullif(p.project_code, ''), p.id::text),
--     'baseline',
--     '2026-04-28',
--     'blocker',
--     'projects.org_id_missing_and_no_project_org_source_table'
--   )
-- from public.projects p
-- on conflict (project_id) do update
-- set
--   reason = excluded.reason,
--   evidence_json = excluded.evidence_json,
--   updated_at = timezone('utc', now());

-- ---------------------------------------------------------------------------
-- Phase 3. Controlled backfill gate
-- Keep commented. Do not run before manual approval.
-- ---------------------------------------------------------------------------
-- update public.projects p
-- set org_id = m.proposed_org_id
-- from app.project_org_backfill_manual_map m
-- where m.project_id = p.id
--   and m.approved_for_backfill = true
--   and m.proposed_org_id is not null
--   and p.org_id is null;

-- Verification gate after proposed backfill:
-- select
--   count(*) filter (where org_id is null) as remaining_null_org_id_rows,
--   count(*) as total_projects
-- from public.projects;

-- ---------------------------------------------------------------------------
-- Phase 4. Post-backfill integrity hardening
-- Keep commented until every project row has an approved org_id.
-- ---------------------------------------------------------------------------
-- alter table public.user_profiles
--   add constraint user_profiles_org_id_fkey
--   foreign key (org_id) references public.organizations(id);
--
-- alter table public.projects
--   add constraint projects_org_id_fkey
--   foreign key (org_id) references public.organizations(id);
--
-- alter table public.projects
--   alter column org_id set not null;
--
-- alter table public.user_profiles
--   alter column org_id set not null;

-- ---------------------------------------------------------------------------
-- Current unresolved manual mapping draft
-- Safe to run now.
-- ---------------------------------------------------------------------------
select
  p.id as project_id,
  null::uuid as current_org_id,
  null::uuid as proposed_org_id,
  'manual_review_required'::text as confidence,
  'public.projects.org_id does not exist in canonical staging baseline; no automatic tenant inference source is available'::text as reason
from public.projects p
order by p.id;
