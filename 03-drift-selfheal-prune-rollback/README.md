# 03 — Drift, self-heal, prune, rollback

**Goal:** see the reconcile loop work. Uses the `hello-web` app from [02](../02-first-app/);
`kubectl` commands run against the **target** cluster.

| # | Do | Expect | Feature |
|---|---|---|---|
| 1 | `replicas: 1` → `3` in git, push, **Refresh** | 3 pods | deploy from git |
| 2 | `kubectl -n hello-web scale deploy hello-web --replicas=1` | OutOfSync for seconds → back to 3 | **self-heal** |
| 3 | `kubectl -n hello-web set image deploy/hello-web web=nginx:alpine` | reverted to the git image | self-heal |
| 4 | `kubectl -n hello-web delete svc hello-web` | recreated | self-heal |
| 5 | in `app.yaml` set `selfHeal: false`, apply; repeat step 2 | stays **OutOfSync**; **App Diff** shows `replicas: 1 → 3`; **Sync** fixes it | **drift detection** |
| 6 | `git rm k8s/service.yaml`, push | Service deleted from the cluster | **prune** |
| 7 | `git revert HEAD`, push | Service back | **rollback** = git revert |
| 8 | UI → **History and Rollback** | every synced commit listed | history |

Set `selfHeal: true` again when done.

**Rollback, two ways**
- `git revert` → git and cluster stay equal. **Use this.**
- UI/CLI rollback (`argocd app rollback <app> <id>`) → needs auto-sync off; git still says the
  new version, so the next sync undoes it. Emergency use only.
