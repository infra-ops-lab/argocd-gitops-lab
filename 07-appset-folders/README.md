# 03 — ApplicationSet over folders: one folder = one app

**Goal:** stop writing an Application per app. One ApplicationSet watches `apps/*` in one repo
and creates an app for every folder.

```
gitops-apps/                         (one git repo)
├── argocd/appset.yaml               ← applied to ArgoCD ONCE
└── apps/
    ├── whoami/   deployment.yaml, service.yaml    → app "whoami", namespace "whoami"
    └── <next>/   ...                              → app "<next>"  (just add the folder)
```

```
appset.yaml  =  generator (git directories: apps/*)   →  finds: whoami, <next>, ...
             +  template  (an Application with {{.path.basename}} filled in)
             →  one Application per folder, same sync policy for all
```

**Run**
1. Create repo `gitops-apps`, push the content of [`gitops-apps/`](gitops-apps/).
2. Set `repoURL` (twice) and `destination.name` in `argocd/appset.yaml`, then on the ArgoCD
   cluster: `kubectl apply -f argocd/appset.yaml`

**Expect:** app `whoami` appears by itself → Synced · Healthy; `curl <node>:30091` →
`Hostname: whoami-...`

**Break it**
- copy `apps/whoami` → `apps/whoami2` (change names, labels, nodePort 30092), push → a second
  app appears, ArgoCD untouched
- delete the folder, push → app and its resources are removed
- `kubectl delete application whoami` → recreated by the ApplicationSet (it owns the apps)

> Docker Hub image — nodes without internet need it mirrored into your registry.
