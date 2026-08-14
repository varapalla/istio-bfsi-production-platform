#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

SECURITY_DIR="${PHASE_DIR}/security"
RESILIENCE_DIR="${PHASE_DIR}/resilience"
GATEWAYS_DIR="${PHASE_DIR}/gateways"
POLICIES_DIR="${PHASE_DIR}/policies"

PAYMENTS_NAMESPACE="${PAYMENTS_NAMESPACE:-payments}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-istio-ingress}"

JWT_ISSUER="${JWT_ISSUER:-}"

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
# Prerequisites
# ------------------------------------------------------------

log "Verifying required namespaces"

kubectl get namespace "${PAYMENTS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${PAYMENTS_NAMESPACE}' not found"

kubectl get namespace "${INGRESS_NAMESPACE}" >/dev/null 2>&1 || \
  error "Namespace '${INGRESS_NAMESPACE}' not found"

# ------------------------------------------------------------
# Security
# ------------------------------------------------------------

log "Deploying PeerAuthentication"

kubectl apply \
  -f "${SECURITY_DIR}/peer-authentication.yaml"

log "Deploying AuthorizationPolicy"

kubectl apply \
  -f "${SECURITY_DIR}/authorization-policy.yaml"

if [[ -n "${JWT_ISSUER}" ]]; then

  log "Deploying RequestAuthentication"

  sed "s|\${JWT_ISSUER}|${JWT_ISSUER}|g" \
    "${SECURITY_DIR}/request-authentication.yaml" |
    kubectl apply -f -

else

  log "JWT_ISSUER not provided"
  log "Skipping RequestAuthentication"

fi

# ------------------------------------------------------------
# Resilience
# ------------------------------------------------------------

log "Deploying PriorityClass"

kubectl apply \
  -f "${RESILIENCE_DIR}/priority-class.yaml"

log "Deploying payments PodDisruptionBudget"

kubectl apply \
  -f "${RESILIENCE_DIR}/pod-disruption-budget.yaml"

# ------------------------------------------------------------
# Gateway resilience
# ------------------------------------------------------------

log "Deploying ingress Gateway PDB"

kubectl apply \
  -f "${GATEWAYS_DIR}/ingress-pdb.yaml"

log "Deploying egress Gateway PDB"

kubectl apply \
  -f "${GATEWAYS_DIR}/egress-pdb.yaml"

# ------------------------------------------------------------
# Resource governance
# ------------------------------------------------------------

log "Deploying ResourceQuota"

kubectl apply \
  -f "${POLICIES_DIR}/resource-quota.yaml"

log "Deploying LimitRange"

kubectl apply \
  -f "${POLICIES_DIR}/limit-range.yaml"

# ------------------------------------------------------------
# Pod Security Admission
# ------------------------------------------------------------

log "Applying Pod Security Admission labels"

kubectl label namespace "${PAYMENTS_NAMESPACE}" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo

log "Security"

kubectl get peerauthentication \
  -n istio-system

kubectl get authorizationpolicy \
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

log "Phase 8 deployment completed successfully"