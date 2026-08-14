# Istio Ambient BFSI Production Platform

Production-grade reference implementation of an **Istio Ambient Mesh platform on Kubernetes for BFSI workloads**.

This repository demonstrates how to design, secure, operate, observe, and deploy a Kubernetes platform for regulated workloads using:

- Kubernetes
- Istio Ambient Mesh
- ztunnel
- Waypoints
- mTLS
- AuthorizationPolicy
- Kubernetes NetworkPolicy
- Ingress / Egress
- Observability
- Production hardening
- Argo CD
- GitOps

The implementation is organized into independent phases so that each capability can be deployed, validated, and operated independently.

---

## 1. Architecture

```text
                         GitHub
                            |
                            v
                    Argo CD / GitOps
                            |
                            v
                    Kubernetes Cluster
                            |
        +-------------------+-------------------+
        |                   |                   |
        v                   v                   v
   Istio Ambient        Security            Network
        |                   |                   |
        v                   v                   v
     ztunnel           Authorization      NetworkPolicy
        |
        v
    Waypoints
        |
        v
+----------------+----------------+----------------+
|                |                |                |
v                v                v                v
Payments         Orders           Cart          Customers
|                |                |                |
+----------------+----------------+----------------+
                         |
                         v
                  Ingress / Egress
                         |
              +----------+----------+
              |                     |
              v                     v
         External APIs          AWS Services
```

---

## 2. Platform Goals

The platform is designed around the following principles:

### Security

- Zero-trust service communication
- Mutual TLS
- Workload identity
- Layer-7 authorization
- Namespace isolation
- Kubernetes NetworkPolicy
- Least privilege
- Controlled ingress and egress

### Reliability

- Highly available platform components
- Failure isolation
- Production hardening
- Health validation
- Controlled deployments

### Observability

- Metrics
- Logs
- Traces
- Service-level visibility
- Istio telemetry
- Kubernetes observability

### Operations

- Declarative configuration
- GitOps
- Automated reconciliation
- Drift detection
- Self-healing
- Repeatable deployment

### BFSI Requirements

The platform is designed around common regulated-workload requirements:

- Strong workload identity
- Encryption in transit
- Authorization
- Network segmentation
- Auditability
- Controlled production changes
- Separation of duties
- Disaster recovery readiness

---

# 3. Technology Stack

| Layer | Technology |
|---|---|
| Container Platform | Kubernetes |
| Service Mesh | Istio Ambient |
| Node-Level Mesh | ztunnel |
| L7 Traffic Processing | Istio Waypoints |
| Service Security | Istio mTLS |
| Authorization | Istio AuthorizationPolicy |
| Network Security | Kubernetes NetworkPolicy |
| Ingress | Istio Gateway |
| Egress | Istio Egress Controls |
| Observability | Prometheus / Grafana / Logging / Tracing |
| GitOps | Argo CD |
| Configuration | Git |
| Cloud Platform | AWS |
| Container Platform | EKS |
| DR | Velero / AWS native services |

---

# 4. Repository Structure

```text
istio-bfsi-production-platform/
│
├── README.md
│
├── phases/
│   │
│   ├── phase-00-prerequisites/
│   │
│   ├── phase-01-istio-ambient-installation/
│   │
│   ├── phase-02-ambient-enrollment/
│   │
│   ├── phase-03-waypoints/
│   │
│   ├── phase-04-security/
│   │
│   ├── phase-05-network-policy/
│   │
│   ├── phase-06-ingress-egress/
│   │
│   ├── phase-07-observability/
│   │
│   ├── phase-08-production-hardening/
│   │
│   └── phase-09-gitops-argocd/
│
└── ...
```

Each phase contains its own:

- README
- Kubernetes manifests
- Configuration
- Deployment scripts
- Verification scripts
- Troubleshooting guidance

---

# 5. Implementation Phases

## Phase 00 — Prerequisites

```text
phase-00-prerequisites/
```

Establishes the prerequisites required by the platform.

