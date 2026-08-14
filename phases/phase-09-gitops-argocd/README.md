# Phase 9 — GitOps with Argo CD

## 1. Objective

This phase implements production-grade GitOps using Argo CD for the Istio Ambient BFSI platform.

The objective is to establish Git as the single source of truth for Kubernetes, Istio, security, networking, and observability configuration.

This phase introduces:

- Argo CD installation using Helm
- Argo CD RBAC
- Dedicated BFSI AppProject
- Git repository integration
- Argo CD Applications
- ApplicationSet for environment-based deployments
- Automated synchronization
- Self-healing
- GitOps drift detection
- Production deployment and verification

---

## 2. Architecture

```text
                    GitHub
                       |
                       v
        istio-bfsi-production-platform
                       |
                       v
                +-------------+
                |   Argo CD   |
                +-------------+
                       |
                Reconciliation
                       |
                       v
                Kubernetes API
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
   Istio Platform   BFSI Security   Network
        |              |              |
        +--------------+--------------+
                       |
                       v
                BFSI Applications
```

### GitOps Flow

```text
Developer
    |
    v
Feature Branch
    |
    v
Pull Request
    |
    v
Code Review
    |
    v
Protected Main
    |
    v
Argo CD
    |
    v
Kubernetes
    |
    v
Istio Ambient
    |
    v
BFSI Applications
```

---

## 3. Scope

### Included

- Argo CD installation using Helm
- Argo CD configuration
- Argo CD RBAC
- BFSI AppProject
- Git repository configuration
- Argo CD Applications
- ApplicationSet
- Automated synchronization
- Self-healing
- GitOps drift detection
- Deployment script
- Verification script

### Not Included

- CI pipeline implementation
- Container image building
- Kubernetes cluster provisioning
- AWS infrastructure provisioning
- Application source code
- Enterprise SSO implementation

---

## 4. Repository Structure

```text
phase-09-gitops-argocd/
├── README.md
├── argocd/
│   └── values.yaml
├── projects/
│   └── bfsi-platform-project.yaml
├── repositories/
│   └── repository-secret.yaml
├── applications/
│   ├── istio-platform.yaml
│   ├── bfsi-security.yaml
│   ├── bfsi-network.yaml
│   ├── bfsi-observability.yaml
│   └── bfsi-environments.yaml
├── applicationsets/
│   └── bfsi-environments.yaml
└── scripts/
    ├── deploy.sh
    └── verify.sh
```

---

## 5. Prerequisites

Verify Kubernetes:

```bash
kubectl version --client
kubectl cluster-info
kubectl get nodes
```

Verify Helm:

```bash
helm version
```

Verify Git:

```bash
git --version
```

Optional Argo CD CLI:

```bash
argocd version --client
```

---

## 6. Verify Previous Phases

Verify the platform phases:

```bash
ls phases/
```

Expected:

```text
phase-00-prerequisites
phase-01-istio-ambient-installation
phase-02-ambient-enrollment
phase-03-waypoints
phase-04-security
phase-05-network-policy
phase-06-ingress-egress
phase-07-observability
phase-08-production-hardening
phase-09-gitops-argocd
```

Phase 9 uses the configuration created by the previous phases.

---

## 7. Argo CD Configuration

Argo CD Helm configuration is maintained in:

```text
argocd/values.yaml
```

The configuration provides:

- RBAC enabled
- Anonymous access disabled
- Argo CD exec disabled
- Status badges enabled
- Read-only default role
- Platform administrator role
- Two Argo CD server replicas
- Two repository server replicas
- Two ApplicationSet replicas

Argo CD configuration is managed through Git.

---

## 8. Argo CD RBAC

The default policy is:

```text
role:readonly
```

A dedicated platform administrator role is defined:

```text
role:platform-admin
```

Administrator group:

```text
argocd-admins
```

Production environments should integrate this group with the enterprise identity provider through SSO.

Shared administrator credentials should not be used for production operations.

---

## 9. BFSI AppProject

The platform uses a dedicated Argo CD project:

```text
bfsi-platform
```

Manifest:

```text
projects/bfsi-platform-project.yaml
```

The AppProject provides a security boundary for the BFSI platform.

### Source Repository

```text
https://github.com/varapalla/istio-bfsi-production-platform.git
```

