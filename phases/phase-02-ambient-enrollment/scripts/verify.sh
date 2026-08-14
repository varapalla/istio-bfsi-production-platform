#!/usr/bin/env bash

set -euo pipefail

NAMESPACES=(
  "payments"
  "orders"
  "cart"
  "customers"
)

ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"

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
# Namespace summary
# --------------------------------------------------

echo
echo "==> Ambient namespaces"

kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels

# --------------------------------------------------
# Ztunnel verification
# --------------------------------------------------

echo
echo "==> Verifying Ztunnel DaemonSet"

kubectl get daemonset \
  -n "${ISTIO_NAMESPACE}" \
  ztunnel

echo
echo "==> Ztunnel Pods"

kubectl get pods \
  -n "${ISTIO_NAMESPACE}" \
  -l app=ztunnel \
  -o wide

# --------------------------------------------------
# Ztunnel readiness
# --------------------------------------------------

echo
echo "==> Checking Ztunnel readiness"

DESIRED="$(
  kubectl get daemonset ztunnel \
    -n "${ISTIO_NAMESPACE}" \
    -o jsonpath='{.status.desiredNumberScheduled}'
)"

READY="$(
  kubectl get daemonset ztunnel \
    -n "${ISTIO_NAMESPACE}" \
    -o jsonpath='{.status.numberReady}'
)"

echo "Desired Ztunnel Pods : ${DESIRED}"
echo "Ready Ztunnel Pods   : ${READY}"

if [[ "${DESIRED}" != "${READY}" ]]; then
  echo "ERROR: Not all Ztunnel Pods are ready."
  exit 1
fi

# --------------------------------------------------
# Ambient workload configuration
# --------------------------------------------------

echo
echo "==> Ztunnel Ambient workloads"

istioctl ztunnel-config workload

# --------------------------------------------------
# Application workload status
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

  else

    echo "No workloads currently deployed in ${namespace}."

  fi

done

echo
echo "=========================================="
echo "Ambient namespace verification completed"
echo "=========================================="