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
  command -v "$1" >/dev/null 2>&1 \
    || fail "Required command not found: $1"
}

check_prerequisites() {
  log "Checking prerequisites..."

  require_command kubectl
  require_command helm
  require_command istioctl

  kubectl cluster-info >/dev/null 2>&1 \
    || fail "Unable to connect to Kubernetes cluster"

  kubectl get namespace "${ISTIO_NAMESPACE}" >/dev/null 2>&1 \
    || fail "Istio namespace '${ISTIO_NAMESPACE}' not found"

  kubectl get gatewayclass istio >/dev/null 2>&1 \
    || fail "Istio GatewayClass 'istio' not found"

  kubectl get namespace "${EGRESS_NAMESPACE}" >/dev/null 2>&1 \
    || fail "Application namespace '${EGRESS_NAMESPACE}' not found"

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

create_ingress_namespace() {
  log "Creating ingress namespace..."

  kubectl apply \
    -f "${INGRESS_DIR}/namespace.yaml"

  kubectl wait \
    --for=jsonpath='{.status.phase}'=Active \
    "namespace/${INGRESS_NAMESPACE}" \
    --timeout=60s

  log "Namespace '${INGRESS_NAMESPACE}' is Active."
}

validate_ingress_manifests() {
  log "Validating ingress manifests..."

  kubectl apply \
    --dry-run=server \
    -f "${INGRESS_DIR}/gateway.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${INGRESS_DIR}/http-route.yaml"

  kubectl apply \
    --dry-run=server \
    -f "${INGRESS_DIR}/authorization-policy.yaml"

  log "Ingress manifests validated."
}

validate_egress_manifests() {
  log "Validating egress manifests..."

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

  log "Egress manifests validated."
}

deploy_ingress() {
  log "Deploying ingress Gateway..."

  kubectl apply \
    -f "${INGRESS_DIR}/gateway.yaml"

  log "Deploying ingress HTTPRoute..."

  kubectl apply \
    -f "${INGRESS_DIR}/http-route.yaml"

  log "Deploying ingress AuthorizationPolicy..."

  kubectl apply \
    -f "${INGRESS_DIR}/authorization-policy.yaml"

  log "Ingress deployment completed."
}

deploy_egress() {
  log "Deploying egress Gateway..."

  kubectl apply \
    -f "${EGRESS_DIR}/gateway.yaml"

  log "Deploying ServiceEntry..."

  kubectl apply \
    -f "${EGRESS_DIR}/service-entry.yaml"

  log "Deploying TLSRoute..."

  kubectl apply \
    -f "${EGRESS_DIR}/tls-route.yaml"

  log "Deploying egress AuthorizationPolicy..."

  kubectl apply \
    -f "${EGRESS_DIR}/authorization-policy.yaml"

  log "Egress deployment completed."
}

main() {
  log "=========================================="
  log "Phase 6 - Ingress & Egress Deployment"
  log "=========================================="

  # 1. Validate cluster and Istio prerequisites
  check_prerequisites

  # 2. Validate Gateway API
  check_gateway_api

  # 3. Namespace MUST exist before server-side validation
  create_ingress_namespace

  # 4. Now server-side validation can safely happen
  validate_ingress_manifests
  validate_egress_manifests

  # 5. Deploy resources
  deploy_ingress
  deploy_egress

  log "=========================================="
  log "Phase 6 Deployment Completed"
  log "=========================================="

  log "Run './scripts/verify.sh' to validate the deployment."
}

main "$@"