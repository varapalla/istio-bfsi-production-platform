#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

TELEMETRY_DIR="${PHASE_DIR}/telemetry"
METRICS_DIR="${PHASE_DIR}/metrics"

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

log "Deploying Istio Telemetry"

kubectl apply \
  -f "${TELEMETRY_DIR}/telemetry.yaml"

log "Deploying access logging configuration"

kubectl apply \
  -f "${TELEMETRY_DIR}/access-logging.yaml"

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then

  log "Prometheus Operator detected"

  kubectl apply \
    -f "${METRICS_DIR}/service-monitor.yaml"

else

  log "Prometheus Operator not detected"
  log "Skipping ServiceMonitor"

fi

echo
log "Telemetry resources"

kubectl get telemetry -A

echo
log "Phase 7 deployment completed successfully"