### Covers

- Kubernetes connectivity
- kubectl
- Helm
- Istio CLI
- Git
- Required namespaces
- Required tooling
- Environment validation

### Objective

Ensure the environment is ready before deploying Istio Ambient.

---

# 6. Phase 01 — Istio Ambient Installation

```text
phase-01-istio-ambient-installation/
```

Installs Istio Ambient using a production-oriented Helm-based approach.

### Covers

- Istio Helm repository
- Istio base components
- Istiod
- Ambient profile
- Helm configuration
- Version pinning
- Installation validation
- Istio health verification

### Architecture

```text
Kubernetes
    |
    v
Istio
    |
    +-- istio-base
    |
    +-- istiod
    |
    +-- ztunnel
```

### Objective

Establish the Istio Ambient control and data plane.

---

# 7. Phase 02 — Ambient Enrollment

```text
phase-02-ambient-enrollment/
```

Enrolls application namespaces into Istio Ambient Mesh.

### Covers

- Ambient namespace labels
- Workload enrollment
- ztunnel participation
- Namespace validation
- Application connectivity validation

### Example

```text
payments namespace
       |
       v
Ambient enrollment
       |
       v
ztunnel
       |
       v
Istio Ambient
```

### Objective

Move workloads into Ambient Mesh without requiring sidecar injection.

---

# 8. Phase 03 — Waypoints

```text
phase-03-waypoints/
```

Introduces Istio Ambient Waypoints for workloads that require Layer-7 traffic processing.

### Covers

- Waypoint deployment
- Namespace/service-account association
- L7 policy enforcement
- Waypoint validation
- Traffic path validation

### Architecture

```text
Application
     |
     v
ztunnel
     |
     v
Waypoint
     |
     v
Destination
```

### Objective

Use Waypoints selectively where L7 processing is required while keeping the Ambient architecture sidecarless.

---

# 9. Phase 04 — Security

```text
phase-04-security/
```

Implements the service-to-service security model.

### Covers

- Mutual TLS
- PeerAuthentication
- AuthorizationPolicy
- Workload identity
- Namespace security
- Service-to-service authorization
- Default-deny authorization strategy

### Example

```text
payments
    |
    | mTLS
    |
    v
orders
```

Authorization determines whether the request is permitted.

### Objective

Establish zero-trust service communication.

---

# 10. Phase 05 — Network Policy

```text
phase-05-network-policy/
```

Implements Kubernetes NetworkPolicy as an additional network security boundary.

### Covers

- Namespace isolation
- Default-deny policies
- Ingress restrictions
- Egress restrictions
- Application-specific policies
- payments
- orders
- cart
- customers

### Security Model

```text
                    Kubernetes NetworkPolicy
                              |
          +-------------------+-------------------+
          |                   |                   |
          v                   v                   v
       payments             orders               cart
          |                   |                   |
          +-------------------+-------------------+
                    Controlled traffic
```

### Objective

Provide a network-level security boundary independent of the service mesh.

Istio provides service-level identity and authorization.

NetworkPolicy provides network-level isolation.

---

# 11. Phase 06 — Ingress / Egress

```text
phase-06-ingress-egress/
```

Controls traffic entering and leaving the platform.

### Covers

- Istio Gateway
- Gateway API / ingress
- External traffic
- TLS termination
- Egress controls
- External service access
- DNS considerations
- Traffic validation

### Architecture

```text
                         Internet
                            |
                            v
                       Load Balancer
                            |
                            v
                     Istio Gateway
                            |
                            v
                     BFSI Services
                            |
                            v
                      Egress Policy
                            |
                            v
                    External Services
```

### Objective

Create controlled north-south traffic paths.

---

# 12. Phase 07 — Observability

```text
phase-07-observability/
```

Provides platform and service observability.

### Covers

- Metrics
- Prometheus
- Grafana
- Logs
- Traces
- Istio telemetry
- Kubernetes metrics
- Service health
- Traffic visibility

