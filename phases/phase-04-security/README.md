# Phase 4 — Istio Ambient Security

This phase implements the **security enforcement layer** for the Istio Ambient Mesh.

The security model uses:

```text
Istio Ambient
     │
     ├── Ztunnel
     │     └── L4 secure transport / mTLS
     │
     └── Waypoint
           └── L7 authorization
```

The reference application contains:

```text
payments
orders
cart
customers
```

Phase 4 establishes:

```text
STRICT mTLS
     +
Default-deny authorization
     +
Explicit service-to-service allow rules
```

The objective is to implement a **zero-trust service-to-service security model** suitable for regulated BFSI workloads.

---

# 4.1 Security Objectives

The security requirements are:

```text
1. Encrypt service-to-service communication
2. Authenticate workloads using workload identity
3. Enforce STRICT mTLS
4. Deny unauthorized service communication
5. Explicitly allow required business flows
6. Keep authorization enforcement at the appropriate Waypoint
7. Maintain Kubernetes NetworkPolicy as a separate infrastructure control
```

The security model follows:

```text
                    Zero Trust
                        │
          ┌─────────────┴─────────────┐
          │                           │
       Identity                   Authorization
          │                           │
      STRICT mTLS             AuthorizationPolicy
          │                           │
       Ztunnel                  Waypoint
```

---

# 4.2 Prerequisites

Phase 4 assumes the following phases are complete:

```text
Phase 0 → Kubernetes / Helm / CLI prerequisites
Phase 1 → Istio Ambient installation
Phase 2 → Ambient namespace enrollment
Phase 3 → Waypoint deployment
```

Verify the application namespaces:

```bash
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

Each namespace must contain:

```text
istio.io/dataplane-mode=ambient
```

Verify Waypoints:

```bash
kubectl get gateway -A
```

Expected:

```text
payments     payments-waypoint
orders       orders-waypoint
cart         cart-waypoint
customers    customers-waypoint
```

---

# 4.3 Security Architecture

The Phase 4 security architecture is:

```text
                    Istiod
                      │
                      │
          ┌───────────┴───────────┐
          │                       │
       Ztunnel                 Waypoints
          │                       │
          │ L4/mTLS               │ L7 Authorization
          │                       │
   ┌──────┼──────┬────────┐       │
   │      │      │        │       │
payments orders cart customers   │
   │      │      │        │       │
   └──────┴──────┴────────┴───────┘
```

Traffic processing:

```text
Source Workload
      │
      ▼
   Ztunnel
      │
      │ HBONE / mTLS
      ▼
Destination Waypoint
      │
      │ AuthorizationPolicy
      ▼
Destination Service
      │
      ▼
Destination Workload
```

---

# 4.4 Security Responsibilities

Istio Ambient separates security responsibilities between Ztunnel and Waypoints.

## Ztunnel

Ztunnel provides the Ambient Layer 4 security foundation:

```text
Workload identity
mTLS
HBONE
L4 traffic enforcement
L4 telemetry
```

## Waypoint

Waypoints provide Layer 7 processing:

```text
HTTP authorization
Service-level authorization
L7 telemetry
Advanced traffic policies
```

Therefore:

```text
Ztunnel
   │
   └── "Is this connection securely authenticated?"

Waypoint
   │
   └── "Is this workload allowed to access this service?"
```

---

# 4.5 STRICT mTLS

BFSI workloads should not rely on permissive or plaintext service communication.

Phase 4 configures:

```text
PeerAuthentication
        │
        ▼
     STRICT
```

The following namespaces are configured for STRICT mTLS:

```text
payments
orders
cart
customers
```

The configuration is stored in:

```text
security/peer-authentication.yaml
```

The effective policy is:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: payments
spec:
  mtls:
    mode: STRICT
```

The same model is applied to:

```text
orders
cart
customers
```

---

# 4.6 Why STRICT mTLS?

STRICT mTLS ensures that workload-to-workload communication must use Istio mutual TLS.

Without STRICT mTLS:

```text
Workload
   │
   ├── plaintext
   │
   └── mTLS
```

With STRICT mTLS:

```text
Workload
   │
   ▼
   mTLS
   │
   ▼
Destination
```

This provides:

```text
Encryption
Authentication
Workload identity
Protection against plaintext traffic
```

For BFSI environments this becomes an important control for:

```text
Confidentiality
Service identity
Internal traffic protection
Zero-trust communication
```

---

# 4.7 Authorization Model

mTLS answers:

```text
WHO is communicating?
```

AuthorizationPolicy answers:

```text
IS this workload allowed to communicate with this service?
```

