# 06 — Sync hooks and waves: run things around a deploy

**Goal:** a job **before** the deploy (DB migration) and a test **after** it (smoke test);
control the order resources are applied in.

```
sync starts
  PreSync   → Job db-migrate        must succeed, else the sync stops — nothing deployed
  Sync      → wave -1: ConfigMap → wave 0: Deployment, Service   (lower wave first, each waits for Healthy)
  PostSync  → Job smoke-test        runs once everything is Healthy; fails → sync marked Failed
```

**Run:** copy the three files from `k8s/` into the `k8s/` folder of your deploy repo
(the `hello-web` app from 02), push, **Refresh**.

**Expect:** UI tree shows `db-migrate` (PreSync) ✔ → app resources → `smoke-test`
(PostSync) ✔; its pod log ends `SMOKE PASS`. **Sync status** → operation details lists the phases.

**Break it**
- change the migrate command to `exit 1` → sync **fails at PreSync**, the Deployment is not
  touched — that's the safety net
- change the smoke grep to `grep nope` → app updated but sync **Failed** → alert on this
- `hook-delete-policy`: `BeforeHookCreation` keeps the last Job for logs; `HookSucceeded`
  deletes it on success

**Annotations used**

| Annotation | Values |
|---|---|
| `argocd.argoproj.io/hook` | `PreSync`, `Sync`, `PostSync`, `SyncFail` |
| `argocd.argoproj.io/hook-delete-policy` | `BeforeHookCreation`, `HookSucceeded`, `HookFailed` |
| `argocd.argoproj.io/sync-wave` | integer, default `0`, lower first |
