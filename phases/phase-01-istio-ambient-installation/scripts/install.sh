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

echo
echo "==> Configuring Istio Helm repository"

if ! helm repo list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "istio"; then
  helm repo add istio "${ISTIO_HELM_REPO}"
fi

helm repo update

echo
echo "==> Creating Istio namespace"

kubectl get namespace "${ISTIO_NAMESPACE}" >/dev/null 2>&1 || \
  kubectl create namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Installing Istio Base"

helm upgrade --install istio-base istio/base \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --wait

echo
echo "==> Installing Istiod"

helm upgrade --install istiod istio/istiod \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --values values/istiod-values.yaml \
  --wait

echo
echo "==> Installing Istio CNI"

helm upgrade --install istio-cni istio/cni \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --values values/cni-values.yaml \
  --wait

echo
echo "==> Installing Ztunnel"

helm upgrade --install ztunnel istio/ztunnel \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --values values/ztunnel-values.yaml \
  --wait

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
  -o wide