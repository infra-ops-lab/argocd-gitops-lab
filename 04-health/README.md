# 04 — Health: applied ≠ working

**Goal:** Synced means "the YAML was applied". **Health** says whether it actually runs.

| Status | Means |
|---|---|
| Healthy | all replicas ready, Service has endpoints |
| Progressing | rolling out / not ready yet |
| Degraded | failed — e.g. rollout exceeded `progressDeadlineSeconds` |
| Missing | in git, not in the cluster |
| Suspended | paused (e.g. scaled-to-zero CronJob, paused rollout) |

**Run** — on the `hello-web` deploy repo, one at a time, push, watch the app tile:

| # | Change in `k8s/deployment.yaml` | Expect |
|---|---|---|
| 1 | `image: ...hello-web:does-not-exist` | Synced · **Progressing** → **Degraded** (ImagePullBackOff; faster with `progressDeadlineSeconds: 60`) |
| 2 | revert, then add a readinessProbe on a wrong path (below) | Synced · **Progressing** — pods run but never Ready |
| 3 | revert | Healthy |

```yaml
          readinessProbe:
            httpGet: { path: /nope, port: 80 }
            periodSeconds: 5
```

**Lesson:** alert on **Health**, not Sync. A wrong image is perfectly "Synced".
Click the red pod → **Events** / **Logs** — the UI shows why without `kubectl`.
