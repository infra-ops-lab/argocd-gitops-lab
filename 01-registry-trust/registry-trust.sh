#!/bin/bash
# Make each node's containerd trust an HTTP registry (writes certs.d/<registry>/hosts.toml), one node at a time.
# Usage: REG=<host:port> NODES="10.0.0.11 10.0.0.12" ./registry-trust.sh      (RESTART=1 to restart containerd)
set -euo pipefail
: "${REG:?set REG=<registry-host>:<port>}" "${NODES:?set NODES=\"<node-ip> ...\"}"
read -rp "node ssh user: " NUSER; read -rsp "node password: " SSHPASS; echo; export SSHPASS

for n in $NODES; do
  echo "=== $n"
  sshpass -e ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$NUSER@$n" \
    "RESTART=${RESTART:-0} REG=$REG PW=$(printf %q "$SSHPASS") bash -s" <<'REMOTE'
set -e
s() { echo "$PW" | sudo -S -p "" "$@"; }
dir=$(s grep -E "^\s*config_path\s*=" /etc/containerd/config.toml | head -1 | sed -E "s/.*=\s*['\"]([^'\"]*)['\"].*/\1/" | cut -d: -f1)
if [ -z "$dir" ]; then echo "config_path not set in /etc/containerd/config.toml — nothing changed"; exit 3; fi
s mkdir -p "$dir/$REG"
s sh -c "printf 'server = \"http://%s\"\n\n[host.\"http://%s\"]\n  capabilities = [\"pull\", \"resolve\"]\n  skip_verify = true\n' $REG $REG > '$dir/$REG/hosts.toml'"
s cat "$dir/$REG/hosts.toml"
[ "${RESTART:-0}" = 1 ] && s systemctl restart containerd
s systemctl is-active containerd
REMOTE
done
