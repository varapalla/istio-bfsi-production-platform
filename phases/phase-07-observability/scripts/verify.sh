#!/usr/bin/env bash

set -Eeuo pipefail

PROMETHEUS_NAMESPACE="${PROMETHEUS_NAMESPACE:-monitoring}"

log() {
  echo "==> $*"
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v kubectl >/dev/null 2>&1 || \
  error "kubectl is not installed"

kubectl cluster-info >/dev/null 2>&1 || \
  error "Unable to connect to Kubernetes cluster"

# ------------------------------------------------------------
# Verify Telemetry CRD
# ------------------------------------------------------------

log "Verifying Telemetry CRD"

kubectl get crd telemetry.istio.io >/dev/null 2>&1 || \
  error "Istio Telemetry CRD not found"

# ------------------------------------------------------------
# Verify Telemetry
# ------------------------------------------------------------

log "Verifying Telemetry resources"

kubectl get telemetry -A

# ------------------------------------------------------------
# Verify access logging
# ------------------------------------------------------------

log "Verifying access logging configuration"

kubectl get telemetry \
  -A \
  -o yaml | grep -q "accessLogging" || \
  error "Access logging configuration not found"

# ------------------------------------------------------------
# Verify Prometheus Operator
# ------------------------------------------------------------

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then

  log "Prometheus Operator detected"

  kubectl get servicemonitor -A

  kubectl get servicemonitor \
    -A \
    -o name | grep -q . || \
    error "No ServiceMonitor resources found"

else

  log "Prometheus Operator not installed"
  log "ServiceMonitor verification skipped"

fi

# ------------------------------------------------------------
# Verify Istio metrics endpoints
# ------------------------------------------------------------

log "Verifying Istio system pods"

kubectl get pods \
  -n istio-system

# ------------------------------------------------------------
# Verify ztunnel
# ------------------------------------------------------------

log "Verifying ztunnel"

kubectl get pods \
  -n istio-system \
  -l app=ztunnel

# ------------------------------------------------------------
# Verify gateways
# ------------------------------------------------------------

if kubectl get namespace istio-ingress >/dev/null 2>&1; then

  log "Verifying ingress gateway"

  kubectl get pods \
    -n istio-ingress

fi

if kubectl get namespace payments >/dev/null 2>&1; then

  log "Verifying payments namespace"

  kubectl get pods \
    -n payments

fi

echo
log "Phase 7 verification completed successfully"