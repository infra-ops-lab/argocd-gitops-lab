# 04 — ApplicationSet over repos: one repo = one app

**Goal:** every repo in a git **organization** that has a `k8s/` folder becomes an app —
create the repo, push, done.

```
git server
└── org team-apps                       ← ArgoCD scans this org
    ├── shop/  k8s/deployment.yaml, service.yaml   → app "shop"
    ├── cart/  k8s/...                             → app "cart"   (just create the repo)
    └── docs/  (no k8s/)                           → ignored by the filter

argocd/appset-repos.yaml                ← applied to ArgoCD ONCE
  generator: scmProvider (gitea, owner team-apps, filter pathsExist: [k8s])
  template:  Application named {{.repository}}, path k8s
```

**Run**
1. Create a **public organization** `team-apps` (the Gitea scanner lists *org* repos only —
   a user account returns 404).
2. Create repo `team-apps/shop`, push [`shop/`](shop/) (set `image:`).
3. Set `api`, `repoURL` and `destination.name` in `argocd/appset-repos.yaml`;
   `kubectl apply -f argocd/appset-repos.yaml`

**Expect:** app `shop` → Synced · Healthy; `curl <node>:30093` → `hello-web v1`.

**New repos are found on a scan — every 30 min by default.** Faster:
- `requeueAfterSeconds: 60` under `scmProvider:` (each scan = API calls per repo — mind rate limits)
- or nudge once: `kubectl -n argocd annotate applicationset team-apps-repos argocd.argoproj.io/application-set-refresh=true --overwrite`

Only *discovering* a new repo waits for the scan. Changes inside an existing app sync like
any app (~3 min, instant with a webhook).

**Why `repoURL` is built by hand:** the scanner's `{{.url}}` is the repo's **SSH** clone URL.
With no SSH domain/key set up it points at `git@git.example.com:...` and sync fails.