### Allowed Destinations

```text
istio-system
istio-ingress
payments
orders
cart
monitoring
```

### Allowed Cluster Resources

```text
Namespace
ClusterRole
ClusterRoleBinding
CustomResourceDefinition
```

The AppProject prevents applications from deploying into arbitrary namespaces.

---

## 10. Argo CD Applications

The following Applications are defined.

### 10.1 Istio Platform

Manifest:

```text
applications/istio-platform.yaml
```

Purpose:

```text
Istio Ambient platform configuration
```

Target namespace:

```text
istio-system
```

### 10.2 BFSI Security

Manifest:

```text
applications/bfsi-security.yaml
```

Purpose:

```text
mTLS
Authorization
Security policies
```

### 10.3 BFSI Network

Manifest:

```text
applications/bfsi-network.yaml
```

Purpose:

```text
Kubernetes NetworkPolicy
Network isolation
Namespace-level network security
```

### 10.4 BFSI Observability

Manifest:

```text
applications/bfsi-observability.yaml
```

Purpose:

```text
Metrics
Logging
Tracing
Observability configuration
```

---

## 11. Synchronization Policy

Applications use automated synchronization:

```yaml
syncPolicy:
  automated:
    selfHeal: true
    prune: false
```

### Self-Healing

Self-healing is enabled:

```yaml
selfHeal: true
```

If a Git-managed resource is manually changed in Kubernetes, Argo CD detects the drift and reconciles the resource toward the Git-defined state.

```text
Git Desired State
       |
       v
Kubernetes Live State
       |
       v
Manual Change
       |
       v
Argo CD Detects Drift
       |
       v
Self-Healing
       |
       v
Git State Restored
```

### Pruning

Pruning is intentionally disabled:

```yaml
prune: false
```

This is a production safety control.

Removing a resource from Git should not automatically delete the live production resource unless an explicit pruning strategy has been approved.

---

## 12. ApplicationSet

ApplicationSet is defined in:

```text
applicationsets/bfsi-environments.yaml
```

The current generator expects:

```text
environments/*
```

The intended environment structure is:

```text
environments/
├── dev/
├── sit/
├── stage/
└── prod/
```

ApplicationSet generates environment-specific Applications:

```text
bfsi-dev
bfsi-sit
bfsi-stage
bfsi-prod
```

This avoids maintaining separate Application manifests for every environment.

---

## 13. ApplicationSet Prerequisite

Before expecting generated environment Applications, verify:

```bash
ls -la environments/
```

And:

```bash
find environments -maxdepth 2 -type f
```

The ApplicationSet currently uses:

```text
environments/*
```

Therefore the environment directories must exist before generated environment Applications can be expected.

Do not consider environment GitOps successful merely because the ApplicationSet resource exists.

---

## 14. Repository Credentials

For a private Git repository, configure credentials through environment variables:

```bash
export GITHUB_USERNAME="<github-user>"
export GITHUB_TOKEN="<github-token>"
```

Then run:

```bash
./scripts/deploy.sh
```

Never commit credentials to Git.

Do not store the following in repository manifests:

```text
GitHub PAT
SSH private key
Passwords
AWS credentials
Cloud credentials
```

For enterprise production, prefer short-lived authentication mechanisms such as GitHub App authentication or enterprise identity integration where supported.

---

## 15. Deploy Phase 9

Change to the Phase 9 directory:

```bash
cd phases/phase-09-gitops-argocd
```

Make scripts executable:

```bash
chmod +x scripts/deploy.sh
chmod +x scripts/verify.sh
```

Run deployment:

```bash
./scripts/deploy.sh
```

---

## 16. Deployment Flow

The deployment script performs:

```text
1. Validate prerequisites
        |
        v
2. Add Argo Helm repository
        |
        v
3. Create argocd namespace
        |
        v
4. Install / upgrade Argo CD
        |
        v
5. Wait for Argo CD components
        |
        v
6. Deploy BFSI AppProject
        |
        v
7. Configure Git repository
        |
        v
8. Deploy Applications
        |
        v
9. Deploy ApplicationSet
        |
        v
10. Display deployment status
```

---

## 17. Verify Argo CD Installation

Check namespace:

```bash
kubectl get namespace argocd
```

