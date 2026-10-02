# 05 — Helm and Kustomize: one app, many environments

**Goal:** ArgoCD isn't limited to plain YAML. It renders **Kustomize** and **Helm** itself —
no `helm install` anywhere.

```
kustomize/
├── base/                      deployment + service (shared)
└── overlays/
    ├── dev/                   replicas 1, nodePort 30094   → app hello-dev
    └── prod/                  replicas 3, nodePort 30095   → app hello-prod
helm/hello-web/                chart: replicas, image, nodePort as values → app hello-helm
argocd/                        3 Applications (same repo, different path)
```

**Run**
1. Copy `kustomize/` and `helm/` into your deploy repo root; set `image:` in
   `kustomize/base/deployment.yaml` and `helm/hello-web/values.yaml`. Push.
2. Set `repoURL` / `destination.name` in `argocd/*.yaml`; `kubectl apply -f argocd/`

**Expect:** 3 apps. `hello-dev` 1 pod, `hello-prod` 3 pods, `hello-helm` 2 pods
(`valuesObject` in the Application overrides `values.yaml`'s 1).
Check locally first: `kubectl kustomize kustomize/overlays/prod` · `helm template x helm/hello-web`

**How ArgoCD decides:** `kustomization.yaml` in the path → Kustomize; `Chart.yaml` → Helm;
otherwise plain YAML.

**Break it**
- change `count: 3` in prod → only `hello-prod` changes; dev untouched
- bump the image tag in `base/` → both dev and prod roll
- `helm list -A` on the target shows **nothing** — ArgoCD renders the chart and applies the
  YAML; it doesn't create Helm releases
