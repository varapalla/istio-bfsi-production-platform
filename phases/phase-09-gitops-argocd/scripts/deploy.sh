#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ARGOCD_DIR="${PHASE_DIR}/argocd"
PROJECTS_DIR="${PHASE_DIR}/projects"
APPLICATIONS_DIR="${PHASE_DIR}/applications"
APPLICATIONSETS_DIR="${PHASE_DIR}/applicationsets"
POLICIES_DIR="${PHASE_DIR}/policies"

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

[[ -f "${ARGOCD_DIR}/values.yaml" ]] || \
  error "Argo CD values.yaml not found"

# ------------------------------------------------------------
# Argo CD Helm repository
# ------------------------------------------------------------

log "Adding Argo Helm repository"

helm repo add argo \
  https://argoproj.github.io/argo-helm \
  --force-update

helm repo update

# ------------------------------------------------------------
# Namespace
# ------------------------------------------------------------

log "Creating Argo CD namespace"

kubectl create namespace "${ARGOCD_NAMESPACE}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

# ------------------------------------------------------------
# Argo CD
# ------------------------------------------------------------

log "Installing Argo CD using Helm"

helm upgrade --install "${ARGOCD_RELEASE}" \
  argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --values "${ARGOCD_DIR}/values.yaml" \
  --wait \
  --timeout 10m

# ------------------------------------------------------------
# Wait for components
# ------------------------------------------------------------

log "Waiting for Argo CD server"

kubectl rollout status \
  deployment/argocd-server \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=10m

log "Waiting for Argo CD repo server"

kubectl rollout status \
  deployment/argocd-repo-server \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=10m

log "Waiting for Argo CD application controller"

kubectl rollout status \
  statefulset/argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=10m

# ------------------------------------------------------------
# Argo CD project
# ------------------------------------------------------------

log "Deploying BFSI AppProject"

kubectl apply \
  -f "${PROJECTS_DIR}/bfsi-platform-project.yaml"

# ------------------------------------------------------------
# RBAC
# ------------------------------------------------------------

log "Deploying Argo CD RBAC"

kubectl apply \
  -f "${POLICIES_DIR}/argocd-rbac-cm.yaml"

# ------------------------------------------------------------
# Applications
# ------------------------------------------------------------

log "Deploying Istio platform Application"

kubectl apply \
  -f "${APPLICATIONS_DIR}/istio-platform.yaml"

log "Deploying BFSI security Application"

kubectl apply \
  -f "${APPLICATIONS_DIR}/bfsi-security.yaml"

log "Deploying BFSI network Application"

kubectl apply \
  -f "${APPLICATIONS_DIR}/bfsi-network.yaml"

log "Deploying BFSI observability Application"

kubectl apply \
  -f "${APPLICATIONS_DIR}/bfsi-observability.yaml"

# ------------------------------------------------------------
# ApplicationSet
# ------------------------------------------------------------

log "Deploying BFSI ApplicationSet"

kubectl apply \
  -f "${APPLICATIONSETS_DIR}/bfsi-environments.yaml"

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo

log "Helm release"

helm list \
  -n "${ARGOCD_NAMESPACE}"

echo

log "Argo CD pods"

kubectl get pods \
  -n "${ARGOCD_NAMESPACE}"

echo

log "Argo CD Applications"

kubectl get applications \
  -n "${ARGOCD_NAMESPACE}"

echo

log "Argo CD ApplicationSets"

kubectl get applicationsets \
  -n "${ARGOCD_NAMESPACE}"

echo

log "BFSI AppProject"

kubectl get appproject \
  bfsi-platform \
  -n "${ARGOCD_NAMESPACE}"

echo

log "Phase 9 deployment completed successfully"