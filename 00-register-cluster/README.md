# 00 — Register the target cluster

**Goal:** give ArgoCD a credential for the remote cluster. The GUI can't do this — use the CLI
(or a labelled Secret).

**Where to run:** any machine with **all three**: the `argocd` CLI, network to the ArgoCD
server, and the target cluster's kubeconfig + network to its API.

**Run**
```bash
curl -sSLo argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 755 argocd /usr/local/bin/argocd && rm argocd

argocd login <argocd-host>:<port> --username admin --insecure      # prompts for the password
kubectl config get-contexts                                         # pick the target's context
argocd cluster add <context> --name edge-cluster --yes
argocd cluster list
```

Example `get-contexts` output — the context is the **NAME** column, not the cluster:
```
CURRENT  NAME                          CLUSTER       SERVER
*        kubernetes-admin@edge-cluster edge-cluster  https://<api-ip>:6443
```
→ `argocd cluster add kubernetes-admin@edge-cluster --name edge-cluster --yes`
(kubeconfig not the default one? add `--kubeconfig <file>`)

**If `get-contexts` or `cluster add` comes back empty:** `argocd cluster add` reads whatever
`KUBECONFIG` currently points to (or `~/.kube/config` if unset) — it does **not** ask you which
file to use. Run it before exporting `KUBECONFIG` to the target cluster's kubeconfig and you'll
hit a confusing error that looks broken rather than wrong:
```
{"level":"error","msg":"Choose a context name from:","time":"..."}
CURRENT  NAME  CLUSTER  SERVER
```
— an error telling you to choose a context, followed by an empty list. That's not a bug; it means
no kubeconfig with any contexts is loaded. Fix: `export KUBECONFIG=<path>` (or `--kubeconfig
<file>` on both commands), confirm the context shows up in `get-contexts`, *then* run `cluster add`.

**Expect:** `edge-cluster` listed. Status `Unknown` until the first app targets it — normal.

**Everyday CLI** (everything here is also in the UI)
```bash
argocd app list                              # all apps: sync + health
argocd app get <app>                         # per-resource status, last error
argocd app diff <app>                        # git vs live
argocd app sync <app>                        # sync now (don't wait for the poll)
argocd app history <app>                     # deployed revisions
argocd app rollback <app> <history-id>       # back to a revision — needs auto-sync OFF; with GitOps prefer `git revert`
argocd app delete <app>                      # remove app + its resources
argocd appset list                           # ApplicationSets
argocd cluster rm <name>                     # forget a cluster
```

**What it did:** created ServiceAccount `argocd-manager` (cluster-admin) on the target and stored
its token in ArgoCD as a Secret labelled `argocd.argoproj.io/secret-type: cluster`.
Lab only — scope it down for anything shared.
