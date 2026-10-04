# 02 — First app: deploy by git push

**Goal:** ArgoCD keeps the target cluster equal to what's in git.

**Run**
1. Create an empty repo `deploy-demo` on the git server; push `k8s/` into it
   (set `image:` to your `hello-web:<sha7>` tag).
2. Set `repoURL` and `destination.name` in `app.yaml`, then on the **ArgoCD** cluster:
   `kubectl apply -f app.yaml`

**Expect:** ArgoCD UI → `hello-web` **Synced · Healthy**, destination `edge-cluster`.
`curl <any-target-node>:30090` → `hello-web v1`.

![hello-web Synced and Healthy: app → svc + deploy → rs → pod](img/argocd-synced-healthy.png)

**Next:** [03](../03-drift-selfheal-prune-rollback/) — scale it, break it, heal it, roll it back.

**Faster than polling:** see [12](../12-webhook-instant-sync/).

**Running this on `kind` instead of a VM/k3s target?** Use [`app.local-kind.yaml`](app.local-kind.yaml)
in place of `app.yaml` — `destination.server` (a raw address) instead of `destination.name` (a
registered cluster name). Bind the `kind` cluster's API server to a fixed address at creation time
(`networking.apiServerAddress` + `apiServerPort` in the `kind` cluster config) so the address
doesn't change on every recreate, and so it's reachable both from your shell and from Argo CD's
own pods — otherwise `argocd cluster add`/syncing can fail trying to dial `127.0.0.1` from inside
a pod, which means the pod itself, not your host.
