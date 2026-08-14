#!/usr/bin/env bash

set -euo pipefail

WAYPOINTS=(
  "payments:payments-waypoint"
  "orders:orders-waypoint"
  "cart:cart-waypoint"
  "customers:customers-waypoint"
)

echo "=========================================="
echo "Istio Ambient Waypoint Verification"
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
# Gateway API
# --------------------------------------------------

echo
echo "==> Gateway API"

kubectl get crd \
  gateways.gateway.networking.k8s.io

# --------------------------------------------------
# GatewayClass
# --------------------------------------------------

echo
echo "==> Istio Waypoint GatewayClass"

kubectl get gatewayclass istio-waypoint

# --------------------------------------------------
# Namespace and waypoint verification
# --------------------------------------------------

for entry in "${WAYPOINTS[@]}"; do

  namespace="${entry%%:*}"
  waypoint="${entry##*:}"

  echo
  echo "==> Checking ${namespace}"
  echo "    Waypoint: ${waypoint}"

  # Namespace
  kubectl get namespace "${namespace}" >/dev/null

  # Ambient enrollment
  ambient_mode="$(
    kubectl get namespace "${namespace}" \
      -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
  )"

  if [[ "${ambient_mode}" != "ambient" ]]; then
    echo "ERROR: ${namespace} is not enrolled in Ambient Mode."
    exit 1
  fi

  # Waypoint enrollment
  configured_waypoint="$(
    kubectl get namespace "${namespace}" \
      -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}'
  )"

  if [[ "${configured_waypoint}" != "${waypoint}" ]]; then
    echo "ERROR: Incorrect waypoint configured for ${namespace}."
    echo "Expected: ${waypoint}"
    echo "Actual:   ${configured_waypoint:-not-set}"
    exit 1
  fi

  # Gateway
  kubectl get gateway \
    "${waypoint}" \
    -n "${namespace}"

done

# --------------------------------------------------
# Gateway status
# --------------------------------------------------

echo
echo "==> Waypoint Gateways"

kubectl get gateway -A

# --------------------------------------------------
# Waypoint deployments
# --------------------------------------------------

echo
echo "==> Waypoint Deployments"

kubectl get deployment -A \
  -l gateway.istio.io/managed=istio.io-mesh-controller

# --------------------------------------------------
# Waypoint Pods
# --------------------------------------------------

echo
echo "==> Waypoint Pods"

kubectl get pods -A \
  -l gateway.istio.io/managed=istio.io-mesh-controller \
  -o wide

# --------------------------------------------------
# Istio waypoint status
# --------------------------------------------------

echo
echo "==> Istio Waypoints"

istioctl waypoint list -A

echo
echo "=========================================="
echo "Waypoint verification completed"
echo "=========================================="