#!/usr/bin/env bash

set -euo pipefail

ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"

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
# Gateway API verification
# --------------------------------------------------

echo
echo "==> Gateway API"

kubectl get crd \
  gateways.gateway.networking.k8s.io

# --------------------------------------------------
# Namespace verification
# --------------------------------------------------

echo
echo "==> Verifying Ambient namespaces"

for entry in "${WAYPOINTS[@]}"; do

  namespace="${entry%%:*}"
  waypoint="${entry##*:}"

  echo
  echo "Checking namespace: ${namespace}"

  if ! kubectl get namespace "${namespace}" >/dev/null 2>&1; then
    echo "ERROR: Namespace ${namespace} does not exist."
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

  configured_waypoint="$(
    kubectl get namespace "${namespace}" \
      -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}'
  )"

  if [[ "${configured_waypoint}" != "${waypoint}" ]]; then
    echo "ERROR: ${namespace} is not configured to use ${waypoint}."
    echo "Current waypoint: ${configured_waypoint:-not-set}"
    exit 1
  fi

  echo "Ambient Mode : enabled"
  echo "Waypoint      : ${waypoint}"

done

# --------------------------------------------------
# Waypoint Gateway verification
# --------------------------------------------------

echo
echo "==> Verifying Waypoint Gateways"

for entry in "${WAYPOINTS[@]}"; do

  namespace="${entry%%:*}"
  waypoint="${entry##*:}"

  echo
  echo "Checking: ${waypoint} in ${namespace}"

  if ! kubectl get gateway \
      "${waypoint}" \
      -n "${namespace}" >/dev/null 2>&1; then

    echo "ERROR: Waypoint ${waypoint} does not exist."
    exit 1
  fi

  kubectl get gateway \
    "${waypoint}" \
    -n "${namespace}"

done

# --------------------------------------------------
# Waypoint status
# --------------------------------------------------

echo
echo "==> Waypoint Gateway status"

kubectl get gateway -A

# --------------------------------------------------
# Waypoint deployments
# --------------------------------------------------

echo
echo "==> Waypoint deployments"

for entry in "${WAYPOINTS[@]}"; do

  namespace="${entry%%:*}"

  echo
  echo "Namespace: ${namespace}"

  kubectl get deployment \
    -n "${namespace}"

done

# --------------------------------------------------
# Waypoint Pods
# --------------------------------------------------

echo
echo "==> Waypoint Pods"

kubectl get pods \
  -A \
  -l gateway.istio.io/managed=istio.io-mesh-controller \
  -o wide

# --------------------------------------------------
# Waypoint list
# --------------------------------------------------

echo
echo "==> Istio Waypoints"

istioctl waypoint list --all

# --------------------------------------------------
# Final namespace state
# --------------------------------------------------

echo
echo "==> Namespace labels"

kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels

echo
echo "=========================================="
echo "Waypoint verification completed"
echo "=========================================="