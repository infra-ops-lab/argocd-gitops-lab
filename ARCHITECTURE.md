# ArgoCD — start here

## What it is

> Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It is implemented
> as a Kubernetes controller which continuously monitors running applications and compares the
> current, live state against the desired target state (as specified in the Git repo).
> — official docs

In plain words: **you describe your apps in git; ArgoCD makes the clusters match, and keeps
them matching.** Nobody runs `kubectl apply` against production by hand.

## What it can do

| Feature | Meaning | Lesson |
|---|---|---|
| Deploy from git | plain YAML, Helm charts, Kustomize, Jsonnet | 02, 05 |
| Many clusters from one place | one ArgoCD (hub) deploys to dev / staging / prod clusters (spokes) | 00, 09 |
| Drift detection | shows **OutOfSync** when the cluster differs from git, with a diff | 03 |
| Self-heal | puts back anything changed by hand on the cluster | 03 |
| Prune | deletes what was removed from git | 03 |
| Rollback | `git revert`, or History and Rollback in the UI | 03 |
| Health | knows if Deployments, pods, services are really up — not just applied | 04 |
| Web UI | live tree of every app: app → deploy → replicaset → pod | 02 |
| Sync hooks | run a job before/after a deploy (DB migration, smoke test) | 06 |
| Generate apps | ApplicationSet: one template → an app per folder, repo, or cluster | 07, 08, 09 |
| SSO + RBAC | who may see / sync which app | 10 |
| Notifications | Slack, email, webhooks on sync / failure | 11 |

What it is **not**: a CI tool. It doesn't build or test images — CI does that, then commits the
new tag to git.

## What you set up, and where

| # | What | Where | How | Lesson |
|---|---|---|---|---|
| 1 | Install ArgoCD | a "tools" cluster | `kubectl create ns argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` (or the Helm chart) | — |
| 2 | Open the UI | same cluster | expose `argocd-server` (NodePort / Ingress); first password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` | — |
| 3 | `argocd` CLI | your workstation / jump host | download the binary, `argocd login` | 00 |
| 4 | Register target clusters | from a host with the target's kubeconfig | `argocd cluster add <context>` | 00 |
| 5 | Nodes can pull your images | every target node | registry trust / pull secret | 01 |
| 6 | Deploy repo | git server | `k8s/` with the manifests | 02 |
| 7 | Tell ArgoCD about the app | ArgoCD cluster | apply an Application (or an ApplicationSet once) | 02, 07, 08 |
| 8 | Faster sync (optional) | git server | webhook → `https://<argocd>/api/webhook` | 12 |

After that, day-to-day work is only **git push**.

---

## How it works

```
            you / CI                         git (desired state)
               │ PR merge ─────────────────►  deploy repo: image v2, 3 replicas
               │                                   │
               │ UI · CLI · API              webhook (or poll ~3 min)
               ▼                                   ▼
   ┌───────────────────── ArgoCD (runs on a "tools" cluster) ──────────────────────┐
   │  API Server          Repo Server               Application Controller         │
   │  front door:         clones git, renders       compares git ⇄ live cluster,   │
   │  UI/CLI, login,      YAML / Helm / Kustomize   applies the difference,        │
   │  cluster creds                                 heals drift                    │
   └───────────────────────────────────────────────────────┬───────────────────────┘
                                                           │ deploy
                                     ┌──────────┬──────────┴──┬──────────┐
                                     ▼          ▼             ▼          ▼
                                    dev      staging      prod-eu    prod-us     (target clusters)
```

## The three parts

| Part | Does | You meet it when |
|---|---|---|
| **API Server** | serves the UI, CLI and API; login, RBAC; stores cluster credentials | `argocd login`, the web UI, `argocd cluster add` |
| **Repo Server** | clones git and turns it into plain manifests — never touches a cluster | repo errors: `ComparisonError`, auth, bad path |
| **Application Controller** | the loop: *git says X, cluster has Y → make it X* | Synced / OutOfSync, self-heal, prune |

Also running, not drawn: **ApplicationSet controller** (generates apps — lessons 07/08),
**Redis** (cache), **Dex** (SSO), **Notifications** (Slack etc.).

## The flow, one line

PR merged → webhook → Repo Server renders the new YAML → Controller sees the difference →
applies it to the target cluster(s) → status in the UI.

## Words you'll see

| Term | Meaning |
|---|---|
| **Application** | "deploy *this path* of *this repo* to *this cluster/namespace*" |
| **Synced / OutOfSync** | live cluster equals git / differs from git |
| **Healthy / Progressing / Degraded** | are the deployed things actually working |
| **auto-sync** | apply git changes without clicking Sync |
| **self-heal** | undo manual changes on the cluster (git wins) |
| **prune** | delete what was removed from git |
| **hub-and-spoke** | one ArgoCD (hub) deploys to many clusters (spokes) — not federation |
| **pull vs push** | CI doesn't need cluster credentials; ArgoCD pulls from git and applies |

## Where CI fits

CI builds and tests the image, then **commits the new tag to the deploy repo**. ArgoCD does the
rest. CI tools *can* call ArgoCD's API (`argocd app sync`, `argocd app wait`), but committing
to git keeps git the single source of truth and gives you rollback by `git revert`.

**Next:** [00-register-cluster](00-register-cluster/) →
