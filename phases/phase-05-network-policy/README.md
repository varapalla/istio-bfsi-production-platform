# Phase 5 — Kubernetes NetworkPolicy Defense in Depth

This phase introduces **Kubernetes NetworkPolicy** as an independent network-security layer alongside Istio Ambient.

Phase 4 established:

```text
STRICT mTLS
+
Istio AuthorizationPolicy
```

Phase 5 adds:

```text
Kubernetes NetworkPolicy
```

The resulting production security model becomes:

```text
                Application Traffic
                       │
                       ▼
              Kubernetes Network
                       │
              ┌────────┴────────┐
              │                 │
        NetworkPolicy       Istio Ambient
              │                 │
          L3/L4 boundary    mTLS + L7 AuthZ
              │                 │
              └────────┬────────┘
                       │
                       ▼
                  Application
```

The purpose is **defense in depth**.

---

# 5.1 Why NetworkPolicy When Istio Is Already Enabled?

Istio and Kubernetes NetworkPolicy solve different security problems.

Istio provides:

```text
Workload identity
mTLS
Service authorization
L7 authorization
```

NetworkPolicy provides:

```text
Pod/network isolation
L3/L4 traffic restrictions
Namespace-level network boundaries
Protection independent of the service mesh
```

Therefore:

```text
Istio
  └── "Is this authenticated workload allowed to access this service?"

NetworkPolicy
  └── "Can network traffic reach this workload at all?"
```

This is an important production distinction.

---

# 5.2 Defense-in-Depth Model

The production security architecture is:

```text
                         Request
                            │
                            ▼
                    NetworkPolicy
                     L3/L4 filtering
                            │
                            ▼
                       Ztunnel
                     mTLS / HBONE
                            │
                            ▼
                       Waypoint
                    L7 Authorization
                            │
                            ▼
                       Service
                            │
                            ▼
                       Workload
```

A request must pass multiple security boundaries.

```text
Network access
      ↓
mTLS authentication
      ↓
Authorization
      ↓
Application
```

---

# 5.3 Security Responsibilities

| Security Layer | Technology                | Responsibility               |
| -------------- | ------------------------- | ---------------------------- |
| Network        | Kubernetes NetworkPolicy  | L3/L4 network isolation      |
| Identity       | Istio Ambient             | Workload identity            |
| Encryption     | Istio mTLS                | Traffic encryption           |
| Authorization  | Istio AuthorizationPolicy | Service authorization        |
| Application    | Application security      | Business-level authorization |

No single layer is expected to provide every security control.

---

# 5.4 Prerequisites

Phase 5 assumes:

```text
Phase 0 → Prerequisites
Phase 1 → Istio Ambient installation
Phase 2 → Ambient namespace enrollment
Phase 3 → Waypoints
Phase 4 → STRICT mTLS + AuthorizationPolicy
```

Verify the application namespaces:

```bash
kubectl get namespace \
  payments \
  orders \
  cart \
  customers
```

Verify Ambient enrollment:

```bash
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

Expected:

```text
istio.io/dataplane-mode=ambient
```

Verify Istio security:

```bash
kubectl get peerauthentication -A
```

```bash
kubectl get authorizationpolicy -A
```

---

# 5.5 NetworkPolicy Strategy

The application namespaces are:

```text
payments
orders
cart
customers
```

Phase 5 introduces a namespace isolation model.

The baseline principle is:

```text
Deny unexpected network access
+
Allow required application flows
+
Allow required platform traffic
```

The policy must not blindly deny all traffic.

Kubernetes workloads require infrastructure communication such as:

```text
DNS
Kubernetes control-plane related traffic
CNI networking
Application dependencies
Observability endpoints
```

Therefore NetworkPolicy design must be explicit.

---

# 5.6 Important Production Principle

Do not use NetworkPolicy to duplicate every Istio authorization rule.

For example, Phase 4 defines:

```text
orders → payments = ALLOW
```

through Istio AuthorizationPolicy.

NetworkPolicy should provide the **network boundary**, not become a second copy of every L7 business authorization rule.

The preferred separation is:

```text
NetworkPolicy
    │
    └── Can traffic reach the workload?

Istio
    │
    ├── Is the workload authenticated?
    │
    └── Is the request authorized?
```

This avoids unnecessary policy duplication.

---

# 5.7 Baseline Default-Deny Policy

Each application namespace receives a baseline ingress policy.

The conceptual model is:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: payments
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

This means:

```text
All Pods in payments
        │
        ▼
Ingress denied by default
```

The same model applies to:

```text
orders
cart
customers
```

---

# 5.8 Why Start With Ingress?

Ingress controls are especially important for service isolation.

Example:

```text
random namespace
       │
       │ network traffic
       ▼
