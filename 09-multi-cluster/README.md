# 09 — Multi-cluster: one Argo CD, four clusters, clear rules

**Goal:** run a small platform the way real teams do: one Argo CD (the hub) manages three
workload clusters, two teams deploy their own apps, and every person can do exactly what their
role allows, where it allows it.

```
                    mgmt  (Argo CD)
          ┌────────────┼──────────────┐
          ▼            ▼              ▼
         dev         staging         prod
   env=dev        env=staging      env=prod
   tier=nonprod   tier=nonprod     tier=prod
   cluster-admin  cluster-admin    only shop-* / payments-* namespaces
```

Two parts:
- **Part A** (quick): one app on every registered cluster with a cluster generator.
- **Part B** (the real setup): [`four-clusters/`](four-clusters/) — clusters as code, least-privilege
  access on prod, projects per team and environment, ApplicationSets, sync windows and RBAC.

---

## Part A — one app on every cluster

```
argocd cluster list                 ApplicationSet (clusters generator)
  in-cluster    (the Argo CD one)  ──►  app whoami-in-cluster
  edge-cluster                    ──►  app whoami-edge-cluster
  <added later>                   ──►  app whoami-<name>      ← no extra step
```

1. Copy `fleet/` into your deploy repo root, push.
2. Set `repoURL` in `argocd/appset-clusters.yaml`; `kubectl apply -f argocd/appset-clusters.yaml`

**Expect:** one `whoami-<cluster>` app per registered cluster, each Synced · Healthy.
Pick clusters by label instead of "all": `argocd cluster set edge-cluster --label env=prod`, then
`clusters: { selector: { matchLabels: { env: prod } } }` in the generator.

---

## Part B — four clusters, two teams, five roles

### 1. Build the clusters (one machine, kind)

```bash
cd four-clusters
./kind-up.sh          # mgmt + dev + staging + prod, Argo CD on mgmt, 3 clusters registered with labels
```
About 8 GB RAM is comfortable. What the script does for each workload cluster:

| Step | dev / staging | prod |
|---|---|---|
| Argo CD's identity on the cluster | ServiceAccount `argocd-manager` + `cluster-admin` | ServiceAccount + `admin` **only** in `shop-storefront` and `payments-api` |
| Namespaces + quotas | created by Argo CD (platform ApplicationSet) | created by the platform bootstrap (`target-access/argocd-manager-prod.yaml`) |
| Cluster Secret on mgmt | labels `env`, `tier`, `region` | same, plus `namespaces: shop-storefront,payments-api`, `clusterResources: "false"` |

Check: `kubectl --context kind-mgmt -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster -L env -L tier`

> Production clusters: same idea, but store cluster Secrets with External Secrets / Sealed
> Secrets, and on EKS use IAM (`awsAuthConfig`) instead of long-lived tokens.

### 2. Git repos

Create three repos on your git server and push the matching folder of
[`deploy-repos/`](four-clusters/deploy-repos/):

| Repo | Owner | Content |
|---|---|---|
| `platform/platform-deploy` | platform team | `tenants/`: team namespaces + quotas |
| `shop/shop-deploy` | shop team | `apps/storefront/{base,overlays/dev,staging,prod}` |
| `payments/payments-deploy` | payments team | `apps/api/{base,overlays/...}` |

Replace `<git-host>` in `projects/*.yaml` and `appsets/*.yaml` with your server.

### 3. Projects: the guard-rails

```bash
kubectl --context kind-mgmt apply -f projects/
```

| Project | Source repos | Destinations | Extra rules |
|---|---|---|---|
| `platform` | `platform/*` | any cluster, any namespace | cluster-scoped resources allowed |
| `shop-nonprod` | `shop/*` | `dev`, `staging` · `shop-*` | no cluster resources, no quotas/limits/network policies; `ci` role for pipelines |
| `shop-prod` | `shop/*` | `prod` · `shop-*` | same, plus **sync window** Mon–Thu 09:00–17:00 UTC |
| `payments-*` | `payments/*` | same shape, `payments-*` | same |

### 4. ApplicationSets: one definition per team and tier

```bash
kubectl --context kind-mgmt apply -f appsets/
```

| ApplicationSet | Generator | Creates | Sync |
|---|---|---|---|
| `platform-tenants` | clusters `tier=nonprod` | `tenants-dev`, `tenants-staging` | automatic, no prune |
| `shop-nonprod` | matrix: clusters `tier=nonprod` × `apps/*` | `shop-storefront-dev`, `shop-storefront-staging` | automatic, prune + self-heal |
| `shop-prod` | matrix: clusters `env=prod` × `apps/*` | `shop-storefront-prod` | **manual** (release manager), inside the window |
| `payments-*` | same | `payments-api-…` | same |

**Expect:** 8 apps. Dev/staging ones Synced · Healthy by themselves; prod ones **OutOfSync**
until someone allowed presses Sync during the window. Add `apps/checkout/` to `shop-deploy`
(copy `storefront`, rename) → three new apps appear, no Argo CD change.

### 5. Who may do what, where

```bash
kubectl --context kind-mgmt -n argocd apply -f rbac/argocd-rbac-cm.yaml
kubectl --context kind-mgmt -n argocd patch cm argocd-cm --type merge --patch-file rbac/argocd-cm-accounts.yaml
argocd account update-password --account sam      # as admin, for each lab user
```

| Who (lab user · SSO group) | dev / staging | prod |
|---|---|---|
| `petra` · `platform-admins` | everything | everything |
| `rita` · `release-managers` | view, logs | view, logs, **sync** (inside the window) |
| `sam` · `shop-developers` | view, logs, sync, restart, terminal — **shop only** | view, logs — shop only |
| `pat` · `payments-developers` | same, payments only | view, logs — payments only |
| `victor` · everyone else | read-only | read-only |

**Prove it before applying:** `rbac/test-rbac.sh` runs 19 checks against the policy file with
the `argocd` CLI — no cluster needed. Expect `passed: 19  failed: 0`.

**Break it**
- log in as `sam`, open `shop-storefront-prod` → **Sync** is refused (`permission denied`)
- as `sam`, sync `shop-storefront-dev` → works; try `payments-api-dev` → refused
- as `rita`, sync `shop-storefront-prod` on a Friday → blocked by the sync window
- as `sam`, add a `ResourceQuota` to `shop-deploy` → sync fails: kind not permitted in project
- in `shop-deploy`, point an app at namespace `payments-api` → `destination ... is not permitted`
- delete the `shop-prod` ApplicationSet → the apps go, the running workload stays
  (`preserveResourcesOnDeletion: true`)

### 6. Day-2 tasks

| Task | How |
|---|---|
| Add a cluster | create its access + cluster Secret with labels → matching ApplicationSets create its apps |
| Remove a cluster | remove the label or Secret → generated apps are deleted (check `preserveResourcesOnDeletion` first) |
| Rotate a cluster credential | new token on the cluster, update the Secret, delete the old token |
| Give a person access | add them to the SSO group; no Argo CD change |
| Freeze prod | add a `deny` window in `*-prod` projects via a pull request |

`./kind-down.sh` removes everything.

**Hub-and-spoke reminder:** the Argo CD cluster must reach every target's API. If a site can't
be reached from the hub, run Argo CD (or Flux) **in** that site instead.
