begin;

create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  org_code text unique,
  org_name text not null,
  org_status text not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.user_profiles
  add column if not exists org_id uuid;

alter table public.projects
  add column if not exists org_id uuid;

comment on column public.user_profiles.org_id is
  'Canonical tenant/org binding for authenticated users. Nullable during staging tenant reconciliation.';

comment on column public.projects.org_id is
  'Canonical tenant/org ownership for project-scoped records. Nullable until manual backfill is approved.';

create schema if not exists app;

create table if not exists app.project_org_backfill_manual_map (
  project_id uuid primary key references public.projects(id) on delete cascade,
  current_org_id uuid,
  proposed_org_id uuid,
  confidence text not null check (
    confidence in (
      'manual_review_required',
      'low',
      'medium',
      'high'
    )
  ),
  reason text not null,
  evidence_json jsonb not null default '{}'::jsonb,
  reviewed_by uuid,
  reviewed_at timestamptz,
  approved_for_backfill boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

insert into app.project_org_backfill_manual_map (
  project_id,
  current_org_id,
  proposed_org_id,
  confidence,
  reason,
  evidence_json
)
select
  p.id,
  null,
  null,
  'manual_review_required',
  'Staging dry run seed. No canonical org mapping is inferred automatically.',
  jsonb_build_object(
    'project_name',
    coalesce(
      nullif(p.project_name_zh, ''),
      nullif(p.project_name_en, ''),
      nullif(p.project_code, ''),
      p.id::text
    ),
    'baseline',
    '2026-04-28',
    'source',
    'sprint2c_staging_dry_run'
  )
from public.projects p
on conflict (project_id) do nothing;

commit;
