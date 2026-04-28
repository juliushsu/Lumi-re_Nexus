begin;

create schema if not exists app;

create table if not exists public.project_source_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  source_system text not null default 'cirqua',
  external_project_id text not null,
  link_status text not null default 'active',
  consent_status text not null default 'pending',
  consent_scope_json jsonb not null default '{}'::jsonb,
  consent_note text,
  consent_granted_by uuid references public.user_profiles(user_id),
  consent_granted_at timestamptz,
  consent_expires_at timestamptz,
  consent_revoked_by uuid references public.user_profiles(user_id),
  consent_revoked_at timestamptz,
  last_imported_at timestamptz,
  created_by uuid references public.user_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, source_system, external_project_id),
  constraint project_source_links_source_system_check
    check (source_system = 'cirqua'),
  constraint project_source_links_link_status_check
    check (link_status in ('active', 'inactive', 'archived')),
  constraint project_source_links_consent_status_check
    check (consent_status in ('pending', 'granted', 'revoked', 'expired'))
);

create table if not exists public.external_import_runs (
  id uuid primary key default gen_random_uuid(),
  project_source_link_id uuid not null references public.project_source_links(id) on delete cascade,
  source_system text not null default 'cirqua',
  import_status text not null default 'draft',
  snapshot_version text,
  requested_by uuid references public.user_profiles(user_id),
  started_at timestamptz,
  completed_at timestamptz,
  diagnostics_json jsonb not null default '{}'::jsonb,
  failure_reason text,
  approved_by uuid references public.user_profiles(user_id),
  approved_at timestamptz,
  baseline_generated_by uuid references public.user_profiles(user_id),
  baseline_generated_at timestamptz,
  baseline_project_evaluation_id uuid references public.project_evaluations(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint external_import_runs_source_system_check
    check (source_system = 'cirqua'),
  constraint external_import_runs_status_check
    check (
      import_status in (
        'draft',
        'consent_required',
        'ready_to_import',
        'imported',
        'mapping_required',
        'approved',
        'rejected',
        'failed'
      )
    )
);

create table if not exists public.external_project_snapshots (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null references public.external_import_runs(id) on delete cascade,
  project_source_link_id uuid not null references public.project_source_links(id) on delete cascade,
  source_system text not null default 'cirqua',
  snapshot_type text not null default 'project_profile',
  external_payload_json jsonb not null default '{}'::jsonb,
  normalized_payload_json jsonb not null default '{}'::jsonb,
  captured_at timestamptz not null default now(),
  imported_by uuid references public.user_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint external_project_snapshots_source_system_check
    check (source_system = 'cirqua'),
  constraint external_project_snapshots_type_check
    check (snapshot_type = 'project_profile')
);

create table if not exists public.external_budget_snapshots (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null references public.external_import_runs(id) on delete cascade,
  project_source_link_id uuid not null references public.project_source_links(id) on delete cascade,
  source_system text not null default 'cirqua',
  snapshot_type text not null default 'budget_summary',
  currency text,
  budget_total numeric(18,2),
  above_the_line_total numeric(18,2),
  below_the_line_total numeric(18,2),
  contingency_total numeric(18,2),
  normalized_payload_json jsonb not null default '{}'::jsonb,
  captured_at timestamptz not null default now(),
  imported_by uuid references public.user_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint external_budget_snapshots_source_system_check
    check (source_system = 'cirqua'),
  constraint external_budget_snapshots_type_check
    check (snapshot_type = 'budget_summary')
);

create table if not exists public.external_import_field_mappings (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null references public.external_import_runs(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  source_system text not null default 'cirqua',
  snapshot_type text not null,
  source_field text not null,
  target_table text not null,
  target_field text not null,
  proposed_value_json jsonb not null default '{}'::jsonb,
  current_value_json jsonb not null default '{}'::jsonb,
  mapping_status text not null default 'pending_review',
  approval_note text,
  approved_by uuid references public.user_profiles(user_id),
  approved_at timestamptz,
  rejected_by uuid references public.user_profiles(user_id),
  rejected_at timestamptz,
  created_by uuid references public.user_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint external_import_field_mappings_source_system_check
    check (source_system = 'cirqua'),
  constraint external_import_field_mappings_status_check
    check (
      mapping_status in (
        'pending_review',
        'approved',
        'rejected',
        'applied_to_baseline',
        'superseded'
      )
    )
);

create table if not exists public.external_import_audit_logs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.projects(id) on delete cascade,
  project_source_link_id uuid references public.project_source_links(id) on delete cascade,
  import_run_id uuid references public.external_import_runs(id) on delete cascade,
  source_system text not null default 'cirqua',
  event_type text not null,
  actor_user_id uuid references public.user_profiles(user_id),
  event_payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint external_import_audit_logs_source_system_check
    check (source_system = 'cirqua'),
  constraint external_import_audit_logs_event_type_check
    check (
      event_type in (
        'create_import_run',
        'grant_consent',
        'revoke_consent',
        'expire_consent',
        'import_snapshot',
        'approve_mapping',
        'reject_mapping',
        'generate_baseline',
        'mark_failed'
      )
    )
);

create index if not exists idx_project_source_links_project_id
  on public.project_source_links(project_id);

create index if not exists idx_project_source_links_consent_status
  on public.project_source_links(consent_status);

create index if not exists idx_external_import_runs_link_id
  on public.external_import_runs(project_source_link_id);

create index if not exists idx_external_import_runs_status
  on public.external_import_runs(import_status);

create index if not exists idx_external_project_snapshots_import_run_id
  on public.external_project_snapshots(import_run_id);

create index if not exists idx_external_budget_snapshots_import_run_id
  on public.external_budget_snapshots(import_run_id);

create index if not exists idx_external_import_field_mappings_import_run_id
  on public.external_import_field_mappings(import_run_id);

create index if not exists idx_external_import_field_mappings_project_id
  on public.external_import_field_mappings(project_id);

create index if not exists idx_external_import_audit_logs_import_run_id
  on public.external_import_audit_logs(import_run_id);

create index if not exists idx_external_import_audit_logs_project_id
  on public.external_import_audit_logs(project_id);

comment on table public.project_source_links is 'Canonical link from Film Investment Platform projects to external CIRQUA project identities.';
comment on table public.external_import_runs is 'Tracks CIRQUA import attempts and approval state without calling CIRQUA directly in this MVP.';
comment on table public.external_project_snapshots is 'Stores imported project profile snapshots. These records never overwrite canonical projects directly.';
comment on table public.external_budget_snapshots is 'Stores imported budget summary snapshots. These records never overwrite canonical projects directly.';
comment on table public.external_import_field_mappings is 'Human-reviewed CIRQUA-to-platform mapping decisions used before baseline generation.';
comment on table public.external_import_audit_logs is 'Audit log for CIRQUA import lifecycle and approval actions.';

alter table public.project_source_links enable row level security;
alter table public.external_import_runs enable row level security;
alter table public.external_project_snapshots enable row level security;
alter table public.external_budget_snapshots enable row level security;
alter table public.external_import_field_mappings enable row level security;
alter table public.external_import_audit_logs enable row level security;

revoke all on table public.project_source_links from anon, authenticated;
revoke all on table public.external_import_runs from anon, authenticated;
revoke all on table public.external_project_snapshots from anon, authenticated;
revoke all on table public.external_budget_snapshots from anon, authenticated;
revoke all on table public.external_import_field_mappings from anon, authenticated;
revoke all on table public.external_import_audit_logs from anon, authenticated;

grant select, insert, update, delete on table public.project_source_links to authenticated;
grant select, insert, update, delete on table public.external_import_runs to authenticated;
grant select, insert, update, delete on table public.external_project_snapshots to authenticated;
grant select, insert, update, delete on table public.external_budget_snapshots to authenticated;
grant select, insert, update, delete on table public.external_import_field_mappings to authenticated;
grant select, insert on table public.external_import_audit_logs to authenticated;

drop policy if exists "project_source_links_select_admin_analyst_v1" on public.project_source_links;
create policy "project_source_links_select_admin_analyst_v1"
on public.project_source_links
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "project_source_links_manage_super_admin_v1" on public.project_source_links;
create policy "project_source_links_manage_super_admin_v1"
on public.project_source_links
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "external_import_runs_select_admin_analyst_v1" on public.external_import_runs;
create policy "external_import_runs_select_admin_analyst_v1"
on public.external_import_runs
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "external_import_runs_manage_super_admin_v1" on public.external_import_runs;
create policy "external_import_runs_manage_super_admin_v1"
on public.external_import_runs
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "external_project_snapshots_select_admin_analyst_v1" on public.external_project_snapshots;
create policy "external_project_snapshots_select_admin_analyst_v1"
on public.external_project_snapshots
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "external_project_snapshots_manage_super_admin_v1" on public.external_project_snapshots;
create policy "external_project_snapshots_manage_super_admin_v1"
on public.external_project_snapshots
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "external_budget_snapshots_select_admin_analyst_v1" on public.external_budget_snapshots;
create policy "external_budget_snapshots_select_admin_analyst_v1"
on public.external_budget_snapshots
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "external_budget_snapshots_manage_super_admin_v1" on public.external_budget_snapshots;
create policy "external_budget_snapshots_manage_super_admin_v1"
on public.external_budget_snapshots
for all
to authenticated
using (app.has_role('super_admin'))
with check (app.has_role('super_admin'));

drop policy if exists "external_import_field_mappings_select_admin_analyst_v1" on public.external_import_field_mappings;
create policy "external_import_field_mappings_select_admin_analyst_v1"
on public.external_import_field_mappings
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "external_import_field_mappings_insert_admin_analyst_v1" on public.external_import_field_mappings;
create policy "external_import_field_mappings_insert_admin_analyst_v1"
on public.external_import_field_mappings
for insert
to authenticated
with check (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "external_import_field_mappings_update_admin_analyst_v1" on public.external_import_field_mappings;
create policy "external_import_field_mappings_update_admin_analyst_v1"
on public.external_import_field_mappings
for update
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
)
with check (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "external_import_field_mappings_delete_super_admin_v1" on public.external_import_field_mappings;
create policy "external_import_field_mappings_delete_super_admin_v1"
on public.external_import_field_mappings
for delete
to authenticated
using (app.has_role('super_admin'));

drop policy if exists "external_import_audit_logs_select_admin_analyst_v1" on public.external_import_audit_logs;
create policy "external_import_audit_logs_select_admin_analyst_v1"
on public.external_import_audit_logs
for select
to authenticated
using (
  app.has_any_role(array['super_admin', 'analyst'])
);

drop policy if exists "external_import_audit_logs_insert_admin_analyst_v1" on public.external_import_audit_logs;
create policy "external_import_audit_logs_insert_admin_analyst_v1"
on public.external_import_audit_logs
for insert
to authenticated
with check (
  app.has_any_role(array['super_admin', 'analyst'])
);

commit;
