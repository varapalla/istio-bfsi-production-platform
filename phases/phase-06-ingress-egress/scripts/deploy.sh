#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

INGRESS_DIR="${PHASE_DIR}/ingress"
EGRESS_DIR="${PHASE_DIR}/egress"

INGRESS_NAMESPACE="istio-ingress"
EGRESS_NAMESPACE="payments"

log() {
  echo "==> $*"
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

# ------------------------------------------------------------
# Prerequisites
# ------------------------------------------------------------

command -v kubectl >/dev/null 2>&1 || \
  error "kubectl is not installed"

kubectl cluster-info >/dev/null 2>&1 || \
  error "Unable to connect to Kubernetes cluster"

# ------------------------------------------------------------
# Verify required namespaces
# ------------------------------------------------------------

log "Verifying application namespace: ${EGRESS_NAMESPACE}"

kubectl get namespace "${EGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Required namespace '${EGRESS_NAMESPACE}' does not exist"

# ------------------------------------------------------------
# Deploy ingress namespace
# ------------------------------------------------------------

log "Deploying ingress namespace"

kubectl apply \
  -f "${INGRESS_DIR}/namespace.yaml"

kubectl get namespace "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${INGRESS_NAMESPACE}' was not created"

# ------------------------------------------------------------
# Deploy ingress
# ------------------------------------------------------------

log "Deploying ingress Gateway"

kubectl apply \
  -f "${INGRESS_DIR}/gateway.yaml"

log "Deploying ingress HTTPRoute"

kubectl apply \
  -f "${INGRESS_DIR}/http-route.yaml"

log "Deploying ingress AuthorizationPolicy"

kubectl apply \
  -f "${INGRESS_DIR}/authorization-policy.yaml"

# ------------------------------------------------------------
# Deploy egress
# ------------------------------------------------------------

log "Deploying egress Gateway"

kubectl apply \
  -f "${EGRESS_DIR}/gateway.yaml"

log "Deploying egress ServiceEntry"

kubectl apply \
  -f "${EGRESS_DIR}/service-entry.yaml"

log "Deploying egress TLSRoute"

kubectl apply \
  -f "${EGRESS_DIR}/tls-route.yaml"

log "Deploying egress AuthorizationPolicy"

kubectl apply \
  -f "${EGRESS_DIR}/authorization-policy.yaml"

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
log "Ingress resources"

kubectl get gateway \
  -n "${INGRESS_NAMESPACE}"

kubectl get httproute \
  -n "${EGRESS_NAMESPACE}"

echo
log "Egress resources"

kubectl get gateway \
  -n "${EGRESS_NAMESPACE}"

kubectl get serviceentry \
  -n "${EGRESS_NAMESPACE}"

kubectl get tlsroute \
  -n "${EGRESS_NAMESPACE}"

echo
log "Phase 6 deployment completed successfully"