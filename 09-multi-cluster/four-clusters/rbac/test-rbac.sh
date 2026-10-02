#!/bin/bash
# Prove the policy does what the table says, before applying it. Works offline:
# needs only the argocd CLI and argocd-rbac-cm.yaml (no cluster).
#   ./test-rbac.sh                     uses ./argocd-rbac-cm.yaml
set -uo pipefail
cd "$(dirname "$0")" || exit 1
POLICY=argocd-rbac-cm.yaml
# The CLI builds a Kubernetes client even with --policy-file; a dummy kubeconfig is enough (never contacted).
if [ -z "${KUBECONFIG:-}" ] && [ ! -f "$HOME/.kube/config" ]; then
  KUBECONFIG=$(mktemp); export KUBECONFIG; trap 'rm -f "$KUBECONFIG"' EXIT
  printf 'apiVersion: v1\nkind: Config\nclusters: [{name: x, cluster: {server: "https://127.0.0.1:1"}}]\ncontexts: [{name: x, context: {cluster: x, user: x}}]\ncurrent-context: x\nusers: [{name: x, user: {token: dummy}}]\n' > "$KUBECONFIG"
fi
pass=0; fail=0
check() {   # check <expect yes|no> <user> <resource> <action> <object>
  local expect=$1 user=$2 res=$3 act=$4 obj=$5 got
  if argocd admin settings rbac can "$user" "$act" "$res" "$obj" --policy-file "$POLICY" </dev/null >/dev/null 2>&1; then got=yes; else got=no; fi
  if [ "$got" = "$expect" ]; then pass=$((pass+1)); mark=ok; else fail=$((fail+1)); mark=FAIL; fi
  printf '%-4s %-7s %-6s %-13s %-7s %-40s -> %s\n' "$mark" "$user" "$expect" "$res" "$act" "$obj" "$got"
}
#        expect user    resource      action   object
check yes sam    applications sync  shop-nonprod/shop-storefront-dev
check no  sam    applications sync  shop-prod/shop-storefront-prod
check yes sam    applications get   shop-prod/shop-storefront-prod
check no  sam    applications sync  payments-nonprod/payments-api-dev
check yes sam    exec         create shop-nonprod/shop-storefront-dev
check no  sam    exec         create shop-prod/shop-storefront-prod
check yes sam    applications action/apps/Deployment/restart shop-nonprod/shop-storefront-staging
check no  sam    applications delete shop-nonprod/shop-storefront-dev
check yes pat    applications sync  payments-nonprod/payments-api-staging
check no  pat    applications sync  shop-nonprod/shop-storefront-dev
check yes rita   applications sync  shop-prod/shop-storefront-prod
check yes rita   applications sync  payments-prod/payments-api-prod
check no  rita   applications sync  shop-nonprod/shop-storefront-dev
check no  rita   applications delete shop-prod/shop-storefront-prod
check yes petra  applications delete shop-prod/shop-storefront-prod
check yes petra  clusters     update prod
check no  sam    clusters     update prod
check yes victor applications get   shop-prod/shop-storefront-prod
check no  victor applications sync  shop-nonprod/shop-storefront-dev
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