### Observability Flow

```text
BFSI Workloads
      |
      +---- Metrics ----> Prometheus
      |
      +---- Logs -------> Logging Platform
      |
      +---- Traces -----> Tracing Platform
                              |
                              v
                           Grafana
```

### Objective

Provide operational visibility into:

- Service health
- Traffic
- Errors
- Latency
- Availability
- Mesh behavior
- Kubernetes behavior

---

# 13. Phase 08 — Production Hardening

```text
phase-08-production-hardening/
```

Hardens the platform for production workloads.

### Covers

- Resource management
- Pod security
- Availability
- Pod disruption handling
- Scheduling
- Security controls
- Operational safeguards
- Production configuration validation

### Objective

Move the platform from a functional deployment toward a production-ready operating model.

---

# 14. Phase 09 — GitOps with Argo CD

```text
phase-09-gitops-argocd/
```

Introduces GitOps as the deployment and reconciliation model.

### Covers

- Argo CD
- Helm installation
- Argo CD RBAC
- BFSI AppProject
- Repository integration
- Applications
- ApplicationSet
- Automated synchronization
- Self-healing
- Drift detection
- Git-based production deployments

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
```

### Objective

Make Git the desired-state source of truth.

Argo CD continuously reconciles Kubernetes with the approved Git state.

---

# 15. End-to-End Platform

After Phase 9, the platform looks like:

```text
                         GitHub
                            |
                            v
                         Argo CD
                            |
                            v
                    Kubernetes / EKS
                            |
              +-------------+-------------+
              |                           |
              v                           v
        Istio Ambient                 NetworkPolicy
              |
       +------+------+
       |             |
       v             v
    ztunnel       Waypoints
       |
       v
+------+------+------+------+
|             |             |
v             v             v
Payments     Orders        Cart
|             |             |
+-------------+-------------+
              |
              v
         Authorization
              |
              v
          mTLS Traffic
              |
              v
       Ingress / Egress
              |
              v
       External Services

              +
              
        Observability
              |
       +------+------+------+
       |      |      |      |
       v      v      v      v
    Metrics Logs  Traces  Events
```

---

# 16. Security Model

The platform uses multiple independent security layers.

```text
                    Request
                       |
                       v
              +----------------+
              | NetworkPolicy  |
              +----------------+
                       |
                       v
              +----------------+
              |    ztunnel     |
              +----------------+
                       |
                       v
              +----------------+
              |      mTLS      |
              +----------------+
                       |
                       v
              +----------------+
              |   Waypoint     |
              +----------------+
                       |
                       v
              +----------------+
              | Authorization  |
              +----------------+
                       |
                       v
                  Application
```

Each layer solves a different problem.

### NetworkPolicy

Provides network-level isolation.

### ztunnel

Provides Ambient mesh L4 traffic handling and workload identity enforcement.

### mTLS

Provides encryption and workload authentication.

### Waypoint

Provides Layer-7 processing.

### AuthorizationPolicy

Determines whether an authenticated workload is allowed to perform an operation.

---

# 17. GitOps Operating Model

Production configuration follows:

```text
Git
 |
 +-- Kubernetes manifests
 |
 +-- Istio configuration
 |
 +-- Security policies
 |
 +-- Network policies
 |
 +-- Observability configuration
 |
 +-- Argo CD configuration
 |
 v
Argo CD
 |
 v
Kubernetes
```

Normal production changes should not be performed using direct imperative changes such as:

```bash
kubectl edit
kubectl patch
kubectl apply
```

Instead:

```text
Change
  |
  v
Pull Request
  |
  v
Review
  |
  v
Merge
  |
  v
Argo CD
  |
  v
Kubernetes
```

---

# 18. CI and CD Separation

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

Argo CD is responsible for:

```text
Deployment
Reconciliation
Drift Detection
Self-Healing
Application Health
Desired-State Management
```

Therefore:

```text
CI
 |
 v
Git
 |
 v