Therefore:

```text
STRICT mTLS
     │
     ▼
Authenticate workload
     │
     ▼
AuthorizationPolicy
     │
     ▼
Authorize request
```

Both controls are required.

---

# 4.8 Default-Deny Security Model

The Phase 4 authorization model follows:

```text
DENY BY DEFAULT
        │
        ▼
EXPLICIT ALLOW
```

For each namespace:

```text
Default deny
     +
Required business flow allow
```

Example:

```text
payments
   │
   ├── orders → ALLOW
   │
   ├── cart → DENY
   │
   └── customers → DENY
```

This prevents accidental service-to-service access.

---

# 4.9 Payments Authorization

Payments uses:

```text
payments-default-deny
payments-allow-orders
```

Files:

```text
security/authorization/payments-default-deny.yaml
security/authorization/payments-allow-orders.yaml
```

The default policy provides the baseline deny behavior.

The explicit allow policy permits:

```text
orders → payments
```

The authorization is targeted at:

```text
payments-waypoint
```

Example:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: payments-allow-orders
  namespace: payments
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: payments-waypoint
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces:
              - orders
```

Therefore:

```text
orders
   │
   │ ALLOWED
   ▼
payments-waypoint
   │
   ▼
payments
```

---

# 4.10 Orders Authorization

Orders uses:

```text
orders-default-deny
orders-allow-cart
```

The permitted business flow is:

```text
cart → orders
```

Therefore:

```text
cart
   │
   │ ALLOWED
   ▼
orders-waypoint
   │
   ▼
orders
```

Unauthorized namespaces remain denied.

---

# 4.11 Customers Authorization

Customers uses:

```text
customers-default-deny
customers-allow-orders
```

The permitted business flow is:

```text
orders → customers
```

Therefore:

```text
orders
   │
   │ ALLOWED
   ▼
customers-waypoint
   │
   ▼
customers
```

---

# 4.12 Cart Authorization

Cart uses:

```text
cart-default-deny
```

No explicit inbound application authorization is configured in this phase.

Therefore:

```text
External application namespace
          │
          ▼
     cart-waypoint
          │
          ▼
         DENY
```

This follows the least-privilege model.

---

# 4.13 Application Communication Matrix

The intended authorization model is:

| Source    | Destination | Result |
| --------- | ----------- | ------ |
| orders    | payments    | ALLOW  |
| cart      | orders      | ALLOW  |
| orders    | customers   | ALLOW  |
| payments  | orders      | DENY   |
| payments  | cart        | DENY   |
| payments  | customers   | DENY   |
| customers | payments    | DENY   |
| customers | orders      | DENY   |
| cart      | payments    | DENY   |
| cart      | customers   | DENY   |

The important principle is:

```text
Only explicitly required business flows are allowed.
Everything else is denied.
```

---

# 4.14 AuthorizationPolicy Targeting

Phase 4 targets authorization policies to the namespace Waypoints:

```yaml
targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: payments-waypoint
```

For example:

```text
payments AuthorizationPolicy
             │
             ▼
      payments-waypoint
             │
             ▼
       payments Service
```

This is important in Ambient Mode because Waypoints provide the Layer 7 enforcement point.

The architecture therefore becomes:

```text
              Source
                │
                ▼
             Ztunnel
                │
                │ mTLS
                ▼
        Destination Waypoint
                │
                │ AuthorizationPolicy
                ▼
        Destination Service
```

---

# 4.15 Security Policy Separation

Phase 4 intentionally separates security controls.

```text
Istio Security
      │
      ├── PeerAuthentication
      │       └── STRICT mTLS
      │
      └── AuthorizationPolicy
              └── Service authorization
```

Kubernetes network controls remain separate:

```text
Kubernetes NetworkPolicy
        │
        └── L3/L4 infrastructure boundary
```

And later, if required:

```text
CiliumNetworkPolicy
        │
        └── Advanced eBPF enforcement
```

Do not replace Kubernetes NetworkPolicy with Istio authorization.

They solve different layers of the security model.

---

# 4.16 What Phase 4 Does Not Configure

The following are intentionally outside the scope of this phase:

```text
NetworkPolicy
CiliumNetworkPolicy
Ingress Gateway
Egress Gateway
External authorization
JWT authentication
OIDC
RequestAuthentication
ServiceEntry
Telemetry
Tracing
Prometheus
Grafana
Alerting
```

Phase 4 is limited to:

```text
STRICT mTLS
        +
