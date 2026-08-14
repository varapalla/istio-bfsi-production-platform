#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-istio-ingress}"
EGRESS_NAMESPACE="${EGRESS_NAMESPACE:-payments}"

INGRESS_DIR="${PHASE_DIR}/ingress"
EGRESS_DIR="${PHASE_DIR}/egress"

log() {
  printf '[INFO] %s\n' "$*"
}

error() {
  printf '[ERROR] %s\n' "$*" >&2
}

fail() {
  error "$*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

check_prerequisites() {
  log "Checking prerequisites..."

  require_command kubectl
  require_command helm
  require_command istioctl

  kubectl cluster-info >/dev/null 2>&1 \
    || fail "Unable to connect to Kubernetes cluster"

  kubectl get namespace "${ISTIO_NAMESPACE}" >/dev/null 2>&1 \
    || fail "Istio namespace '${ISTIO_NAMESPACE}' does not exist"

  kubectl get gatewayclass istio >/dev/null 2>&1 \
    || fail "Istio GatewayClass 'istio' does not exist"

  log "Prerequisites validated."
}

check_gateway_api() {
  log "Checking Gateway API CRDs..."

  local crd

  for crd in \
    gateways.gateway.networking.k8s.io \
    httproutes.gateway.networking.k8s.io \
    tlsroutes.gateway.networking.k8s.io
  do
    kubectl get crd "${crd}" >/dev/null 2>&1 \
      || fail "Gateway API CRD missing: ${crd}"
  done

  log "Gateway API CRDs validated."
}

validate_manifests() {
  log "Validating Phase 6 manifests..."

  kubectl apply \
    --dry-run=server \
    -f "${INGRESS_DIR}/namespace.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${INGRESS_DIR}/gateway.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${INGRESS_DIR}/http-route.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${INGRESS_DIR}/authorization-policy.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${EGRESS_DIR}/gateway.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${EGRESS_DIR}/service-entry.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${EGRESS_DIR}/tls-route.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${EGRESS_DIR}/authorization-policy.yaml"

  log "Manifest validation completed."
}

deploy_ingress() {
  log "Deploying ingress..."

  kubectl apply \
    -f "${INGRESS_DIR}/namespace.yaml"

  kubectl apply \
    -f "${INGRESS_DIR}/gateway.yaml"

  kubectl apply \
    -f "${INGRESS_DIR}/http-route.yaml"

  kubectl apply \
    -f "${INGRESS_DIR}/authorization-policy.yaml"

  log "Ingress deployment completed."
}

deploy_egress() {
  log "Deploying egress..."

  kubectl apply \
    -f "${EGRESS_DIR}/gateway.yaml"

  kubectl apply \
    -f "${EGRESS_DIR}/service-entry.yaml"

  kubectl apply \
    -f "${EGRESS_DIR}/tls-route.yaml"

  kubectl apply \
    -f "${EGRESS_DIR}/authorization-policy.yaml"

  log "Egress deployment completed."
}

main() {
  log "=========================================="
  log "Phase 6 - Ingress & Egress Deployment"
  log "=========================================="

  check_prerequisites
  check_gateway_api
  validate_manifests

  deploy_ingress
  deploy_egress

  log "=========================================="
  log "Phase 6 Deployment Completed"
  log "=========================================="

  log "Run './scripts/verify.sh' to validate the deployment."
}

main "$@"