Argo CD
 |
 v
Kubernetes
```

---

# 19. Environment Model

The intended environment model is:

```text
                    Git
                     |
          +----------+----------+
          |          |          |
          v          v          v
         Dev        Stage      Prod
          |          |          |
          v          v          v
       Argo CD     Argo CD    Argo CD
          |          |          |
          v          v          v
     Kubernetes   Kubernetes Kubernetes
```

Environment-specific configuration should remain declarative and version controlled.

---

# 20. Production Design Principles

## Declarative

Everything required to operate the platform should be represented as code.

## Version Controlled

Production configuration must be version controlled.

## Least Privilege

Every component receives only the permissions it requires.

## Defense in Depth

Security is implemented at multiple layers.

## Separation of Duties

Application development, infrastructure management, security approval, and production deployment should be separated where organizational controls require it.

## Immutable Changes

Production changes should originate from reviewed Git changes.

## Observability First

Every production service should have sufficient metrics, logs, traces, and health signals.

## Failure-Aware

The platform must be designed and tested for component and infrastructure failures.

---

# 21. Validation Strategy

Each phase contains validation appropriate to its scope.

Typical validation flow:

```text
Deploy
  |
  v
Validate Kubernetes
  |
  v
Validate Istio
  |
  v
Validate Security
  |
  v
Validate Networking
  |
  v
Validate Observability
  |
  v
Validate GitOps
```

Each phase should be independently validated before moving to the next phase.

---

# 22. Recommended Deployment Order

Deploy phases in order:

```text
Phase 00
   |
   v
Phase 01
   |
   v
Phase 02
   |
   v
Phase 03
   |
   v
Phase 04
   |
   v
Phase 05
   |
   v
Phase 06
   |
   v
Phase 07
   |
   v
Phase 08
   |
   v
Phase 09
```

Do not skip foundational phases unless the required capability has already been implemented and validated elsewhere.

---

# 23. Phase Completion Criteria

The platform should satisfy the following before being considered production-ready.

### Kubernetes

- [ ] Cluster is healthy
- [ ] Nodes are healthy
- [ ] Required namespaces exist
- [ ] Workloads are healthy

### Istio

- [ ] Istio control plane is healthy
- [ ] Ambient enrollment works
- [ ] ztunnel is healthy
- [ ] Waypoints are healthy
- [ ] Mesh traffic works

### Security

- [ ] mTLS is enabled
- [ ] Authorization policies are enforced
- [ ] NetworkPolicy is enforced
- [ ] Ingress is controlled
- [ ] Egress is controlled

### Observability

- [ ] Metrics available
- [ ] Logs available
- [ ] Traces available
- [ ] Service health observable
- [ ] Mesh traffic observable

### Production Hardening

- [ ] Resource requests/limits defined
- [ ] Availability controls configured
- [ ] Security controls validated
- [ ] Operational safeguards implemented

### GitOps

- [ ] Argo CD is healthy
- [ ] AppProject is configured
- [ ] Applications are synced
- [ ] ApplicationSet is functional
- [ ] Drift detection works
- [ ] Self-healing works
- [ ] Production changes flow through Git

---

# 24. BFSI Service Communication Example

Example service topology:

```text
                 Customer
                    |
                    v
               API Gateway
                    |
                    v
               Payments API
                    |
                    v
                 Orders
                    |
                    v
                  Cart
```

Security:

```text
Payments
    |
    | mTLS
    |
    v
Orders
    |
    | mTLS
    |
    v
Cart
```

Authorization:

```text
payments  ---> orders     ALLOW
payments  ---> cart       DENY
orders    ---> cart       ALLOW
cart      ---> payments   DENY
```

The exact authorization relationships should be defined explicitly through Istio policies.

NetworkPolicy provides an additional network-level boundary.

---

# 25. Important Security Principle

Istio and Kubernetes NetworkPolicy are not replacements for each other.

```text
NetworkPolicy
    |
    +-- Network-level isolation