AuthorizationPolicy
```

This keeps each phase independently deployable and auditable.

---

# 4.17 Repository Structure

Phase 4 uses:

```text
phase-04-security/
│
├── README.md
│
├── scripts/
│   ├── deploy.sh
│   └── verify.sh
│
└── security/
    │
    ├── peer-authentication.yaml
    │
    └── authorization/
        ├── payments-default-deny.yaml
        ├── payments-allow-orders.yaml
        ├── orders-default-deny.yaml
        ├── orders-allow-cart.yaml
        ├── cart-default-deny.yaml
        ├── customers-default-deny.yaml
        └── customers-allow-orders.yaml
```

The repository keeps security policies as Kubernetes manifests rather than relying on imperative commands.

This allows:

```text
Git
 │
 ▼
Review
 │
 ▼
GitOps
 │
 ▼
Cluster
```

---

# 4.18 Deploy Security Policies

Change to the Phase 4 directory:

```bash
cd phases/phase-04-security
```

Make the deployment script executable:

```bash
chmod +x scripts/deploy.sh
```

Run:

```bash
./scripts/deploy.sh
```

The deployment script verifies:

```text
Ambient namespaces
        ↓
Waypoints
        ↓
STRICT mTLS
        ↓
AuthorizationPolicies
```

The script applies:

```text
security/peer-authentication.yaml
security/authorization/
```

---

# 4.19 Verify STRICT mTLS

List PeerAuthentication resources:

```bash
kubectl get peerauthentication -A
```

Expected:

```text
payments/default
orders/default
cart/default
customers/default
```

Check Payments:

```bash
kubectl get peerauthentication default \
  -n payments \
  -o yaml
```

Verify:

```yaml
spec:
  mtls:
    mode: STRICT
```

Repeat for:

```bash
kubectl get peerauthentication default \
  -n orders \
  -o yaml
```

```bash
kubectl get peerauthentication default \
  -n cart \
  -o yaml
```

```bash
kubectl get peerauthentication default \
  -n customers \
  -o yaml
```

---

# 4.20 Verify AuthorizationPolicies

List all policies:

```bash
kubectl get authorizationpolicy -A
```

Expected policies:

```text
payments
  payments-default-deny
  payments-allow-orders

orders
  orders-default-deny
  orders-allow-cart

cart
  cart-default-deny

customers
  customers-default-deny
  customers-allow-orders
```

---

# 4.21 Verify Payments Authorization

```bash
kubectl get authorizationpolicy \
  -n payments \
  payments-default-deny \
  payments-allow-orders
```

Inspect:

```bash
kubectl get authorizationpolicy \
  -n payments \
  payments-allow-orders \
  -o yaml
```

Verify that the policy targets:

```text
payments-waypoint
```

And permits:

```text
orders namespace
```

---

# 4.22 Verify Orders Authorization

```bash
kubectl get authorizationpolicy \
  -n orders \
  orders-default-deny \
  orders-allow-cart
```

Verify:

```text
cart → orders
```

is explicitly allowed.

---

# 4.23 Verify Customers Authorization

```bash
kubectl get authorizationpolicy \
  -n customers \
  customers-default-deny \
  customers-allow-orders
```

Verify:

```text
orders → customers
```

is explicitly allowed.

---

# 4.24 Verify Cart Authorization

```bash
kubectl get authorizationpolicy \
  -n cart \
  cart-default-deny
```

Cart has no additional allow policy in this phase.

Therefore the namespace remains protected by the default-deny model.

---

# 4.25 Verify Waypoint Configuration

Verify all Waypoints:

```bash
istioctl waypoint list --all
```

Expected:

```text
payments-waypoint
orders-waypoint
cart-waypoint
customers-waypoint
```

Verify Gateway resources:

```bash
kubectl get gateway -A
```

Verify Waypoint deployments:

```bash
kubectl get deployment -A
```

---

# 4.26 Run Verification Script

Make the verification script executable:

```bash
chmod +x scripts/verify.sh
```

Run:

```bash
./scripts/verify.sh
```

The verification script validates:

```text
Ambient namespaces
        ↓
Waypoints
        ↓
PeerAuthentication
        ↓
STRICT mTLS
        ↓
AuthorizationPolicies
        ↓
Required authorization policies
```

The script must complete successfully before considering Phase 4 complete.

---

# 4.27 End-to-End Security Flow

The final security flow is:

```text
orders workload
       │
       ▼
    Ztunnel
       │
       │ mTLS / HBONE
       ▼
payments-waypoint
       │
       │ AuthorizationPolicy
       │
       │ orders namespace = ALLOW
       ▼
payments Service
       │
       ▼
payments workload
```

Unauthorized traffic:

```text
payments workload
       │
       ▼
    Ztunnel
       │
       │ mTLS
       ▼
