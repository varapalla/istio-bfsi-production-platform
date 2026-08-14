#!/usr/bin/env bash

set -euo pipefail

ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"

echo "=========================================="
echo "Istio Ambient Mode - Verification"
echo "=========================================="

echo
echo "==> Kubernetes connectivity"

kubectl cluster-info

echo
echo "==> Istio version"

istioctl version

echo
echo "==> Istio precheck"

istioctl x precheck

echo
echo "==> Istio Helm releases"

helm list \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Istio Base"

helm status istio-base \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Istiod"

helm status istiod \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Istio CNI"

helm status istio-cni \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Ztunnel"

helm status ztunnel \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Istio pods"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  -o wide

echo
echo "==> Istio deployments"

kubectl get deployments \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Istio DaemonSets"

kubectl get daemonsets \
  --namespace "${ISTIO_NAMESPACE}"

echo
echo "==> Istiod pods"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  -l app=istiod

echo
echo "==> Istio CNI pods"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  -l k8s-app=istio-cni-node

echo
echo "==> Ztunnel pods"

kubectl get pods \
  --namespace "${ISTIO_NAMESPACE}" \
  -l app=ztunnel \
  -o wide

echo
echo "==> Ztunnel workloads"

istioctl ztunnel-config workloads

echo
echo "=========================================="
echo "Istio Ambient verification completed"
echo "=========================================="