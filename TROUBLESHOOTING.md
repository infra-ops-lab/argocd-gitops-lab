# Troubleshooting

Symptom → cause → fix. The first block is what actually broke while building this lab.

## Hit while building this lab

| Symptom | Cause | Fix |
|---|---|---|
| `argocd login ... <password>` prints the usage text | the password was given as a 2nd positional arg | drop it — `argocd login <host>:<port> --username admin --insecure` prompts. Avoid `--password` (shell history) |
| `argocd cluster add` → `Choose a context name from:` | no context given | `argocd cluster add <CONTEXT-from-the-list> --name <name>` |
| `kubectl apply app.yaml` → `Unexpected args` | missing `-f` | `kubectl apply -f app.yaml` (on k3s: `sudo k3s kubectl ...`) |
| pushed the deploy repo, **no pipeline started** | expected — a deploy repo has no workflow; ArgoCD *pulls* it | create the Application; for instant sync add a webhook |
| `hosts.toml` exists but is **empty** | script did `echo $PW \| sudo -S tee file` — the password pipe replaced the content pipe | write the file inside one `sudo sh -c "printf ... > file"` |
| `argocd cluster list` → `Unknown` | ArgoCD connects lazily | normal until an app targets the cluster |
| ApplicationSet (repos) `got 404 while getting default branch "main"` | applied before the repo had a commit | push, then refresh: `kubectl -n argocd annotate applicationset <name> argocd.argoproj.io/application-set-refresh=true --overwrite` |
| generated app `ComparisonError ... SSH agent requested but SSH_AUTH_SOCK not-specified`, repoURL `git@git.example.com:...` | scanner's `{{.url}}` = SSH clone URL from an unconfigured Gitea SSH domain | build it: `repoURL: 'http://<host>/{{.organization}}/{{.repository}}.git'` |
| SCM scanner: `404` listing repos | `owner` is a **user**; the Gitea scanner lists org repos only | move the repos into an organization |
| new repo pushed, no app for a long time | scan interval 30 min | `requeueAfterSeconds` or the refresh annotation |

## Cluster / connection

| Symptom | Cause | Fix |
|---|---|---|
| `cluster add` hangs or `dial tcp ...:6443` | the machine running the CLI or the ArgoCD pods can't reach the target API | test `curl -k https://<api>:6443/version` from **an ArgoCD pod**, not just your shell |
| app error `cluster "edge-cluster" not found` | `destination.name` doesn't match `argocd cluster list` | use the exact name, or `destination.server: https://<api>:6443` |
| `the server has asked for the client to provide credentials` | target cluster rebuilt → stored SA token invalid | `argocd cluster rm <name>` then `cluster add` again |

## Repo

| Symptom | Cause | Fix |
|---|---|---|
| `ComparisonError ... repository not found` / `authentication required` | private repo, ArgoCD has no creds | Settings → Repositories → connect with a read-only token, or make the repo public |
| `... no such host` for the repo URL | `repoURL` uses an in-cluster DNS name of *another* cluster | use the git server's external address |
| `app path does not exist` | `path:` wrong or branch empty | `path: k8s`, `targetRevision: main`, and push first |
| git changed, app still old | polling interval (~3 min) | **Refresh** in the UI, or add a webhook |
| webhook delivery fails `webhook can only call allowed HTTP servers` | Gitea blocks private/internal targets by default | `[webhook] ALLOWED_HOST_LIST = private` |
| deleted a generated Application, it came back | the ApplicationSet owns it | remove the folder/repo, or the ApplicationSet |

## Sync / health

| Symptom | Cause | Fix |
|---|---|---|
| `namespaces "hello-web" not found` | namespace doesn't exist | `syncOptions: [CreateNamespace=true]` |
| **OutOfSync** right after a manual `kubectl` change | drift from git | expected; `selfHeal: true` reverts it, or sync manually |
| stays OutOfSync forever, no diff you made | a controller/webhook mutates a field (e.g. defaults, HPA replicas) | `ignoreDifferences` for that field |
| resource deleted from git but still running | `prune` is off | `automated: { prune: true }` or sync with Prune ticked |
| **Progressing** forever | pods not Ready | look at the pods, not ArgoCD ↓ |

## Image pull on the target

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` · `http: server gave HTTP response to HTTPS client` | node containerd doesn't trust the HTTP registry | [01-registry-trust](01-registry-trust/) on **every** node |
| `hosts.toml` in place, still HTTPS errors | containerd `config_path` not set → `certs.d` ignored | `grep config_path /etc/containerd/config.toml` |
| `401 Unauthorized` / `not found` on pull | private package | `imagePullSecrets` in the Deployment, or make the package public |
| works on one node, fails on another | registry trust applied to only some nodes | each node pulls for itself — apply everywhere |
| `dial tcp <registry>: i/o timeout` | node can't reach the registry | test `curl http://<registry>/v2/` **from the node** |

## Where to look

```bash
argocd app get hello-web                 # sync + health + last error, per resource
argocd app diff hello-web                # git vs live
kubectl -n argocd logs deploy/argocd-repo-server --tail=50      # repo / manifest errors
kubectl -n argocd logs statefulset/argocd-application-controller --tail=50   # sync / cluster errors
kubectl -n hello-web describe pod -l app=hello-web               # on the target: pull + scheduling
```