orders-waypoint
       │
       │ AuthorizationPolicy
       │
       │ payments namespace = NOT ALLOWED
       ▼
      DENY
```

Authentication and authorization are therefore separate:

```text
mTLS
 │
 └── Authenticated identity

AuthorizationPolicy
 │
 └── Authorized operation
```

---

# 4.28 Production Security Model

The production model is:

```text
                 BFSI Zero Trust
                       │
        ┌──────────────┴──────────────┐
        │                             │
   Identity Layer               Authorization
        │                             │
   STRICT mTLS                 AuthorizationPolicy
        │                             │
     Ztunnel                      Waypoint
        │                             │
        └──────────────┬──────────────┘
                       │
                Application Service
```

Security decisions are therefore layered:

```text
Layer 3/4
   │
   └── Kubernetes NetworkPolicy

Layer 4
   │
   └── Ambient Ztunnel / mTLS

Layer 7
   │
   └── Waypoint / AuthorizationPolicy
```

This provides defense in depth rather than relying on a single security mechanism.

---

# 4.29 Operational Principles

The following production principles apply:

### Least privilege

Only required application flows are explicitly allowed.

### Default deny

Unknown service-to-service communication must not become implicitly trusted.

### Identity based security

Authorization is based on workload identity and namespace/service relationships rather than IP addresses.

### GitOps friendly

Security configuration is represented as Kubernetes manifests stored in Git.

### Separation of concerns

```text
Helm
 └── Istio platform installation

Kubernetes manifests
 └── Security policy

GitOps
 └── Deployment lifecycle
```

### Auditability

Every security change should be:

```text
Pull Request
    ↓
Review
    ↓
Merge
    ↓
GitOps deployment
    ↓
Cluster
```

---

# 4.30 Phase 4 Validation

Run the following commands:

```bash
kubectl get peerauthentication -A
```

```bash
kubectl get authorizationpolicy -A
```

```bash
kubectl get gateway -A
```

```bash
istioctl waypoint list --all
```

Verify all four namespaces:

```bash
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

Run the complete validation:

```bash
./scripts/verify.sh
```

Expected security state:

```text
payments
  ├── STRICT mTLS
  ├── default deny
  └── allow orders

orders
  ├── STRICT mTLS
  ├── default deny
  └── allow cart

cart
  ├── STRICT mTLS
  └── default deny

customers
  ├── STRICT mTLS
  ├── default deny
  └── allow orders
```

---

# 4.31 Phase 4 Checklist

* [ ] Phase 1 Ambient installation completed
* [ ] Phase 2 namespace enrollment completed
* [ ] Phase 3 Waypoints deployed
* [ ] `payments` uses Ambient Mode
* [ ] `orders` uses Ambient Mode
* [ ] `cart` uses Ambient Mode
* [ ] `customers` uses Ambient Mode
* [ ] `payments-waypoint` exists
* [ ] `orders-waypoint` exists
* [ ] `cart-waypoint` exists
* [ ] `customers-waypoint` exists
* [ ] STRICT mTLS configured for Payments
* [ ] STRICT mTLS configured for Orders
* [ ] STRICT mTLS configured for Cart
* [ ] STRICT mTLS configured for Customers
* [ ] Payments default-deny policy configured
* [ ] Orders default-deny policy configured
* [ ] Cart default-deny policy configured
* [ ] Customers default-deny policy configured
* [ ] Orders → Payments explicitly allowed
* [ ] Cart → Orders explicitly allowed
* [ ] Orders → Customers explicitly allowed
* [ ] Unauthorized flows remain denied
* [ ] AuthorizationPolicies target the appropriate Waypoints
* [ ] `deploy.sh` completes successfully
* [ ] `verify.sh` completes successfully
* [ ] No NetworkPolicy changes are introduced in this phase
* [ ] Security manifests are committed to Git

---

# 4.32 Phase 4 Architecture Summary

```text
                         Istiod
                           │
                           │
                    Security Configuration
                           │
             ┌─────────────┴─────────────┐
             │                           │
        PeerAuthentication        AuthorizationPolicy
             │                           │
        STRICT mTLS                  Waypoints
             │                           │
             ▼                           ▼
          Ztunnel                  Layer 7 Enforcement
             │                           │
             └─────────────┬─────────────┘
                           │
                     Application
                        Services
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
     payments            orders             cart
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                       customers
```

The security boundary is:

```text
Authenticate
     ↓
Encrypt
     ↓
Authorize
     ↓
Allow only required business traffic
```

**Phase 4 complete.**
