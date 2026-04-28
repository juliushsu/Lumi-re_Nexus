# CIRQUA Sprint 2F Preflight Snapshot

This snapshot captures the staging state immediately before enabling tenant-aware RLS on `public.user_profiles` and `public.projects`.

## organizations
- RLS enabled: `true`
- helper exists: `public.current_user_org_id()`

## organizations Policies
- `organizations_authenticated_select_own_org_v1`

## organizations Grants
| role | select | insert | update | delete |
| --- | --- | --- | --- | --- |
| `anon` | no | no | no | no |
| `authenticated` | yes | no | no | no |
| `service_role` | yes | yes | yes | yes |

## org_id Backfill State
| metric | value |
| --- | ---: |
| `user_profiles_null_org_id` | 0 |
| `projects_null_org_id` | 0 |

## user_profiles Grants Before 2F
| role | select | insert | update | delete |
| --- | --- | --- | --- | --- |
| `anon` | no | no | no | no |
| `authenticated` | yes | no | no | no |
| `service_role` | yes | yes | yes | yes |

## projects Grants Before 2F
| role | select | insert | update | delete |
| --- | --- | --- | --- | --- |
| `anon` | no | no | no | no |
| `authenticated` | yes | yes | yes | yes |
| `service_role` | yes | yes | yes | yes |

## Read Surface Check Before 2F
- `anon -> projects`: blocked with `401 / 42501`
- `service_role -> projects`: readable

## Preflight Conclusion
The staging org model and organizations lockdown were already in place. The remaining gap was that `user_profiles` and `projects` still used role-based policies instead of tenant-aware `SELECT` policies.
