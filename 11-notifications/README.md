# 11 — Notifications: tell someone when a deploy happens or breaks

**Goal:** ArgoCD posts a message on **sync succeeded** and on **Degraded**. Here the receiver
is an in-cluster echo server so it works offline; in real life swap it for Slack / Teams / email.

```
app event ─► notifications-controller ─ trigger (when?) ─ template (what?) ─ service (where?) ─► echo / Slack
```

**Run** (on the ArgoCD cluster)
```bash
kubectl apply -f echo/echo.yaml
kubectl -n argocd patch cm argocd-notifications-cm --type merge --patch-file notifications-cm-patch.yaml
kubectl -n argocd annotate application hello-web \
  notifications.argoproj.io/subscribe.on-synced.echo="" \
  notifications.argoproj.io/subscribe.on-degraded.echo=""
```

**Expect:** push a change to `hello-web` → `kubectl -n argocd logs deploy/echo` shows a POST
`{"app":"hello-web","sync":"Synced","health":"Healthy",...}`. Break the image tag (lesson 04)
→ a second message with `"health":"Degraded"`.

**Pieces**

| Key in `argocd-notifications-cm` | Role |
|---|---|
| `service.<type>.<name>` | where to send (webhook, slack, email, teams, ...) |
| `template.<name>` | message body, Go template over the app object |
| `trigger.<name>` | condition + which templates to send |
| annotation on the app | `notifications.argoproj.io/subscribe.<trigger>.<service>: <recipient>` |

Ready-made triggers/templates: the official catalog
(`notifications_catalog/install.yaml` in the argo-cd repo).
Debug: `kubectl -n argocd logs deploy/argocd-notifications-controller`.
