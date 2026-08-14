#!/usr/bin/env bash

set -Eeuo pipefail

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
# Verify namespaces
# ------------------------------------------------------------

log "Verifying ingress namespace"

kubectl get namespace "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${INGRESS_NAMESPACE}' not found"

log "Verifying application namespace"

kubectl get namespace "${EGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${EGRESS_NAMESPACE}' not found"

# ------------------------------------------------------------
# Verify GatewayClass
# ------------------------------------------------------------

log "Verifying Istio GatewayClass"

kubectl get gatewayclass istio >/dev/null 2>&1 || \
  error "Istio GatewayClass 'istio' not found"

# ------------------------------------------------------------
# Verify ingress
# ------------------------------------------------------------

log "Verifying ingress Gateway"

kubectl get gateway \
  bfsi-ingress \
  -n "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Ingress Gateway 'bfsi-ingress' not found"

log "Verifying ingress HTTPRoute"

kubectl get httproute \
  payments \
  -n "${EGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "HTTPRoute 'payments' not found"

log "Verifying ingress AuthorizationPolicy"

kubectl get authorizationpolicy \
  bfsi-ingress-authorization \
  -n "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Ingress AuthorizationPolicy not found"

# ------------------------------------------------------------
# Verify egress
# ------------------------------------------------------------

log "Verifying egress Gateway"

kubectl get gateway \
  payments-egress \
  -n "${EGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Egress Gateway 'payments-egress' not found"

log "Verifying ServiceEntry"

kubectl get serviceentry \
  payment-provider \
  -n "${EGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "ServiceEntry 'payment-provider' not found"

log "Verifying TLSRoute"

kubectl get tlsroute \
  payment-provider-to-egress \
  -n "${EGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "TLSRoute 'payment-provider-to-egress' not found"

log "Verifying egress AuthorizationPolicy"

kubectl get authorizationpolicy \
  payments-egress-authorization \
  -n "${EGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Egress AuthorizationPolicy not found"

# ------------------------------------------------------------
# Display deployed resources
# ------------------------------------------------------------

echo
log "Ingress Gateway"

kubectl get gateway \
  -n "${INGRESS_NAMESPACE}"

echo
log "HTTPRoutes"

kubectl get httproute \
  -n "${EGRESS_NAMESPACE}"

echo
log "Ingress AuthorizationPolicies"

kubectl get authorizationpolicy \
  -n "${INGRESS_NAMESPACE}"

echo
log "Egress Gateway"

kubectl get gateway \
  -n "${EGRESS_NAMESPACE}"

echo
log "ServiceEntries"

kubectl get serviceentry \
  -n "${EGRESS_NAMESPACE}"

echo
log "TLSRoutes"

kubectl get tlsroute \
  -n "${EGRESS_NAMESPACE}"

echo
log "Egress AuthorizationPolicies"

kubectl get authorizationpolicy \
  -n "${EGRESS_NAMESPACE}"

echo
log "Phase 6 verification completed successfully"