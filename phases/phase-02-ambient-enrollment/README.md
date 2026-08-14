# Phase 2 — Ambient Namespace Enrollment

This phase enrolls application namespaces into **Istio Ambient Mode**.

The reference architecture uses four application namespaces:

```text
payments
orders
cart
customers
```

Each namespace is enrolled using:

```text
istio.io/dataplane-mode=ambient
```

This phase focuses only on **Ambient namespace enrollment and validation**.

---

# 2.1 Application Namespaces

The application namespaces are:

| Namespace   | Purpose                     |
| ----------- | --------------------------- |
| `payments`  | Payment processing services |
| `orders`    | Order management services   |
| `cart`      | Shopping/cart services      |
| `customers` | Customer-related services   |

---

# 2.2 Ambient Enrollment Model

```text
                    Istio Ambient
                         │
              ┌──────────┴──────────┐
              │                     │
        Istio Control Plane      Ztunnel
              │                     │
              └──────────┬──────────┘
                         │
                 Istio CNI
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    payments          orders             cart
        │                │                │
        └────────────────┼────────────────┘
                         │
                     customers
```

Each namespace is enrolled by applying:

```text
istio.io/dataplane-mode=ambient
```

---

# 2.3 Create Payments Namespace

Apply:

```bash
kubectl apply \
  -f namespaces/payments.yaml
```

Verify:

```bash
kubectl get namespace payments
```

Check labels:

```bash
kubectl get namespace payments \
  --show-labels
```

Expected:

```text
istio.io/dataplane-mode=ambient
```

---

# 2.4 Create Orders Namespace

Apply:

```bash
kubectl apply \
  -f namespaces/orders.yaml
```

Verify:

```bash
kubectl get namespace orders
```

Check labels:

```bash
kubectl get namespace orders \
  --show-labels
```

Expected:

```text
istio.io/dataplane-mode=ambient
```

---

# 2.5 Create Cart Namespace

Apply:

```bash
kubectl apply \
  -f namespaces/cart.yaml
```

Verify:

```bash
kubectl get namespace cart
```

Check labels:

```bash
kubectl get namespace cart \
  --show-labels
```

Expected:

```text
istio.io/dataplane-mode=ambient
```

---

# 2.6 Create Customers Namespace

Apply:

```bash
kubectl apply \
  -f namespaces/customers.yaml
```

Verify:

```bash
kubectl get namespace customers
```

Check labels:

```bash
kubectl get namespace customers \
  --show-labels
```

Expected:

```text
istio.io/dataplane-mode=ambient
```

---

# 2.7 Apply All Namespaces

All four namespaces can be created together:

```bash
kubectl apply \
  -f namespaces/
```

Verify:

```bash
kubectl get namespace \
  payments \
  orders \
  cart \
  customers
```

---

# 2.8 Verify Ambient Labels

Verify Payments:

```bash
kubectl get namespace payments \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
```

Expected:

```text
ambient
```

Verify Orders:

```bash
kubectl get namespace orders \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
```

Expected:

```text
ambient
```

Verify Cart:

```bash
kubectl get namespace cart \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
```

Expected:

```text
ambient
```

Verify Customers:

```bash
kubectl get namespace customers \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
```

Expected:

```text
ambient
```

---

# 2.9 Verify All Namespace Labels

Run:

```bash
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

All four namespaces should contain:

```text
istio.io/dataplane-mode=ambient
```

---

# 2.10 Enroll Namespaces Using Script

Make the script executable:

```bash
chmod +x scripts/enroll.sh
```

Run:

```bash
./scripts/enroll.sh
```

The script validates and enrolls:

```text
payments
orders
cart
customers
```

into Ambient Mode.

---

# 2.11 Verify Ztunnel

Check ztunnel:

```bash
kubectl get daemonset \
  -n istio-system \
  ztunnel
```

Check ztunnel Pods:

```bash
kubectl get pods \
  -n istio-system \
  -l app=ztunnel \
  -o wide