payments Pod
```

NetworkPolicy can prevent the traffic from reaching the Pod.

The request therefore does not even reach:

```text
Ztunnel
Waypoint
Application
```

This is different from an Istio authorization denial.

---

# 5.9 NetworkPolicy vs Istio Deny

Consider:

```text
payments → orders
```

Istio can evaluate:

```text
mTLS
   ↓
Authenticated identity
   ↓
AuthorizationPolicy
   ↓
DENY
```

NetworkPolicy can enforce:

```text
Network
   ↓
L3/L4 policy
   ↓
DENY
```

These are different enforcement layers.

---

# 5.10 Defense-in-Depth Example

Consider an unauthorized workload:

```text
random namespace
       │
       ▼
NetworkPolicy
       │
       └── DENY
```

The traffic never reaches the application.

Now consider a legitimate network path:

```text
orders
   │
   ▼
NetworkPolicy
   │
   │ ALLOW network path
   ▼
Ztunnel
   │
   │ STRICT mTLS
   ▼
payments-waypoint
   │
   │ AuthorizationPolicy
   │
   │ ALLOW
   ▼
payments
```

Both layers cooperate.

---

# 5.11 DNS Requirement

A common production mistake is enabling default-deny policies without allowing DNS.

Applications frequently require:

```text
Pod
 │
 ▼
CoreDNS
 │
 ▼
Service discovery
```

If DNS is blocked:

```text
Application
   │
   └── DNS failure
```

Therefore NetworkPolicy implementation must explicitly account for DNS traffic.

The exact DNS policy must match the cluster's DNS architecture.

---

# 5.12 Egress Considerations

Phase 5 initially focuses on ingress isolation.

Do not immediately implement an unrestricted:

```text
default-deny-egress
```

without identifying required dependencies.

Production applications commonly require egress to:

```text
DNS
Databases
Message brokers
AWS services
External APIs
Observability systems
Secrets systems
```

Therefore egress should be introduced deliberately.

The production approach is:

```text
Inventory dependencies
        ↓
Define required destinations
        ↓
Allow required traffic
        ↓
Deny everything else
```

---

# 5.13 Namespace Isolation

The objective is to establish clear namespace boundaries.

Conceptually:

```text
                  Cluster
                     │
        ┌────────────┼────────────┐
        │            │            │
     payments      orders       cart
        │            │            │
        └────────────┼────────────┘
                     │
                 customers
```

NetworkPolicy prevents arbitrary workloads from establishing network paths across these boundaries.

Istio then performs workload-level identity and authorization.

---

# 5.14 Example: Payments Namespace

Baseline policy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payments-default-deny-ingress
  namespace: payments
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Result:

```text
Any Pod
   │
   ▼
payments
   │
   └── DENY by default
```

Required traffic must be explicitly allowed.

---

# 5.15 Example: Orders Namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: orders-default-deny-ingress
  namespace: orders
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Result:

```text
Unexpected network source
          │
          ▼
      orders Pod
          │
          └── DENY
```

---

# 5.16 Example: Cart Namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cart-default-deny-ingress
  namespace: cart
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Cart therefore starts from a protected network boundary.

---

# 5.17 Example: Customers Namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: customers-default-deny-ingress
  namespace: customers
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Customers receives the same baseline isolation model.

---

# 5.18 Required Platform Traffic

Before applying restrictive policies in production, identify:

```text
DNS
Ingress
Monitoring
Logging
Metrics
Tracing
Service dependencies
Database dependencies
Message brokers
Cloud services
```

The correct policy model is:

```text
Required platform traffic
          │
          ▼
      Explicit ALLOW
          │
          ▼
    Everything else
          │
          ▼
         DENY
```

Do not guess platform dependencies.

---

# 5.19 NetworkPolicy and Ztunnel

NetworkPolicy and Ztunnel operate at different layers.

Conceptually:

```text
Pod
 │
 ▼
Kubernetes networking
 │
 ▼
NetworkPolicy
 │
 ▼
Ambient traffic handling
 │
 ▼
Ztunnel
 │
 ▼
Waypoint
```

NetworkPolicy should therefore be treated as an infrastructure security boundary.

Ztunnel remains responsible for Ambient mesh security.

---

# 5.20 NetworkPolicy and Waypoints

Waypoints provide Layer 7 processing:

```text
HTTP
AuthorizationPolicy
Routing
Telemetry
```

NetworkPolicy does not understand application-level authorization such as:

```text
HTTP method
JWT claims
HTTP path
Service identity
Application request semantics
```

Therefore:

```text
NetworkPolicy
    → L3/L4

Waypoint
    → L7
