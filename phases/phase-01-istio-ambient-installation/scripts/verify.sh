#!/usr/bin/env bash

set -euo pipefail

ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"

echo "=========================================="
echo "Istio Ambient Mode - Verification"
echo "=========================================="

# --------------------------------------------------
# Kubernetes
# --------------------------------------------------

echo
echo "==> Kubernetes connectivity"

kubectl cluster-info

# --------------------------------------------------
# Helm releases
# --------------------------------------------------

echo
echo "==> Istio Helm releases"

helm list \
  --namespace "${ISTIO_NAMESPACE}"

# --------------------------------------------------
# Pods
# --------------------------------------------------

echo
echo "==> Istio pods"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  --wide

# --------------------------------------------------
# Deployments
# --------------------------------------------------

echo
echo "==> Istio deployments"

kubectl get deployments \
  --namespace "${ISTIO_NAMESPACE}"

# --------------------------------------------------
# DaemonSets
# --------------------------------------------------

echo
echo "==> Istio DaemonSets"

kubectl get daemonsets \
  --namespace "${ISTIO_NAMESPACE}"

# --------------------------------------------------
# Istiod
# --------------------------------------------------

echo
echo "==> Istiod"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  -l app=istiod

# --------------------------------------------------
# Istio CNI
# --------------------------------------------------

echo
echo "==> Istio CNI"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  -l k8s-app=istio-cni-node

# --------------------------------------------------
# Ztunnel
# --------------------------------------------------

echo
echo "==> Ztunnel"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  -l app=ztunnel \
  --wide

# --------------------------------------------------
# Istio version
# --------------------------------------------------

echo
echo "==> Istio version"

istioctl version

# --------------------------------------------------
# Istio precheck
# --------------------------------------------------

echo
echo "==> Istio precheck"

istioctl x precheck

# --------------------------------------------------
# Installation verification
# --------------------------------------------------

echo
echo "==> Istio installation verification"

istioctl verify-install

# --------------------------------------------------
# Ztunnel configuration
# --------------------------------------------------

echo
echo "==> Ztunnel workloads"

istioctl ztunnel-config workloads

echo
echo "=========================================="
echo "Istio Ambient verification completed"
echo "=========================================="