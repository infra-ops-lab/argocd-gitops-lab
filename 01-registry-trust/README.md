# 01 — Let the target nodes pull from an HTTP registry

**Goal:** every node pulls images itself. containerd refuses plain-HTTP registries unless told
otherwise — without this the pod sits in `ImagePullBackOff`.

**Run** — pick your distro:

| Cluster | File | Apply |
|---|---|---|
| containerd with `config_path` (most kubeadm-style clusters) | `hosts.toml` → `/etc/containerd/certs.d/<host:port>/hosts.toml` on **every node** | read on each pull, no restart needed |
| k3s | `k3s-registries.yaml` → `/etc/rancher/k3s/registries.yaml` | `systemctl restart k3s` |

Many nodes? From a jump host:
```bash
REG=<registry-host>:<port> NODES="<node1-ip> <node2-ip> <node3-ip>" ./registry-trust.sh
```

**Expect:** each node prints its `hosts.toml` and `active`.

**Check:** `grep -n config_path /etc/containerd/config.toml` must point at `certs.d`, otherwise
the file is ignored. Node changes are lost when nodes are re-provisioned — the durable fix is
TLS on the registry.
