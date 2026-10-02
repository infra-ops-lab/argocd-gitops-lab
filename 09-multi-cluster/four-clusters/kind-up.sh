#!/bin/bash
# Build the 4-cluster lab on one machine with kind (about 8 GB RAM recommended):
#   mgmt    - runs Argo CD (the hub)
#   dev     - env=dev      tier=nonprod
#   staging - env=staging  tier=nonprod
#   prod    - env=prod     tier=prod
# Then register dev/staging/prod with Argo CD as declarative cluster Secrets (labels included).
# Needs: docker, kind, kubectl. Usage: ./kind-up.sh      (./kind-down.sh removes everything)
set -euo pipefail
cd "$(dirname "$0")"

ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"          # or a tag such as v3.1.0
declare -A ENV=( [dev]=dev [staging]=staging [prod]=prod )
declare -A TIER=( [dev]=nonprod [staging]=nonprod [prod]=prod )

for c in mgmt dev staging prod; do
  kind get clusters 2>/dev/null | grep -qx "$c" || kind create cluster --name "$c" --wait 120s
done

echo "=== Argo CD on mgmt"
kubectl --context kind-mgmt create namespace argocd --dry-run=client -o yaml | kubectl --context kind-mgmt apply -f -
kubectl --context kind-mgmt apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl --context kind-mgmt -n argocd rollout status deploy/argocd-server --timeout=300s

for c in dev staging prod; do
  echo "=== $c: create Argo CD's access, then register it"
  # dev and staging: Argo CD may manage the whole cluster. prod: only the team namespaces (least privilege).
  if [ "$c" = prod ]; then access=target-access/argocd-manager-prod.yaml; else access=target-access/argocd-manager-nonprod.yaml; fi
  kubectl --context "kind-$c" apply -f "$access"
  kubectl --context "kind-$c" -n kube-system wait --for=jsonpath='{.data.token}' secret/argocd-manager-token --timeout=60s

  token=$(kubectl --context "kind-$c" -n kube-system get secret argocd-manager-token -o jsonpath='{.data.token}' | base64 -d)
  ca=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name=='kind-$c')].cluster.certificate-authority-data}")
  # Argo CD runs inside the mgmt container, so use the node's address on the shared 'kind' Docker network,
  # not 127.0.0.1. The API server certificate includes this IP.
  ip=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "$c-control-plane")

  namespaces=""
  if [ "$c" = prod ]; then namespaces="shop-storefront,payments-api"; fi

  kubectl --context kind-mgmt apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-$c
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    env: ${ENV[$c]}
    tier: ${TIER[$c]}
    region: eu
type: Opaque
stringData:
  name: $c
  server: https://$ip:6443
  namespaces: "$namespaces"
  clusterResources: "$( [ "$c" = prod ] && echo false || echo true )"
  config: |
    {"bearerToken": "$token", "tlsClientConfig": {"caData": "$ca"}}
EOF
done

echo "=== registered clusters"
kubectl --context kind-mgmt -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster \
  -L env -L tier -L region
echo
echo "Admin password: kubectl --context kind-mgmt -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "UI:             kubectl --context kind-mgmt -n argocd port-forward svc/argocd-server 8080:443   -> https://localhost:8080"
