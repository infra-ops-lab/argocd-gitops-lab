# 12 — Webhook: sync on push instead of polling

**Goal:** git tells ArgoCD about a push → sync in seconds instead of up to ~3 min.

```
git push ─► git server ─ webhook POST ─► ArgoCD /api/webhook ─► refresh the matching apps
```

**Run**
1. Gitea only: allow webhooks to private addresses (blocked by default):
   `[webhook] ALLOWED_HOST_LIST = private` — Helm: `--set gitea.config.webhook.ALLOWED_HOST_LIST=private`
2. Deploy repo (or the whole **organization**) → Settings → Webhooks → Add → **Gitea**
   - URL: `https://<argocd-host>/api/webhook` — same cluster as the git server?
     `http://argocd-server.argocd.svc.cluster.local/api/webhook`
   - Trigger: push events · Content type: `application/json`
3. Optional secret: set the same value in the webhook and in `argocd-secret` key
   `webhook.gogs.secret` (Gitea webhooks use the Gogs format).

**Expect:** change `replicas`, push → app updates within seconds; webhook **Recent
Deliveries** shows `200`.

**What it covers:** existing apps and ApplicationSet **git** generators (new folders).
Not the SCM-provider scan for new repos — that stays on `requeueAfterSeconds`.

**Troubleshoot:** delivery `webhook can only call allowed HTTP servers` → step 1 ·
`200` but nothing happens → `repoURL` in the app must match the URL the webhook reports ·
logs: `kubectl -n argocd logs deploy/argocd-server | grep -i webhook`