```

This separation is intentional.

---

# 5.21 NetworkPolicy and Cilium

Phase 5 uses the Kubernetes-standard:

```text
networking.k8s.io/v1
NetworkPolicy
```

If the production platform uses Cilium, Cilium can extend this model with:

```text
eBPF enforcement
Identity-aware policies
Advanced L3/L4 controls
L7 policies
Observability
```

However, Cilium-specific policies are not introduced in this phase.

The objective is to establish the Kubernetes NetworkPolicy baseline first.

---

# 5.22 Why Not Replace Istio With Cilium?

Cilium and Istio have overlapping capabilities but different responsibilities.

For this architecture:

```text
Cilium / NetworkPolicy
        │
        └── Network security

Istio Ambient
        │
        ├── mTLS
        ├── workload identity
        ├── service authorization
        └── L7 traffic management
```

The production design can use both when the requirements justify it.

---

# 5.23 Security Control Matrix

| Requirement                | Control                   |
| -------------------------- | ------------------------- |
| Pod network isolation      | NetworkPolicy             |
| Namespace network boundary | NetworkPolicy             |
| Workload identity          | Istio Ambient             |
| Encryption in transit      | Istio mTLS                |
| Service authorization      | Istio AuthorizationPolicy |
| HTTP authorization         | Waypoint                  |
| L7 routing                 | Waypoint                  |
| Advanced eBPF enforcement  | Cilium                    |
| Application authorization  | Application               |

This layered model avoids forcing one technology to solve every problem.

---

# 5.24 Deployment Structure

Phase 5 should use:

```text
phase-05-network-policy/
│
├── README.md
│
├── scripts/
│   ├── deploy.sh
│   └── verify.sh
│
└── network-policy/
    ├── payments/
    │   └── default-deny-ingress.yaml
    │
    ├── orders/
    │   └── default-deny-ingress.yaml
    │
    ├── cart/
    │   └── default-deny-ingress.yaml
    │
    └── customers/
        └── default-deny-ingress.yaml
```

Keep network policies separate from Istio security policies.

```text
security/
    └── Istio security

network-policy/
    └── Kubernetes network security
```

---

# 5.25 Deployment

Change to the Phase 5 directory:

```bash
cd phases/phase-05-network-policy
```

Make the deployment script executable:

```bash
chmod +x scripts/deploy.sh
```

Run:

```bash
./scripts/deploy.sh
```

The deployment process should:

```text
Validate namespaces
        ↓
Validate Ambient enrollment
        ↓
Validate existing Istio security
        ↓
Apply NetworkPolicies
        ↓
Verify policies
```

---

# 5.26 Verify NetworkPolicies

List policies:

```bash
kubectl get networkpolicy -A
```

Expected:

```text
payments
orders
cart
customers
```

Inspect Payments:

```bash
kubectl get networkpolicy \
  -n payments
```

Inspect Orders:

```bash
kubectl get networkpolicy \
  -n orders
```

Inspect Cart:

```bash
kubectl get networkpolicy \
  -n cart
```

Inspect Customers:

```bash
kubectl get networkpolicy \
  -n customers
```

---

# 5.27 Inspect Policy YAML

Payments:

```bash
kubectl get networkpolicy \
  -n payments \
  -o yaml
```

Orders:

```bash
kubectl get networkpolicy \
  -n orders \
  -o yaml
```

Cart:

```bash
kubectl get networkpolicy \
  -n cart \
  -o yaml
```

Customers:

```bash
kubectl get networkpolicy \
  -n customers \
  -o yaml
```

---

# 5.28 Verify Istio Security Remains Intact

NetworkPolicy deployment must not remove or modify Istio security controls.

Verify:

```bash
kubectl get peerauthentication -A
```

```bash
kubectl get authorizationpolicy -A
```

Verify Waypoints:

```bash
istioctl waypoint list --all
```

The expected model remains:

```text
NetworkPolicy
     │
     ▼
STRICT mTLS
     │
     ▼
AuthorizationPolicy
     │
     ▼
Application
```

---

# 5.29 Verification Script

Make the verification script executable:

```bash
chmod +x scripts/verify.sh
```

Run:

```bash
./scripts/verify.sh
```

The script should verify:

```text
Kubernetes connectivity
        ↓
Required namespaces
        ↓
Ambient enrollment
        ↓
NetworkPolicy existence
        ↓
STRICT mTLS
        ↓
AuthorizationPolicy
        ↓
Waypoints
```

---

# 5.30 Troubleshooting

## Pods cannot communicate

Check:

```bash
kubectl get networkpolicy -A
```

Inspect:

```bash
kubectl describe networkpolicy \
  -n <namespace>
```

Check Pod labels:

```bash
kubectl get pods \
  -n <namespace> \
  --show-labels
