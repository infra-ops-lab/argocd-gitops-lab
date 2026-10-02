# 10 — Projects and RBAC: who may deploy what, where

**Goal:** a `dev` user who can see everything but **sync only team A's apps**, and team A's
apps can only come from team A's repos and land in team A's namespaces.

| Layer | Object | Controls |
|---|---|---|
| **AppProject** | `project-team-a.yaml` | allowed source repos, destination clusters/namespaces, resource kinds |
| **Account** | `argocd-cm` → `accounts.dev: login` | a local user (SSO in real life) |
| **RBAC** | `argocd-rbac-cm` → `policy.csv` | what each role may do on which project's apps |

**Run** (on the ArgoCD cluster)
```bash
kubectl apply -f project-team-a.yaml
kubectl -n argocd patch cm argocd-cm      --type merge --patch-file argocd-cm-patch.yaml
kubectl -n argocd patch cm argocd-rbac-cm --type merge --patch-file argocd-rbac-cm-patch.yaml
argocd account update-password --account dev      # as admin: set dev's password
```
Point an app at the project: `spec.project: team-a`, namespace `team-a-shop`.

**Expect / break it**
- log in as `dev` → sees all apps (`policy.default: role:readonly`), **Sync** works only on
  `team-a` apps; others → `permission denied`
- a `team-a` app with namespace `default` → `application destination ... is not permitted in project`
- a `team-a` app from a repo outside `team-apps/` → `application repo ... is not permitted`

**policy.csv format:** `p, <role>, <resource>, <action>, <project>/<app>, allow|deny` and
`g, <user-or-group>, <role>`.
