#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/../network-policy"

NAMESPACES=(
  "payments"
  "orders"
  "cart"
  "customers"
)

echo "=========================================="
echo "Kubernetes NetworkPolicy Deployment"
echo "=========================================="

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is not installed."
  exit 1
}

kubectl cluster-info >/dev/null

# --------------------------------------------------
# Verify namespaces
# --------------------------------------------------

echo
echo "==> Verifying application namespaces"

for namespace in "${NAMESPACES[@]}"; do

  kubectl get namespace "${namespace}" >/dev/null

  mode="$(
    kubectl get namespace "${namespace}" \
      -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
  )"

  if [[ "${mode}" != "ambient" ]]; then
    echo "ERROR: ${namespace} is not enrolled in Ambient Mode."
    exit 1
  fi

  echo "${namespace}: Ambient Mode enabled"

done

# --------------------------------------------------
# Apply NetworkPolicies
# --------------------------------------------------

echo
echo "==> Applying NetworkPolicies"

for namespace in "${NAMESPACES[@]}"; do

  echo
  echo "Applying policy for ${namespace}"

  kubectl apply \
    -f "${POLICY_DIR}/${namespace}/"

done

# --------------------------------------------------
# Final status
# --------------------------------------------------

echo
echo "==> NetworkPolicies"

kubectl get networkpolicy -A

echo
echo "=========================================="
echo "NetworkPolicy deployment completed"
echo "=========================================="