Istio
    |
    +-- Workload identity
    +-- mTLS
    +-- L7 authorization
    +-- Service-level controls
```

Using both provides defense in depth.

---

# 26. Operational Model

Normal platform operation should follow:

```text
Observe
   |
   v
Detect
   |
   v
Investigate
   |
   v
Change Git
   |
   v
Review
   |
   v
Merge
   |
   v
Argo CD
   |
   v
Reconcile
   |
   v
Validate
```

Manual production changes should be treated as exceptions and audited.

---

# 27. Disaster Recovery Direction

Disaster recovery is planned as the next platform phase.

The intended architecture is:

```text
Git
 |
 +-- Platform Configuration
 |
 v
Argo CD
 |
 v
Rebuild Kubernetes / Istio Platform

+

Velero
 |
 +-- Kubernetes Resource Backup
 +-- Kubernetes Persistent Storage Backup
 |
 v
S3

+

AWS Managed Database
 |
 +-- Native Backup
 +-- Point-in-Time Recovery
 +-- Cross-Region DR
 |
 v
Recovery
```

Important:

**AWS-managed databases such as Aurora/RDS should use their native backup and disaster-recovery capabilities.**

Velero should not be treated as the primary backup mechanism for an external Aurora/RDS database.

---

# 28. Production Change Management

Recommended production workflow:

```text
Developer
    |
    v
Feature Branch
    |
    v
Pull Request
    |
    +--> Unit Tests
    +--> Security Scan
    +--> Manifest Validation
    +--> Policy Validation
    |
    v
Peer Review
    |
    v
Approval
    |
    v
Protected Main
    |
    v
Argo CD
    |
    v
Production
```

This provides:

- Auditability
- Traceability
- Controlled changes
- Reproducibility
- Rollback capability

---

# 29. Repository Philosophy

This repository is intentionally structured as a **platform engineering reference implementation**, not as a collection of disconnected YAML examples.

Each phase should answer:

1. What problem does this solve?
2. Why is it required?
3. How is it implemented?
4. How is it validated?
5. How is it operated?
6. What happens when it fails?

The implementation should prefer:

```text
Declarative
+
Version Controlled
+
Validated
+
Repeatable
+
Production Oriented
```

over imperative, ad-hoc configuration.

---

# 30. Phase Summary

| Phase | Capability | Primary Outcome |
|---|---|---|
| 00 | Prerequisites | Platform prerequisites validated |
| 01 | Istio Ambient Installation | Istio Ambient installed |
| 02 | Ambient Enrollment | Workloads enrolled into Ambient |
| 03 | Waypoints | L7 traffic processing |
| 04 | Security | mTLS and authorization |
| 05 | Network Policy | Network-level isolation |
| 06 | Ingress / Egress | Controlled north-south traffic |
| 07 | Observability | Metrics, logs and traces |
| 08 | Production Hardening | Production operational controls |
| 09 | GitOps / Argo CD | Declarative deployment and reconciliation |

---

# 31. End State

The target platform architecture is:

```text
                         GitHub
                            |
                            v
                         Argo CD
                            |
                            v
                    Kubernetes / EKS
                            |
        +-------------------+-------------------+
        |                   |                   |
        v                   v                   v
   Istio Ambient       NetworkPolicy       Observability
        |
        +----------------------+
        |                      |
        v                      v
     ztunnel                Waypoints
        |
        v
+-------+-------+-------+-------+
|               |               |
v               v               v
Payments       Orders          Cart
|               |               |
+---------------+---------------+
                |
                v
        Authorization / mTLS
                |
                v
          Ingress / Egress
                |
                v
        External Dependencies
```

The platform provides:

```text
Kubernetes
    +
Istio Ambient
    +
Zero Trust Security
    +
Network Segmentation
    +
Ingress / Egress Control
    +
Observability
    +
Production Hardening
    +
GitOps
```

This forms the foundation for a production-oriented **BFSI Kubernetes and Istio Ambient platform**.