Check pods:

```bash
kubectl get pods -n argocd
```

Check deployments:

```bash
kubectl get deployments -n argocd
```

Check StatefulSets:

```bash
kubectl get statefulsets -n argocd
```

Check Helm release:

```bash
helm list -n argocd
```

---

## 18. Verify Argo CD Components

### Argo CD Server

```bash
kubectl rollout status \
  deployment/argocd-server \
  -n argocd \
  --timeout=10m
```

### Repository Server

```bash
kubectl rollout status \
  deployment/argocd-repo-server \
  -n argocd \
  --timeout=10m
```

### Application Controller

```bash
kubectl rollout status \
  statefulset/argocd-application-controller \
  -n argocd \
  --timeout=10m
```

---

## 19. Verify AppProject

```bash
kubectl get appproject \
  bfsi-platform \
  -n argocd
```

Detailed:

```bash
kubectl describe appproject \
  bfsi-platform \
  -n argocd
```

---

## 20. Verify Applications

```bash
kubectl get applications \
  -n argocd
```

Detailed:

```bash
kubectl get applications \
  -n argocd \
  -o wide
```

Inspect an Application:

```bash
kubectl describe application \
  istio-platform \
  -n argocd
```

---

## 21. Verify ApplicationSet

```bash
kubectl get applicationsets \
  -n argocd
```

Inspect:

```bash
kubectl describe applicationset \
  bfsi-environments \
  -n argocd
```

Check generated Applications:

```bash
kubectl get applications \
  -n argocd
```

---

## 22. Run Verification Script

Execute:

```bash
./scripts/verify.sh
```

The verification script validates:

```text
Kubernetes connectivity
Argo CD namespace
Argo CD pods
Argo CD deployments
Argo CD controller
AppProject
Applications
ApplicationSets
GitOps resources
```

---

## 23. Argo CD CLI Validation

List Applications:

```bash
argocd app list
```

Inspect an Application:

```bash
argocd app get istio-platform
```

Expected healthy state:

```text
Sync Status:   Synced
Health Status: Healthy
```

---

## 24. GitOps Drift Validation

GitOps must detect configuration drift.

Expected flow:

```text
Git Desired State
       |
       v
Kubernetes Live State
       |
       v
Manual Configuration Change
       |
       v
Argo CD Detects Drift
       |
       v
Application OutOfSync
       |
       v
Self-Healing
       |
       v
Git Desired State Restored
```

Verify:

```bash
argocd app get istio-platform
```

---

## 25. Git Change Validation

Make a controlled configuration change through Git.

Check:

```bash
git status
```

After making the change:

```bash
git add .
git commit -m "gitops: update platform configuration"
git push origin main
```

Verify Argo CD detects the new Git revision:

```bash
argocd app list
```

Then:

```bash
argocd app get istio-platform
```

---

## 26. Production GitOps Workflow

The production deployment model is:

```text
Developer
    |
    v
Feature Branch
    |
    v
Pull Request
    |
    +---- CI
    |      |
    |      +-- Build
    |      +-- Test
    |      +-- Security Scan
    |      +-- Manifest Validation
    |
    v
Code Review
    |
    v
Protected Branch
    |
    v
Argo CD
    |
    v
Kubernetes
```

Normal production deployments should not be performed by engineers directly running:

```bash
kubectl apply
```

against production.

Preferred model:

```text
Git
 |
 v
Argo CD
 |
 v
Kubernetes
```

---

## 27. CI vs CD Responsibilities

### CI

CI is responsible for:

```text
Build
Test
Lint
Security Scan
Image Build
Image Scan
Artifact Publication
Manifest Validation
```

### CD / GitOps

Argo CD is responsible for:

```text
Deployment
Reconciliation
Drift Detection
Self-Healing
Application Health
Desired-State Management
```

This provides clear separation between CI and CD responsibilities.

---

## 28. Troubleshooting

### Argo CD Pods Not Ready

```bash
kubectl get pods -n argocd
```

Inspect:

```bash
kubectl describe pod <pod-name> -n argocd
```

Logs:

```bash
kubectl logs \
  -n argocd \
  <pod-name>
```

---

### Application OutOfSync

```bash
argocd app get <application>
```

Then:

