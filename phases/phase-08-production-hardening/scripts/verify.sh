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

log "Verifying payments namespace"

kubectl get namespace \
  "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${PAYMENTS_NAMESPACE}' not found"

log "Verifying ingress namespace"

kubectl get namespace \
  "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${INGRESS_NAMESPACE}' not found"

# ------------------------------------------------------------
# Verify PeerAuthentication
# ------------------------------------------------------------

log "Verifying PeerAuthentication"

kubectl get peerauthentication \
  mesh-default \
  -n istio-system >/dev/null 2>&1 || \
  error "PeerAuthentication 'mesh-default' not found"

# Verify STRICT mTLS

MTLS_MODE="$(
  kubectl get peerauthentication \
    mesh-default \
    -n istio-system \
    -o jsonpath='{.spec.mtls.mode}'
)"

[[ "${MTLS_MODE}" == "STRICT" ]] || \
  error "PeerAuthentication mode is '${MTLS_MODE}', expected 'STRICT'"

# ------------------------------------------------------------
# Verify AuthorizationPolicy
# ------------------------------------------------------------

log "Verifying AuthorizationPolicy"

kubectl get authorizationpolicy \
  payments-authorization \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "AuthorizationPolicy 'payments-authorization' not found"

# ------------------------------------------------------------
# Verify RequestAuthentication
# ------------------------------------------------------------

if kubectl get requestauthentication \
  payments-jwt \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1; then

  log "RequestAuthentication found"

else

  log "RequestAuthentication not configured"

fi

# ------------------------------------------------------------
# Verify PriorityClass
# ------------------------------------------------------------

log "Verifying PriorityClass"

kubectl get priorityclass \
  bfsi-critical >/dev/null 2>&1 || \
  error "PriorityClass 'bfsi-critical' not found"

# ------------------------------------------------------------
# Verify payments PDB
# ------------------------------------------------------------

log "Verifying payments PodDisruptionBudget"

kubectl get pdb \
  payments \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Payments PDB not found"

# ------------------------------------------------------------
# Verify ingress Gateway PDB
# ------------------------------------------------------------

log "Verifying ingress Gateway PDB"

kubectl get pdb \
  bfsi-ingress \
  -n "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Ingress Gateway PDB 'bfsi-ingress' not found"

# ------------------------------------------------------------
# Verify egress Gateway PDB
# ------------------------------------------------------------

log "Verifying egress Gateway PDB"

kubectl get pdb \
  payments-egress \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Egress Gateway PDB 'payments-egress' not found"

# ------------------------------------------------------------
# Verify ResourceQuota
# ------------------------------------------------------------

log "Verifying ResourceQuota"

kubectl get resourcequota \
  payments-quota \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "ResourceQuota 'payments-quota' not found"

# ------------------------------------------------------------
# Verify LimitRange
# ------------------------------------------------------------

log "Verifying LimitRange"

kubectl get limitrange \
  payments-defaults \
  -n "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "LimitRange 'payments-defaults' not found"

# ------------------------------------------------------------
# Verify Pod Security Admission
# ------------------------------------------------------------

log "Verifying Pod Security Admission"

PSA_AUDIT="$(
  kubectl get namespace \
    "${PAYMENTS_NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}'
)"

PSA_WARN="$(
  kubectl get namespace \
    "${PAYMENTS_NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}'
)"

[[ "${PSA_AUDIT}" == "restricted" ]] || \
  error "Pod Security audit level is '${PSA_AUDIT}', expected 'restricted'"

[[ "${PSA_WARN}" == "restricted" ]] || \
  error "Pod Security warn level is '${PSA_WARN}', expected 'restricted'"

# ------------------------------------------------------------
# Verify enforcement is not enabled by Phase 8
# ------------------------------------------------------------

PSA_ENFORCE="$(
  kubectl get namespace \
    "${PAYMENTS_NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
)"

if [[ -n "${PSA_ENFORCE}" ]]; then
  error "Pod Security enforce label is '${PSA_ENFORCE}'. Phase 8 expects audit/warn only."
fi

# ------------------------------------------------------------
# Display Security state
# ------------------------------------------------------------

echo

log "Security"

kubectl get peerauthentication \
  -n istio-system

kubectl get authorizationpolicy \
  -n "${PAYMENTS_NAMESPACE}"

kubectl get requestauthentication \
  -n "${PAYMENTS_NAMESPACE}" \
  --ignore-not-found

# ------------------------------------------------------------
# Display Resilience state
# ------------------------------------------------------------

echo

log "Resilience"

kubectl get priorityclass \
  bfsi-critical

kubectl get pdb \
  -A

# ------------------------------------------------------------
# Display Resource Governance
# ------------------------------------------------------------

echo

log "Resource Governance"

kubectl get resourcequota \
  -n "${PAYMENTS_NAMESPACE}"

kubectl get limitrange \
  -n "${PAYMENTS_NAMESPACE}"

# ------------------------------------------------------------
# Display Pod Security
# ------------------------------------------------------------

echo

log "Pod Security"

kubectl get namespace \
  "${PAYMENTS_NAMESPACE}" \
  --show-labels

# ------------------------------------------------------------
# Final result
# ------------------------------------------------------------

echo

log "Phase 8 verification completed successfully"