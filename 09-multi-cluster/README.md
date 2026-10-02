# 09 — Multi-cluster: one definition, every cluster

**Goal:** deploy the same app to **every cluster ArgoCD knows**, and to each new cluster
automatically.

```
argocd cluster list                 ApplicationSet (clusters generator)
  in-cluster    (the ArgoCD one)  ──►  app whoami-in-cluster
  edge-cluster                    ──►  app whoami-edge-cluster
  <added later>                   ──►  app whoami-<name>      ← no extra step
```

**Run**
1. Copy `fleet/` into your deploy repo root, push.
2. Set `repoURL` in `argocd/appset-clusters.yaml`; `kubectl apply -f argocd/appset-clusters.yaml`

**Expect:** one `whoami-<cluster>` app per registered cluster, each Synced · Healthy.

**Pick clusters by label** instead of "all":
```bash
argocd cluster set edge-cluster --label env=prod
```
```yaml
    - clusters:
        selector:
          matchLabels: { env: prod }
```
Typical use: platform add-ons (monitoring agent, ingress, policies) on every cluster;
`env=prod` / `region=eu` labels to target subsets.

**Hub-and-spoke reminder:** the ArgoCD cluster must reach every target's API. If a site can't
be reached from the hub, run ArgoCD (or Flux) **in** that site instead.
