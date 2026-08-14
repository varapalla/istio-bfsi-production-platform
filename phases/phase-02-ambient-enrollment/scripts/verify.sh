#!/usr/bin/env bash

set -euo pipefail

NAMESPACES=(
  "payments"
  "orders"
  "cart"
  "customers"
)

echo "=========================================="
echo "Istio Ambient Namespace Verification"
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
# Namespace verification
# --------------------------------------------------

echo
echo "==> Verifying Ambient namespaces"

for namespace in "${NAMESPACES[@]}"; do
  echo
  echo "Checking: ${namespace}"

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
    echo "Current mode: ${mode:-not-set}"
    exit 1
  fi

  echo "Ambient Mode: enabled"
done

# --------------------------------------------------
# Ztunnel verification
# --------------------------------------------------

echo
echo "==> Verifying Ztunnel"

kubectl get daemonset \
  -n istio-system \
  ztunnel

kubectl get pods \
  -n istio-system \
  -l app=ztunnel \
  -o wide

# --------------------------------------------------
# Ambient workload verification
# --------------------------------------------------

echo
echo "==> Ztunnel Ambient workloads"

istioctl ztunnel-config workloads

# --------------------------------------------------
# Namespace workload discovery
# --------------------------------------------------

for namespace in "${NAMESPACES[@]}"; do
  echo
  echo "==> Checking workloads for: ${namespace}"

  if kubectl get pods \
      -n "${namespace}" \
      --no-headers 2>/dev/null | grep -q .; then

    kubectl get pods \
      -n "${namespace}" \
      -o wide

    if istioctl ztunnel-config workloads | grep -q "${namespace}"; then
      echo "Ztunnel workload detected: ${namespace}"
    else
      echo "WARNING: No workload currently detected by Ztunnel in ${namespace}."
    fi
  else
    echo "No workloads currently deployed in ${namespace}."
  fi
done

# --------------------------------------------------
# Endpoint verification
# --------------------------------------------------

echo
echo "==> Ztunnel endpoints"

istioctl ztunnel-config endpoints

echo
echo "=========================================="
echo "Ambient namespace verification completed"
echo "=========================================="