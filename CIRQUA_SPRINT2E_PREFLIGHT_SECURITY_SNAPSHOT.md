# CIRQUA Sprint 2E Preflight Security Snapshot

This snapshot captures the staging state immediately before the organizations lockdown migration.

## organizations Preflight
- RLS enabled: `false`
- RLS forced: `false`
- policies: none

## organizations Grants Preflight
| role | select | insert | update | delete |
| --- | --- | --- | --- | --- |
| `anon` | yes | yes | yes | yes |
| `authenticated` | yes | yes | yes | yes |
| `service_role` | yes | yes | yes | yes |

## organizations Rows Preflight
| id | org_code | org_name | org_status |
| --- | --- | --- | --- |
| `8c1f3e4d-c2ee-4b7c-a0b9-7ec6e63f8d7a` | `staging-default-org` | `Staging Default Organization` | `active` |

## organizations Visibility Risk
- `anon` had direct visibility due open table grants and no RLS
- `authenticated` had direct visibility to all org rows due open table grants and no RLS
- `service_role` had full visibility and management access

## Backfill State Preflight
| metric | value |
| --- | ---: |
| `projects_null_org_id` | 0 |
| `projects_with_org_id` | 1 |
| `user_profiles_null_org_id` | 0 |
| `user_profiles_with_org_id` | 5 |

## Preflight Conclusion
The Sprint 2D backfill had already succeeded, but `public.organizations` was still fully exposed and unprotected. This was the Sprint 2E blocker.
