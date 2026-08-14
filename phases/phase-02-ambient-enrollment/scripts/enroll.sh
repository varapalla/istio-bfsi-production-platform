#!/usr/bin/env bash

set -euo pipefail

NAMESPACES=(
  "payments"
  "orders"
  "cart"
  "customers"
)

AMBIENT_LABEL="istio.io/dataplane-mode=ambient"

echo "=========================================="
echo "Istio Ambient Namespace Enrollment"
echo "=========================================="

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is not installed."
  exit 1
}

kubectl cluster-info >/dev/null

for namespace in "${NAMESPACES[@]}"; do
  echo
  echo "==> Processing namespace: ${namespace}"

  if kubectl get namespace "${namespace}" >/dev/null 2>&1; then
    echo "Namespace already exists."
  else
    echo "Creating namespace..."
    kubectl create namespace "${namespace}"
  fi

  echo "Enabling Ambient Mode..."

  kubectl label namespace "${namespace}" \
    "${AMBIENT_LABEL}" \
    --overwrite

  mode="$(
    kubectl get namespace "${namespace}" \
      -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
  )"

  if [[ "${mode}" != "ambient" ]]; then
    echo "ERROR: Failed to enroll ${namespace} into Ambient Mode."
    exit 1
  fi

  echo "Ambient Mode enabled: ${namespace}"
done

echo
echo "=========================================="
echo "Ambient enrollment completed"
echo "=========================================="

echo
echo "Enrolled namespaces:"

kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels