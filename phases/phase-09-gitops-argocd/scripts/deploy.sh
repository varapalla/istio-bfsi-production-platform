#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"
ARGOCD_CHART="${ARGOCD_CHART:-argo/argo-cd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-}"

ARGOCD_DIR="${PHASE_DIR}/argocd"
PROJECTS_DIR="${PHASE_DIR}/projects"
APPLICATIONS_DIR="${PHASE_DIR}/applications"
APPLICATIONSETS_DIR="${PHASE_DIR}/applicationsets"

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

command -v helm >/dev/null 2>&1 || \
  error "helm is not installed"

command -v kubectl >/dev/null 2>&1 || \
  error "kubectl is not installed"

kubectl cluster-info >/dev/null 2>&1 || \
  error "Unable to connect to Kubernetes cluster"

[[ -f "${ARGOCD_DIR}/values.yaml" ]] || \
  error "Argo CD values.yaml not found"

# ------------------------------------------------------------
# Helm repository
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
# Remove legacy kubectl-managed RBAC ConfigMap
# ------------------------------------------------------------

if kubectl get configmap \
  argocd-rbac-cm \
  -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then

  log "Removing legacy kubectl-managed argocd-rbac-cm"

  kubectl delete configmap \
    argocd-rbac-cm \
    -n "${ARGOCD_NAMESPACE}"

fi

# ------------------------------------------------------------
# Argo CD installation
# ------------------------------------------------------------

log "Installing Argo CD using Helm"

HELM_ARGS=(
  upgrade
  --install
  "${ARGOCD_RELEASE}"
  "${ARGOCD_CHART}"
  --namespace
  "${ARGOCD_NAMESPACE}"
  --values
  "${ARGOCD_DIR}/values.yaml"
  --wait
  --timeout
  10m
)

if [[ -n "${ARGOCD_CHART_VERSION}" ]]; then

  HELM_ARGS+=(
    --version
    "${ARGOCD_CHART_VERSION}"
  )

fi

helm "${HELM_ARGS[@]}"

# ------------------------------------------------------------
# Wait for Argo CD components
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
# Verify Helm-managed RBAC
# ------------------------------------------------------------

log "Verifying Helm-managed Argo CD RBAC"

kubectl get configmap \
  argocd-rbac-cm \
  -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || \
  error "Helm-managed argocd-rbac-cm was not created"

# ------------------------------------------------------------
# BFSI AppProject
# ------------------------------------------------------------

log "Deploying BFSI AppProject"

kubectl apply \
  -f "${PROJECTS_DIR}/bfsi-platform-project.yaml"

# ------------------------------------------------------------
# Repository credentials
# ------------------------------------------------------------

if [[ -n "${GITHUB_USERNAME:-}" && -n "${GITHUB_TOKEN:-}" ]]; then

  log "Configuring Git repository credentials"

  kubectl create secret generic \
    bfsi-platform-repository \
    -n "${ARGOCD_NAMESPACE}" \
    --from-literal=type=git \
    --from-literal=name=bfsi-platform-repository \
    --from-literal=project=bfsi-platform \
    --from-literal=url=https://github.com/varapalla/istio-bfsi-production-platform.git \
    --from-literal=username="${GITHUB_USERNAME}" \
    --from-literal=password="${GITHUB_TOKEN}" \
    --dry-run=client \
    -o yaml |
    kubectl apply -f -

  kubectl label secret \
    bfsi-platform-repository \
    -n "${ARGOCD_NAMESPACE}" \
    argocd.argoproj.io/secret-type=repository \
    --overwrite

else

  log "GitHub credentials not provided"
  log "Skipping repository credential configuration"

fi

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

log "Argo CD Helm release"

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