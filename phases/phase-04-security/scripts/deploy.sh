#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="${SCRIPT_DIR}/../security"

echo "=========================================="
echo "Istio Ambient Security Deployment"
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

for namespace in payments orders cart customers; do

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
# Verify waypoints
# --------------------------------------------------

echo
echo "==> Verifying waypoints"

for entry in \
  "payments:payments-waypoint" \
  "orders:orders-waypoint" \
  "cart:cart-waypoint" \
  "customers:customers-waypoint"
do

  namespace="${entry%%:*}"
  waypoint="${entry##*:}"

  kubectl get gateway \
    "${waypoint}" \
    -n "${namespace}" >/dev/null

  echo "${namespace}: ${waypoint} exists"

done

# --------------------------------------------------
# PeerAuthentication
# --------------------------------------------------

echo
echo "==> Applying STRICT mTLS policies"

kubectl apply \
  -f "${SECURITY_DIR}/peer-authentication.yaml"

# --------------------------------------------------
# AuthorizationPolicy
# --------------------------------------------------

echo
echo "==> Applying AuthorizationPolicies"

kubectl apply \
  -f "${SECURITY_DIR}/authorization/"

# --------------------------------------------------
# Final status
# --------------------------------------------------

echo
echo "==> PeerAuthentication"

kubectl get peerauthentication \
  -A

echo
echo "==> AuthorizationPolicies"

kubectl get authorizationpolicy \
  -A

echo
echo "=========================================="
echo "Istio Ambient security deployment completed"
echo "=========================================="