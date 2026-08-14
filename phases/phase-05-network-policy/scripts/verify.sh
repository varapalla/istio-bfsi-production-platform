#!/usr/bin/env bash

set -euo pipefail

NAMESPACES=(
  "payments"
  "orders"
  "cart"
  "customers"
)

echo "=========================================="
echo "Kubernetes NetworkPolicy Verification"
echo "=========================================="

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is not installed."
  exit 1
}

kubectl cluster-info >/dev/null

# --------------------------------------------------
# Verify Ambient namespaces
# --------------------------------------------------

echo
echo "==> Ambient namespaces"

for namespace in "${NAMESPACES[@]}"; do

  mode="$(
    kubectl get namespace "${namespace}" \
      -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
  )"

  if [[ "${mode}" != "ambient" ]]; then
    echo "ERROR: ${namespace} is not Ambient."
    exit 1
  fi

  echo "${namespace}: Ambient"

done

# --------------------------------------------------
# Verify NetworkPolicies
# --------------------------------------------------

echo
echo "==> NetworkPolicies"

kubectl get networkpolicy -A

for namespace in "${NAMESPACES[@]}"; do

  policy="default-deny-ingress"

  if ! kubectl get networkpolicy \
    "${policy}" \
    -n "${namespace}" >/dev/null 2>&1; then

    echo "ERROR: ${namespace}/${policy} not found."
    exit 1

  fi

  echo "${namespace}: ${policy} exists"

done

# --------------------------------------------------
# Verify Istio security
# --------------------------------------------------

echo
echo "==> PeerAuthentication"

kubectl get peerauthentication -A

echo
echo "==> AuthorizationPolicies"

kubectl get authorizationpolicy -A

# --------------------------------------------------
# Verify Waypoints
# --------------------------------------------------

echo
echo "==> Waypoints"

command -v istioctl >/dev/null 2>&1 || {
  echo "ERROR: istioctl is not installed."
  exit 1
}

istioctl waypoint list --all

echo
echo "=========================================="
echo "NetworkPolicy verification completed"
echo "=========================================="