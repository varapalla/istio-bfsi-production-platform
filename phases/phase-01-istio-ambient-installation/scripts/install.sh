#!/usr/bin/env bash

set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.30.3}"
ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"

ISTIO_HELM_REPO="https://istio-release.storage.googleapis.com/charts"

echo "=========================================="
echo "Istio Ambient Mode - Installation"
echo "=========================================="
echo "Istio Version : ${ISTIO_VERSION}"
echo "Namespace     : ${ISTIO_NAMESPACE}"
echo "=========================================="

# --------------------------------------------------
# Phase 0 validation
# --------------------------------------------------

echo
echo "==> Checking prerequisites"

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is not installed"
  exit 1
}

command -v helm >/dev/null 2>&1 || {
  echo "ERROR: Helm is not installed"
  exit 1
}

kubectl cluster-info >/dev/null

echo "Prerequisites validated."

# --------------------------------------------------
# Istio Helm repository
# --------------------------------------------------

echo
echo "==> Configuring Istio Helm repository"

if ! helm repo list 2>/dev/null | awk '{print $1}' | grep -qx "istio"; then
  helm repo add istio "${ISTIO_HELM_REPO}"
fi

helm repo update

# --------------------------------------------------
# Istio namespace
# --------------------------------------------------

echo
echo "==> Creating Istio namespace"

kubectl get namespace "${ISTIO_NAMESPACE}" >/dev/null 2>&1 || \
  kubectl create namespace "${ISTIO_NAMESPACE}"

# --------------------------------------------------
# Istio Base
# --------------------------------------------------

echo
echo "==> Installing Istio Base"

helm upgrade --install istio-base istio/base \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --wait

# --------------------------------------------------
# Istiod
# --------------------------------------------------

echo
echo "==> Installing Istiod"

helm upgrade --install istiod istio/istiod \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --values values/istiod-values.yaml \
  --wait

# --------------------------------------------------
# Istio CNI
# --------------------------------------------------

echo
echo "==> Installing Istio CNI"

helm upgrade --install istio-cni istio/cni \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --values values/cni-values.yaml \
  --wait

# --------------------------------------------------
# Ztunnel
# --------------------------------------------------

echo
echo "==> Installing Ztunnel"

helm upgrade --install ztunnel istio/ztunnel \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --values values/ztunnel-values.yaml \
  --wait

# --------------------------------------------------
# Final status
# --------------------------------------------------

echo
echo "=========================================="
echo "Istio Ambient installation completed"
echo "=========================================="

echo
echo "==> Helm releases"

helm list \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Istio workloads"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  --wide