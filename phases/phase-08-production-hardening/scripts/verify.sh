#!/usr/bin/env bash

set -Eeuo pipefail

PAYMENTS_NAMESPACE="${PAYMENTS_NAMESPACE:-payments}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-istio-ingress}"

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
# Verify namespaces
# ------------------------------------------------------------

log "Verifying payments namespace"

kubectl get namespace "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${PAYMENTS_NAMESPACE}' not found"

log "Verifying ingress namespace"

kubectl get namespace "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${INGRESS_NAMESPACE}' not found"

# ------------------------------------------------------------
# Verify security
# ------------------------------------------------------------

log "Verifying PeerAuthentication"

kubectl get peerauthentication \
  mesh-default \
  -n istio-system >/dev/null 2>&1 || \
  error "PeerAuthentication 'mesh-default' not found"

log "Verifying AuthorizationPolicy"

kubectl get authorizationpolicy \
  payments-authorization \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Payments AuthorizationPolicy not found"

log "Verifying RequestAuthentication"

kubectl get requestauthentication \
  payments-jwt \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "RequestAuthentication 'payments-jwt' not found"

# ------------------------------------------------------------
# Verify resilience
# ------------------------------------------------------------

log "Verifying PriorityClass"

kubectl get priorityclass \
  bfsi-critical >/dev/null 2>&1 || \
  error "PriorityClass 'bfsi-critical' not found"

log "Verifying payments PDB"

kubectl get pdb \
  payments \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Payments PDB not found"

# ------------------------------------------------------------
# Verify gateway PDBs
# ------------------------------------------------------------

log "Verifying ingress Gateway PDB"

kubectl get pdb \
  bfsi-ingress \
  -n "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Ingress Gateway PDB not found"

log "Verifying egress Gateway PDB"

kubectl get pdb \
  payments-egress \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Egress Gateway PDB not found"

# ------------------------------------------------------------
# Verify resource governance
# ------------------------------------------------------------

log "Verifying ResourceQuota"

kubectl get resourcequota \
  payments-quota \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "ResourceQuota not found"

log "Verifying LimitRange"

kubectl get limitrange \
  payments-defaults \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "LimitRange not found"

# ------------------------------------------------------------
# Verify Pod Security Admission
# ------------------------------------------------------------

log "Verifying Pod Security Admission"

ENFORCE_LEVEL="$(
  kubectl get namespace "${PAYMENTS_NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
)"

[[ "${ENFORCE_LEVEL}" == "restricted" ]] || \
  error "Pod Security enforce level is '${ENFORCE_LEVEL}', expected 'restricted'"

# ------------------------------------------------------------
# Verify topology spread
# ------------------------------------------------------------

log "Verifying payments topology spread"

kubectl get deployment payments \
  -n "${PAYMENTS_NAMESPACE}" \
  -o jsonpath='{.spec.template.spec.topologySpreadConstraints[*].topologyKey}' \
  | grep -q 'topology.kubernetes.io/zone' || \
  error "Payments deployment does not have zone topology spread"

# ------------------------------------------------------------
# Display state
# ------------------------------------------------------------

echo

log "Security"

kubectl get peerauthentication \
  -n istio-system

kubectl get authorizationpolicy \
  -n "${PAYMENTS_NAMESPACE}"

kubectl get requestauthentication \
  -n "${PAYMENTS_NAMESPACE}"

echo

log "Resilience"

kubectl get priorityclass bfsi-critical

kubectl get pdb \
  -A

echo

log "Resource Governance"

kubectl get resourcequota \
  -n "${PAYMENTS_NAMESPACE}"

kubectl get limitrange \
  -n "${PAYMENTS_NAMESPACE}"

echo

log "Payments Deployment"

kubectl get deployment payments \
  -n "${PAYMENTS_NAMESPACE}"

echo

log "Phase 8 verification completed successfully"