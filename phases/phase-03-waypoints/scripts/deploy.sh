#!/usr/bin/env bash

set -euo pipefail

WAYPOINTS=(
  "payments:payments-waypoint"
  "orders:orders-waypoint"
  "cart:cart-waypoint"
  "customers:customers-waypoint"
)

echo "=========================================="
echo "Istio Ambient Waypoint Deployment"
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

for entry in "${WAYPOINTS[@]}"; do

  namespace="${entry%%:*}"
  waypoint="${entry##*:}"

  echo
  echo "==> Deploying ${waypoint}"
  echo "    Namespace: ${namespace}"

  if ! kubectl get namespace "${namespace}" >/dev/null 2>&1; then
    echo "ERROR: Namespace ${namespace} does not exist."
    echo "Run Phase 2 before Phase 3."
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

  istioctl waypoint apply \
    --namespace "${namespace}" \
    --name "${waypoint}" \
    --for service \
    --wait

  echo
  echo "==> Enrolling namespace with ${waypoint}"

  kubectl label namespace "${namespace}" \
    "istio.io/use-waypoint=${waypoint}" \
    --overwrite

  echo "Waypoint deployed: ${waypoint}"
  echo "Namespace enrolled: ${namespace}"

done

echo
echo "=========================================="
echo "Waypoint deployment completed"
echo "=========================================="

echo
echo "==> Waypoints"

istioctl waypoint list --all

echo
echo "==> Namespace labels"

kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels