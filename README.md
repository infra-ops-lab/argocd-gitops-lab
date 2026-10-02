# argocd-gitops-lab

> **Series** (do in order): 1. [gitea-actions-lab](https://github.com/infra-ops-lab/gitea-action-lab) — CI: build + push an image → 2. [argocd-gitops-lab](https://github.com/infra-ops-lab/argocd-gitops-lab) — CD: deploy it with GitOps → 3. jenkins-ci-lab (soon) → 4. cicd-capstone (soon): push code → new version live, no human step

Hands-on, code-first lab: **ArgoCD on one cluster deploys to another cluster** from a git repo
and a registry hosted on a third machine. Each folder is one lesson — a short README
(goal → run → expect → break it) and the code. Stuck? → [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

> **New to ArgoCD? Start here → [ARCHITECTURE.md](ARCHITECTURE.md)** — what it is, what it can do, what you set up where, the 3 components, the
> flow from git to cluster, and the words used in every lesson. Then do the lessons in order.

✅ = run end-to-end on the reference lab · 📝 = written, verify as you go (fixes welcome)

```
 git server + registry           ArgoCD (tools cluster)            target cluster
 (repo: deploy-demo,  ◄─ polls ──┤ Application hello-web  ── apply ──► API :6443
  image: hello-web)              │                                      │ nodes
        ▲                                                               │
        └────────────────────── image pull (containerd) ────────────────┘
```

**Two repos, on purpose:** the *app repo* holds code and CI builds the image
([gitea-actions-lab](https://github.com/infra-ops-lab/gitea-action-lab) lesson 05); the *deploy repo* holds only the
desired state that ArgoCD applies — it needs no pipeline.

## Three ways to tell ArgoCD about an app

Same task in every column — **add a new app `shop`**:

| | **A. Application by hand** (02) | **B. ApplicationSet: folders** (07) | **C. ApplicationSet: repos** (08) |
|---|---|---|---|
| One-time setup | nothing | apply 1 ApplicationSet → watches `gitops-apps/apps/*` | apply 1 ApplicationSet → watches org `team-apps` |
| Where shop's YAML goes | its repo, `k8s/` | new **folder** `apps/shop/` | new **repo** `team-apps/shop` with `k8s/` |
| Write an Application? | ✅ every time | ❌ | ❌ |
| Touch ArgoCD? | ✅ `kubectl apply` | ❌ | ❌ |
| Your steps | create repo · write Application · apply | add folder · push | create repo · push |
| Remove shop | delete the app in ArgoCD | delete the folder · push | delete the repo |
| New app shows up | immediately | ~3 min (instant with webhook) | next scan, 30 min default |
| Typical use | learning, 1–2 apps | most teams: onboarding by reviewed PR | many teams, repo per app |

A and B/C differ in **who creates the Application** — you, or a generator. B and C differ only
in **where the list of apps lives** — folders in one repo, or repos in one org.

## How fast does a change reach the cluster?

| Change | Default | Instant |
|---|---|---|
| edit an existing app (tag, replicas) | ~3 min poll | git webhook → `https://<argocd>/api/webhook` |
| new folder (B) | ~3 min | same webhook |
| new repo (C) | 30 min scan | `requeueAfterSeconds`, or the refresh annotation |

Gitea refuses webhooks to private IPs by default → set `[webhook] ALLOWED_HOST_LIST = private`
(Helm: `gitea.config.webhook.ALLOWED_HOST_LIST`). An **org-level** webhook covers every repo in it.

**Prerequisites:** ArgoCD running on a "tools" cluster, a target cluster you have a kubeconfig
for, a git server + registry (here Gitea), and the `hello-web` image from the CI lab.