```bash
kubectl describe application \
  <application> \
  -n argocd
```

Check:

```text
repoURL
targetRevision
path
destination
project
```

---

### Application Not Found

```bash
kubectl get applications \
  -n argocd
```

Check ApplicationSet:

```bash
kubectl get applicationsets \
  -n argocd
```

---

### ApplicationSet Not Generating Applications

```bash
kubectl describe applicationset \
  bfsi-environments \
  -n argocd
```

Verify:

```bash
find environments -maxdepth 2 -type f
```

Confirm:

```text
environments/*
```

exists and is accessible from the configured Git revision.

---

### Repository Authentication Failure

Check:

```bash
kubectl get secrets \
  -n argocd
```

Verify:

```bash
kubectl get secret \
  bfsi-platform-repository \
  -n argocd
```

Using Argo CD CLI:

```bash
argocd repo list
```

Never print repository passwords or tokens.

---

### Invalid Application Source Path

Verify configured paths:

```bash
grep -R "path:" applications/
```

Compare against repository directories:

```bash
find ../../ -maxdepth 2 -type d
```

The Application source path must exactly match the repository directory.

---

## 29. Production Security Controls

```text
Git
 |
 +-- Protected Branch
 |
 +-- Pull Request Review
 |
 +-- CI Validation
 |
 +-- Security Scanning
 |
 v
Argo CD
 |
 +-- RBAC
 +-- AppProject
 +-- Repository Restrictions
 +-- Namespace Restrictions
 +-- Self-Healing
 +-- Drift Detection
 +-- Prune Disabled
 |
 v
Kubernetes
```

---

## 30. Production Design Decisions

| Design | Decision |
|---|---|
| Argo CD installation | Helm |
| Configuration source | Git |
| Deployment model | GitOps |
| RBAC | Enabled |
| Anonymous access | Disabled |
| Default access | Read-only |
| AppProject | `bfsi-platform` |
| Automated Sync | Enabled |
| Self-Healing | Enabled |
| Pruning | Disabled |
| Environment management | ApplicationSet |
| Repository access | Dedicated Argo CD repository credential |
| Production changes | Pull Request + Git |
| Direct production kubectl | Avoided for normal deployments |

---

## 31. Validation Checklist

### Argo CD

- [ ] Argo CD namespace exists
- [ ] Argo CD Helm release exists
- [ ] Argo CD server is healthy
- [ ] Argo CD repo-server is healthy
- [ ] Argo CD application controller is healthy
- [ ] ApplicationSet controller is healthy

### Security

- [ ] Anonymous access disabled
- [ ] RBAC enabled
- [ ] Default role is read-only
- [ ] BFSI AppProject exists
- [ ] Repository access restricted
- [ ] Namespace destinations restricted
- [ ] Production credentials are not committed to Git

### Applications

- [ ] `istio-platform` exists
- [ ] `bfsi-security` exists
- [ ] `bfsi-network` exists
- [ ] `bfsi-observability` exists

### ApplicationSet

- [ ] `bfsi-environments` exists
- [ ] `environments/*` exists before environment generation
- [ ] Generated Applications are created
- [ ] Generated Applications use the correct namespace

### GitOps

- [ ] Git is the source of truth
- [ ] Automated sync enabled
- [ ] Self-healing enabled
- [ ] Pruning disabled
- [ ] Git changes are detected
- [ ] Configuration drift is detected
- [ ] Self-healing restores desired state

### Production

- [ ] Git branch protection enabled
- [ ] Pull Request review required
- [ ] CI validation enabled
- [ ] Security scanning enabled
- [ ] Production deployment performed through GitOps

---

## 32. Phase Completion

Phase 9 is complete when the following deployment path is working:

```text
                 GitHub
                    |
                    v
             Pull Request
                    |
                    v
              Code Review
                    |
                    v
             Protected Main
                    |
                    v
                Argo CD
                    |
             Reconciliation
                    |
                    v
              Kubernetes
                    |
                    v
             Istio Ambient
                    |
                    v
             BFSI Services
```

Git is the desired-state source of truth.

Argo CD is the reconciliation engine.

Kubernetes is the runtime platform.

Istio Ambient provides the service-mesh networking and security layer.

Phase 9 establishes the GitOps foundation for the production BFSI platform lifecycle.