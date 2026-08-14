#!/usr/bin/env bash

set -euo pipefail

NAMESPACES=(
  "payments"
  "orders"
  "cart"
  "customers"
)

echo "=========================================="
echo "Istio Ambient Security Verification"
echo "=========================================="

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is not installed."
  exit 1
}

command -v istioctl >/dev/null 2>&1 || {
  echo "ERROR: istioctl is not installed."
  exit 1
}

kubectl cluster-info >/dev/null

# --------------------------------------------------
# Ambient namespaces
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
# Waypoints
# --------------------------------------------------

echo
echo "==> Waypoints"

istioctl waypoint list -A

# --------------------------------------------------
# STRICT mTLS
# --------------------------------------------------

echo
echo "==> PeerAuthentication"

kubectl get peerauthentication \
  -A

for namespace in "${NAMESPACES[@]}"; do

  mode="$(
    kubectl get peerauthentication default \
      -n "${namespace}" \
      -o jsonpath='{.spec.mtls.mode}'
  )"

  if [[ "${mode}" != "STRICT" ]]; then
    echo "ERROR: ${namespace} is not configured for STRICT mTLS."
    exit 1
  fi

  echo "${namespace}: STRICT mTLS"

done

# --------------------------------------------------
# Authorization policies
# --------------------------------------------------

echo
echo "==> AuthorizationPolicies"

kubectl get authorizationpolicy \
  -A

# --------------------------------------------------
# Payments policies
# --------------------------------------------------

echo
echo "==> Payments authorization"

kubectl get authorizationpolicy \
  -n payments \
  payments-default-deny \
  payments-allow-orders

# --------------------------------------------------
# Orders policies
# --------------------------------------------------

echo
echo "==> Orders authorization"

kubectl get authorizationpolicy \
  -n orders \
  orders-default-deny \
  orders-allow-cart

# --------------------------------------------------
# Customers policies
# --------------------------------------------------

echo
echo "==> Customers authorization"

kubectl get authorizationpolicy \
  -n customers \
  customers-default-deny \
  customers-allow-orders

# --------------------------------------------------
# Cart policy
# --------------------------------------------------

echo
echo "==> Cart authorization"

kubectl get authorizationpolicy \
  -n cart \
  cart-default-deny

echo
echo "=========================================="
echo "Istio Ambient security verification completed"
echo "=========================================="