```

---

## DNS stops working

Check:

```bash
kubectl exec \
  -n <namespace> \
  <pod> \
  -- nslookup kubernetes.default.svc.cluster.local
```

If DNS is blocked, review the NetworkPolicy egress rules.

---

## Istio traffic is denied

Determine which layer is denying traffic.

```text
NetworkPolicy?
      │
      ▼
mTLS?
      │
      ▼
AuthorizationPolicy?
      │
      ▼
Application?
```

Do not immediately change the Istio policy.

First establish which security layer rejected the request.

---

# 5.31 Security Troubleshooting Model

For an application request:

```text
Client
  │
  ▼
NetworkPolicy
  │
  ├── DENY → Network layer
  │
  ▼
Ztunnel
  │
  ├── mTLS failure → Identity/security
  │
  ▼
Waypoint
  │
  ├── DENY → AuthorizationPolicy
  │
  ▼
Service
  │
  ├── failure → Application/service
  │
  ▼
Workload
```

This model is critical for production troubleshooting.

---

# 5.32 Production Operating Principle

Never troubleshoot only from the Istio layer.

For example:

```text
Application cannot reach payments
```

Check in this order:

```text
1. DNS
2. Kubernetes NetworkPolicy
3. Service
4. Ambient enrollment
5. Ztunnel
6. mTLS
7. Waypoint
8. AuthorizationPolicy
9. Application
```

This prevents incorrect remediation.

---

# 5.33 Phase 5 Architecture

```text
                         Istiod
                           │
              ┌────────────┴────────────┐
              │                         │
        Istio Security            Kubernetes Network
              │                         │
       ┌──────┴──────┐                  │
       │             │                  ▼
   STRICT mTLS   Authorization    NetworkPolicy
       │             │                  │
       ▼             ▼                  │
    Ztunnel       Waypoint              │
       │             │                  │
       └─────────────┴──────────────────┘
                     │
                     ▼
              Application Service
                     │
                     ▼
                  Workload
```

---

# 5.34 Final Security Model

After Phase 5:

```text
                         Request
                            │
                            ▼
                 ┌────────────────────┐
                 │ Kubernetes Network  │
                 │    NetworkPolicy    │
                 └─────────┬──────────┘
                           │
                         ALLOW
                           │
                           ▼
                    ┌─────────────┐
                    │   Ztunnel   │
                    │   mTLS/L4   │
                    └──────┬──────┘
                           │
                        Authenticated
                           │
                           ▼
                    ┌─────────────┐
                    │   Waypoint  │
                    │    L7 AuthZ │
                    └──────┬──────┘
                           │
                         ALLOW
                           │
                           ▼
                    Application
```

The security model therefore provides:

```text
Network isolation
+
Encrypted communication
+
Workload identity
+
Service authorization
+
Defense in depth
```

---

# 5.35 Phase 5 Checklist

* [ ] Phase 1 Ambient installation completed
* [ ] Phase 2 Ambient enrollment completed
* [ ] Phase 3 Waypoints deployed
* [ ] Phase 4 STRICT mTLS configured
* [ ] Phase 4 AuthorizationPolicies configured
* [ ] Kubernetes NetworkPolicy API available
* [ ] Payments namespace has baseline NetworkPolicy
* [ ] Orders namespace has baseline NetworkPolicy
* [ ] Cart namespace has baseline NetworkPolicy
* [ ] Customers namespace has baseline NetworkPolicy
* [ ] NetworkPolicy is treated as an independent security layer
* [ ] DNS requirements are identified
* [ ] Required platform traffic is identified
* [ ] Istio security policies remain unchanged
* [ ] Waypoints remain operational
* [ ] NetworkPolicy does not duplicate every Istio authorization rule
* [ ] `kubectl get networkpolicy -A` succeeds
* [ ] `kubectl get peerauthentication -A` succeeds
* [ ] `kubectl get authorizationpolicy -A` succeeds
* [ ] `istioctl waypoint list --all` succeeds
* [ ] `deploy.sh` completes successfully
* [ ] `verify.sh` completes successfully

---

# 5.36 Phase 5 Completion Criteria

Phase 5 is complete when:

```text
Kubernetes NetworkPolicy
          │
          ▼
Network boundary established
          │
          +
          ▼
Istio STRICT mTLS
          │
          ▼
Workload identity established
          │
          +
          ▼
Istio AuthorizationPolicy
          │
          ▼
Service authorization established
```

The final architecture has independent controls at:

```text
L3/L4 → Kubernetes NetworkPolicy
L4    → Istio Ambient / Ztunnel
L7    → Istio Waypoint
```

This provides the foundation for the next phase: **traffic management and controlled application routing**.
