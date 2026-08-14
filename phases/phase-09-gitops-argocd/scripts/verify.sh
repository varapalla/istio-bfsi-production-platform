#!/usr/bin/env bash

set -Eeuo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"

log() {
  echo "==> $*"
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v helm >/dev/null 2>&1 || \
  error "helm is not installed"

command -v kubectl >/dev/null 2>&1 || \
  error "kubectl is not installed"

kubectl cluster-info >/dev/null 2>&1 || \
  error "Unable to connect to Kubernetes cluster"

# ------------------------------------------------------------
# Namespace
# ------------------------------------------------------------

log "Verifying Argo CD namespace"

kubectl get namespace \
  "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || \
  error "Argo CD namespace not found"

# ------------------------------------------------------------
# Helm release
# ------------------------------------------------------------

log "Verifying Argo CD Helm release"

helm status \
  "${ARGOCD_RELEASE}" \
  -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || \
  error "Argo CD Helm release not found"

helm status \
  "${ARGOCD_RELEASE}" \
  -n "${ARGOCD_NAMESPACE}"

# ------------------------------------------------------------
# Pods
# ------------------------------------------------------------

log "Verifying Argo CD pods"

kubectl get pods \
  -n "${ARGOCD_NAMESPACE}"

# ------------------------------------------------------------
# Deployments
# ------------------------------------------------------------

log "Verifying Argo CD deployments"

kubectl get deployment \
  -n "${ARGOCD_NAMESPACE}"

kubectl rollout status \
  deployment/argocd-server \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=60s

kubectl rollout status \
  deployment/argocd-repo-server \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=60s

# ------------------------------------------------------------
# Application Controller
# ------------------------------------------------------------

log "Verifying application controller"

kubectl rollout status \
  statefulset/argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=60s

# ------------------------------------------------------------
# Argo CD CRDs
# ------------------------------------------------------------

log "Verifying Argo CD CRDs"

for crd in \
  applications.argoproj.io \
  applicationsets.argoproj.io \
  appprojects.argoproj.io
do
  kubectl get crd "${crd}" >/dev/null 2>&1 || \
    error "Argo CD CRD '${crd}' not found"
done

# ------------------------------------------------------------
# AppProject
# ------------------------------------------------------------

log "Verifying BFSI AppProject"

kubectl get appproject \
  bfsi-platform \
  -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || \
  error "BFSI AppProject not found"

kubectl get appproject \
  bfsi-platform \
  -n "${ARGOCD_NAMESPACE}"

# ------------------------------------------------------------
# Applications
# ------------------------------------------------------------

log "Verifying Argo CD Applications"

for application in \
  istio-platform \
  bfsi-security \
  bfsi-network \
  bfsi-observability
do

  kubectl get application \
    "${application}" \
    -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || \
    error "Application '${application}' not found"

done

kubectl get applications \
  -n "${ARGOCD_NAMESPACE}"

# ------------------------------------------------------------
# ApplicationSet
# ------------------------------------------------------------

log "Verifying ApplicationSet"

kubectl get applicationset \
  bfsi-environments \
  -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || \
  error "ApplicationSet 'bfsi-environments' not found"

kubectl get applicationsets \
  -n "${ARGOCD_NAMESPACE}"

# ------------------------------------------------------------
# RBAC
# ------------------------------------------------------------

log "Verifying Argo CD RBAC"

kubectl get configmap \
  argocd-rbac-cm \
  -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || \
  error "argocd-rbac-cm not found"

# ------------------------------------------------------------
# Services
# ------------------------------------------------------------

log "Verifying Argo CD services"

kubectl get svc \
  -n "${ARGOCD_NAMESPACE}"

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------

echo

log "Phase 9 verification completed successfully"