```

Ztunnel should be running on the Kubernetes nodes participating in the Ambient data plane.

---

# 2.12 Deploy Application Workloads

Application deployments should be maintained separately under:

```text
applications/
```

For example:

```text
applications/
├── payments/
├── orders/
├── cart/
└── customers/
```

Once workloads are deployed into the enrolled namespaces, verify:

```bash
kubectl get pods -n payments
```

```bash
kubectl get pods -n orders
```

```bash
kubectl get pods -n cart
```

```bash
kubectl get pods -n customers
```

---

# 2.13 Verify Ambient Workloads

List workloads known by ztunnel:

```bash
istioctl ztunnel-config workloads
```

Filter Payments:

```bash
istioctl ztunnel-config workloads | grep payments
```

Filter Orders:

```bash
istioctl ztunnel-config workloads | grep orders
```

Filter Cart:

```bash
istioctl ztunnel-config workloads | grep cart
```

Filter Customers:

```bash
istioctl ztunnel-config workloads | grep customers
```

Workloads should appear in ztunnel after they are deployed into the Ambient-enrolled namespaces.

---

# 2.14 Verify Ztunnel Endpoints

Run:

```bash
istioctl ztunnel-config endpoints
```

This allows verification that Ambient workloads and their endpoints are known to ztunnel.

---

# 2.15 Verify No Sidecar Injection

Ambient Mode does not require an Envoy sidecar inside every application Pod.

For example:

```bash
kubectl get pods \
  -n payments \
  -o jsonpath='{range .items[*]}{.metadata.name}{" : "}{.spec.containers[*].name}{"\n"}{end}'
```

Repeat for:

```bash
kubectl get pods \
  -n orders \
  -o jsonpath='{range .items[*]}{.metadata.name}{" : "}{.spec.containers[*].name}{"\n"}{end}'
```

```bash
kubectl get pods \
  -n cart \
  -o jsonpath='{range .items[*]}{.metadata.name}{" : "}{.spec.containers[*].name}{"\n"}{end}'
```

```bash
kubectl get pods \
  -n customers \
  -o jsonpath='{range .items[*]}{.metadata.name}{" : "}{.spec.containers[*].name}{"\n"}{end}'
```

The application Pods should not contain an injected `istio-proxy` sidecar.

---

# 2.16 Ambient Traffic Model

After enrollment:

```text
payments
   │
   │
   ▼
Istio CNI
   │
   ▼
Ztunnel
   │
   ▼
Ambient Network
```

The same model applies to:

```text
orders
cart
customers
```

At this stage, no application-specific authorization rules are configured.

---

# 2.17 Namespace Enrollment Script

The complete enrollment process can be executed using:

```bash
./scripts/enroll.sh
```

The script handles:

```text
payments
orders
cart
customers
```

and ensures:

```text
istio.io/dataplane-mode=ambient
```

is present.

---

# 2.18 Verification Script

Make the script executable:

```bash
chmod +x scripts/verify.sh
```

Run:

```bash
./scripts/verify.sh
```

The verification script checks:

```text
Kubernetes connectivity
        │
        ▼
Namespace existence
        │
        ▼
Ambient labels
        │
        ▼
Ztunnel status
        │
        ▼
Ambient workload discovery
```

---

# 2.19 Phase 2 Validation

Run:

```bash
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

Verify ztunnel:

```bash
kubectl get daemonset \
  -n istio-system \
  ztunnel
```

Check Ambient workloads:

```bash
istioctl ztunnel-config workloads
```

Check endpoints:

```bash
istioctl ztunnel-config endpoints
```

Run the verification script:

```bash
./scripts/verify.sh
```

---

# Phase 2 Architecture

```text
                         Istiod
                           │
                           │
                  Ambient Control Plane
                           │
                           ▼
                       Istio CNI
                           │
                           ▼
                        Ztunnel
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    payments            orders              cart
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                       customers
```

---

# 2.20 Scope Boundaries

The following are intentionally **not configured in Phase 2**:

```text
Waypoints
AuthorizationPolicy
PeerAuthentication
NetworkPolicy
CiliumNetworkPolicy
Ingress
Egress
Retries
Timeouts
Circuit Breaking
Observability
```

These controls are introduced in their respective phases.

---

# Phase 2 Checklist

* [ ] `payments` namespace exists
* [ ] `orders` namespace exists
* [ ] `cart` namespace exists
* [ ] `customers` namespace exists
* [ ] `payments` has `istio.io/dataplane-mode=ambient`
* [ ] `orders` has `istio.io/dataplane-mode=ambient`
* [ ] `cart` has `istio.io/dataplane-mode=ambient`
* [ ] `customers` has `istio.io/dataplane-mode=ambient`
* [ ] Ztunnel DaemonSet is healthy
* [ ] Application workloads are deployed into the enrolled namespaces
* [ ] Payments workloads are discovered by ztunnel
* [ ] Orders workloads are discovered by ztunnel
* [ ] Cart workloads are discovered by ztunnel
* [ ] Customers workloads are discovered by ztunnel
* [ ] Application Pods do not contain an `istio-proxy` sidecar
* [ ] Ztunnel endpoints are visible
* [ ] `enroll.sh` executes successfully
* [ ] `verify.sh` passes
* [ ] No Phase 3+ policies have been introduced

---

# Next Phase

Once all Phase 2 checklist items pass, proceed to:

```text
Phase 3 — Waypoints
```

Phase 3 will introduce **waypoint proxies** for Layer 7 traffic processing and policy enforcement.
