#!/usr/bin/env bash

set -euo pipefail

ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"

WAYPOINT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../waypoints" && pwd)"

echo "=========================================="
echo "Istio Ambient Waypoint Deployment"
echo "=========================================="

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is not installed."
  exit 1
}

kubectl cluster-info >/dev/null

# --------------------------------------------------
# Gateway API validation
# --------------------------------------------------

echo
echo "==> Verifying Gateway API"

kubectl get crd gateways.gateway.networking.k8s.io \
  >/dev/null 2>&1 || {
    echo "ERROR: Gateway API CRDs are not installed."
    exit 1
  }

# --------------------------------------------------
# Istio Waypoint GatewayClass
# --------------------------------------------------

echo
echo "==> Verifying Istio Waypoint GatewayClass"

kubectl get gatewayclass istio-waypoint \
  >/dev/null 2>&1 || {
    echo "ERROR: GatewayClass istio-waypoint does not exist."
    echo "Verify the Istio Ambient installation."
    exit 1
  }

# --------------------------------------------------
# Namespace validation
# --------------------------------------------------

echo
echo "==> Verifying Ambient namespaces"

for namespace in payments orders cart customers; do

  if ! kubectl get namespace "${namespace}" \
      >/dev/null 2>&1; then

    echo "ERROR: Namespace ${namespace} does not exist."
    echo "Complete Phase 2 before deploying Phase 3."
    exit 1
  fi

  mode="$(
    kubectl get namespace "${namespace}" \
      -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
  )"

  if [[ "${mode}" != "ambient" ]]; then
    echo "ERROR: ${namespace} is not enrolled in Ambient Mode."
    exit 1
  fi

done

# --------------------------------------------------
# Deploy waypoint Gateway resources
# --------------------------------------------------

echo
echo "==> Deploying waypoint Gateway resources"

kubectl apply \
  -f "${WAYPOINT_DIR}/payments-waypoint.yaml" \
  -f "${WAYPOINT_DIR}/orders-waypoint.yaml" \
  -f "${WAYPOINT_DIR}/cart-waypoint.yaml" \
  -f "${WAYPOINT_DIR}/customers-waypoint.yaml"

# --------------------------------------------------
# Enroll namespaces
# --------------------------------------------------

echo
echo "==> Enrolling namespaces to their waypoints"

kubectl label namespace payments \
  istio.io/use-waypoint=payments-waypoint \
  --overwrite

kubectl label namespace orders \
  istio.io/use-waypoint=orders-waypoint \
  --overwrite

kubectl label namespace cart \
  istio.io/use-waypoint=cart-waypoint \
  --overwrite

kubectl label namespace customers \
  istio.io/use-waypoint=customers-waypoint \
  --overwrite

# --------------------------------------------------
# Wait for Gateway resources
# --------------------------------------------------

echo
echo "==> Waiting for waypoint Gateways"

for entry in \
  "payments:payments-waypoint" \
  "orders:orders-waypoint" \
  "cart:cart-waypoint" \
  "customers:customers-waypoint"
do

  namespace="${entry%%:*}"
  waypoint="${entry##*:}"

  echo "Waiting for ${namespace}/${waypoint}"

  kubectl wait \
    --for=condition=programmed \
    "gateway/${waypoint}" \
    -n "${namespace}" \
    --timeout=180s

done

# --------------------------------------------------
# Final status
# --------------------------------------------------

echo
echo "==> Waypoint Gateways"

kubectl get gateway -A

echo
echo "==> Waypoint Deployments"

kubectl get deployment -A \
  -l gateway.istio.io/managed=istio.io-mesh-controller

echo
echo "==> Waypoint Pods"

kubectl get pods -A \
  -l gateway.istio.io/managed=istio.io-mesh-controller \
  -o wide

echo
echo "=========================================="
echo "Waypoint deployment completed"
echo "=========================================="