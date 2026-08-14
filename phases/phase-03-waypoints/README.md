# Phase 3 — Waypoint Proxies

This phase deploys **Istio Ambient Waypoint Proxies** for the application namespaces.

The reference architecture contains four application namespaces:

```text
payments
orders
cart
customers
```

Each namespace will receive a dedicated namespace-scoped waypoint:

```text
payments  → payments-waypoint
orders    → orders-waypoint
cart      → cart-waypoint
customers → customers-waypoint
```

Waypoints provide **Layer 7 processing** for Ambient workloads. Ztunnel remains responsible for the Ambient Layer 4 secure overlay.

---

# 3.1 Why Waypoints?

Ztunnel provides:

```text
L3/L4
mTLS
HBONE
L4 authorization
L4 telemetry
```

Waypoints provide additional L7 capabilities:

```text
HTTP routing
L7 authorization
HTTP telemetry
Advanced traffic management
VirtualService processing
```

Therefore:

```text
Ambient workload
       │
       ▼
    Ztunnel
       │
       │ L4
       ▼
   Waypoint
       │
       │ L7
       ▼
 Destination Service
```

Waypoints are not required for every Ambient workload. They are introduced when L7 processing is required.

---

# 3.2 Prerequisites

Phase 3 assumes the following phases are complete:

```text
Phase 0 → Kubernetes / Helm / istioctl prerequisites
Phase 1 → Istio Ambient installation
Phase 2 → Ambient namespace enrollment
```

Verify the four namespaces:

```bash id="2ihg5v"
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

Each namespace must have:

```text id="1xj6hl"
istio.io/dataplane-mode=ambient
```

---

# 3.3 Verify Gateway API

Waypoints use the Kubernetes Gateway API.

Check the Gateway API CRD:

```bash id="c7i0qk"
kubectl get crd gateways.gateway.networking.k8s.io
```

Verify the Gateway API resources:

```bash id="kpp6n2"
kubectl api-resources | grep gateway.networking.k8s.io
```

Expected resources include:

```text id="i7h2ly"
gatewayclasses
gateways
httproutes
referencegrants
```

If Gateway API is not installed, install the required CRDs:

```bash id="x7f4l3"
kubectl apply --server-side \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/experimental-install.yaml
```

Verify again:

```bash id="6c1l0x"
kubectl get crd | grep gateway.networking.k8s.io
```

---

# 3.4 Verify Istio Ambient Installation

Verify Istiod:

```bash id="j3bq3s"
kubectl get pods \
  -n istio-system \
  -l app=istiod
```

Verify Ztunnel:

```bash id="e1w8b4"
kubectl get pods \
  -n istio-system \
  -l app=ztunnel \
  -o wide
```

Verify Istio:

```bash id="q1cy83"
istioctl version
```

---

# 3.5 Deploy Payments Waypoint

Create a service-scoped waypoint for Payments:

```bash id="ks5q6f"
istioctl waypoint apply \
  --namespace payments \
  --name payments-waypoint \
  --for service \
  --wait
```

The waypoint is configured to process traffic destined for Kubernetes Services in the namespace.

Verify:

```bash id="x9u8dz"
kubectl get gateway \
  -n payments
```

Expected:

```text id="q9m5m4"
payments-waypoint
```

Check the waypoint:

```bash id="3c9d1p"
kubectl get gateway \
  payments-waypoint \
  -n payments
```

---

# 3.6 Deploy Orders Waypoint

```bash id="x2as8p"
istioctl waypoint apply \
  --namespace orders \
  --name orders-waypoint \
  --for service \
  --wait
```

Verify:

```bash id="yb4m1c"
kubectl get gateway \
  -n orders
```

Check:

```bash id="x3g4az"
kubectl get gateway \
  orders-waypoint \
  -n orders
```

---

# 3.7 Deploy Cart Waypoint

```bash id="4o4tgr"
istioctl waypoint apply \
  --namespace cart \
  --name cart-waypoint \
  --for service \
  --wait
```

Verify:

```bash id="a6qk4s"
kubectl get gateway \
  -n cart
```

Check:

```bash id="g0t8q3"
kubectl get gateway \
  cart-waypoint \
  -n cart
```

---

# 3.8 Deploy Customers Waypoint

```bash id="k7fd5d"
istioctl waypoint apply \
  --namespace customers \
  --name customers-waypoint \
  --for service \
  --wait
```

Verify:

```bash id="j7tq0c"
kubectl get gateway \
  -n customers
```

Check:

```bash id="6b0s9c"
kubectl get gateway \
  customers-waypoint \
  -n customers
```

---

# 3.9 Enroll Namespaces to Use Waypoints

A waypoint can exist without receiving application traffic.

The namespace must explicitly reference the waypoint using:

```text id="z4hx9u"
istio.io/use-waypoint=<waypoint-name>
```

The `--enroll-namespace` option performs this labeling automatically.

Apply the namespace enrollment:

```bash id="5s9j5m"
kubectl label namespace payments \
  istio.io/use-waypoint=payments-waypoint \
  --overwrite
```

```bash id="u9pk8j"
kubectl label namespace orders \
  istio.io/use-waypoint=orders-waypoint \
  --overwrite
```

```bash id="5qk2zz"
kubectl label namespace cart \
  istio.io/use-waypoint=cart-waypoint \
  --overwrite
```

```bash id="k9n8pf"
kubectl label namespace customers \
  istio.io/use-waypoint=customers-waypoint \
  --overwrite
```

---

# 3.10 Verify Waypoint Enrollment

Check Payments:

```bash id="z0q9bq"
kubectl get namespace payments \
  --show-labels
```

Expected:

```text id="tq6g55"
istio.io/dataplane-mode=ambient
istio.io/use-waypoint=payments-waypoint
```

Orders:

```bash id="f7c4f1"
kubectl get namespace orders \
  --show-labels
```

Cart:

```bash id="1f8l25"
kubectl get namespace cart \
  --show-labels
```

Customers:

```bash id="z1j7f8"
kubectl get namespace customers \
  --show-labels
```

---

# 3.11 Verify Waypoint Deployments

Istio manages the waypoint Deployment automatically after the Gateway resource is created.

Check Payments:

```bash id="2f7x4h"
kubectl get deployment \
  -n payments
```

Orders:

```bash id="70k8s1"
kubectl get deployment \
  -n orders
```

Cart:

```bash id="n4y1r4"
kubectl get deployment \
  -n cart
```

Customers:

```bash id="j8f7p0"
kubectl get deployment \
  -n customers
```

---

# 3.12 Verify Waypoint Pods

Payments:

```bash id="4l0n8f"
kubectl get pods \
  -n payments \
  -l gateway.istio.io/managed=istio.io-mesh-controller
```

Orders:

```bash id="7m2q9a"
kubectl get pods \
  -n orders \
  -l gateway.istio.io/managed=istio.io-mesh-controller
```

Cart:

```bash id="v5q3w7"
kubectl get pods \
  -n cart \
  -l gateway.istio.io/managed=istio.io-mesh-controller
```

Customers:

```bash id="n3f5s2"
kubectl get pods \
  -n customers \
  -l gateway.istio.io/managed=istio.io-mesh-controller
```

---

# 3.13 Verify Waypoint Status

Check all Gateway resources:

```bash id="6k3c8x"
kubectl get gateway \
  -A
```

Check waypoint status:

```bash id="j5y4t2"
kubectl get gateway \
  -A \
  -o wide
```

The waypoint should become programmed and have an associated address.

---

# 3.14 Verify Waypoints Using istioctl

List Payments waypoints:

```bash id="s6d0n2"
istioctl waypoint list \
  --namespace payments
```

Orders:

```bash id="2v5m3n"
istioctl waypoint list \
  --namespace orders
```

Cart:

```bash id="q4x6c1"
istioctl waypoint list \
  --namespace cart
```

Customers:

```bash id="z8v2m6"
istioctl waypoint list \
  --namespace customers
```

List all waypoints:

```bash id="f3n7j5"
istioctl waypoint list \
  --all
```

---

# 3.15 Verify Ambient and Waypoint Labels

Run:

```bash id="5d3z1q"
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

Expected model:

```text id="q4m2f9"
payments
  istio.io/dataplane-mode=ambient
  istio.io/use-waypoint=payments-waypoint

orders
  istio.io/dataplane-mode=ambient
  istio.io/use-waypoint=orders-waypoint

cart
  istio.io/dataplane-mode=ambient
  istio.io/use-waypoint=cart-waypoint

customers
  istio.io/dataplane-mode=ambient
  istio.io/use-waypoint=customers-waypoint
```

---

# 3.16 Waypoint Traffic Model

After namespace enrollment:

```text id="v0n9g5"
              payments workload
                     │
                     ▼
                  Ztunnel
                     │
                     │ HBONE
                     ▼
             payments-waypoint
                     │
                     │ L7
                     ▼
              payments Service
```

Orders:

```text id="g4f5c7"
              orders workload
                     │
                     ▼
                  Ztunnel
                     │
                     ▼
              orders-waypoint
                     │
                     ▼
               orders Service
```

The same model applies to:

```text id="m6y2x8"
cart
customers
```

---

# 3.17 Important Waypoint Behavior

The waypoint is configured with:

```text id="t6p9d1"
--for service
```

Therefore, it handles traffic destined for Services in the namespace.

Istio supports these waypoint traffic types:

```text id="4k8j1s"
service
workload
all
none
```

For this production reference architecture, the initial configuration uses:

```text id="q5v7w2"
service
```

This keeps the initial L7 processing scope focused on service traffic.

---

# 3.18 No AuthorizationPolicy Yet

Waypoints are deployed in this phase, but no authorization policies are configured yet.

Do not add:

```text id="2s9m4d"
AuthorizationPolicy
PeerAuthentication
NetworkPolicy
CiliumNetworkPolicy
```

Those controls belong to later phases.

The purpose of Phase 3 is:

```text id="m3p7x2"
Deploy Waypoint
      ↓
Enroll Namespace
      ↓
Verify Waypoint
      ↓
Verify Waypoint Pod
```

---

# 3.19 Run Deployment Script

Make the script executable:

```bash id="f8k2c4"
chmod +x scripts/deploy.sh
```

Run:

```bash id="n3m7p8"
./scripts/deploy.sh
```

The script deploys:

```text id="z5h1v7"
payments-waypoint
orders-waypoint
cart-waypoint
customers-waypoint
```

---

# 3.20 Run Verification Script

Make the script executable:

```bash id="x9f4k2"
chmod +x scripts/verify.sh
```

Run:

```bash id="j6m8q1"
./scripts/verify.sh
```

The verification script checks:

```text id="r8c3w5"
Namespace enrollment
        ↓
Waypoint Gateway
        ↓
Waypoint Deployment
        ↓
Waypoint Pods
        ↓
Waypoint status
        ↓
istioctl waypoint list
```

---

# Phase 3 Validation

Run:

```bash id="b5f7m2"
kubectl get namespace \
  payments \
  orders \
  cart \
  customers \
  --show-labels
```

```bash id="d8q4s1"
kubectl get gateway -A
```

```bash id="h3k6v9"
kubectl get deployment -A
```

```bash id="p7x2c5"
kubectl get pods -A \
  -l gateway.istio.io/managed=istio.io-mesh-controller
```

```bash id="k9m4r7"
istioctl waypoint list --all
```

---

# Phase 3 Architecture

```text id="v5n8c2"
                         Istiod
                           │
                           ▼
                    Ambient Control Plane
                           │
                           ▼
                         Ztunnel
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    payments            orders              cart
        │                  │                  │
        ▼                  ▼                  ▼
payments-waypoint   orders-waypoint    cart-waypoint
        │                  │                  │
        ▼                  ▼                  ▼
 Payments Service     Orders Service      Cart Service
        │
        │
        ▼
customers-waypoint
        │
        ▼
 Customers Service
```

---

# Phase 3 Checklist

* [ ] Gateway API CRDs are installed
* [ ] `payments` namespace is enrolled in Ambient Mode
* [ ] `orders` namespace is enrolled in Ambient Mode
* [ ] `cart` namespace is enrolled in Ambient Mode
* [ ] `customers` namespace is enrolled in Ambient Mode
* [ ] `payments-waypoint` is deployed
* [ ] `orders-waypoint` is deployed
* [ ] `cart-waypoint` is deployed
* [ ] `customers-waypoint` is deployed
* [ ] Payments namespace uses `payments-waypoint`
* [ ] Orders namespace uses `orders-waypoint`
* [ ] Cart namespace uses `cart-waypoint`
* [ ] Customers namespace uses `customers-waypoint`
* [ ] All waypoint Gateway resources are programmed
* [ ] All waypoint Pods are Running
* [ ] Waypoints use `service` traffic mode
* [ ] `istioctl waypoint list` shows all four waypoints
* [ ] `deploy.sh` executes successfully
* [ ] `verify.sh` passes
* [ ] No AuthorizationPolicy is configured
* [ ] No NetworkPolicy is configured
* [ ] No CiliumNetworkPolicy is configured

---

# Next Phase

Once all Phase 3 checklist items pass, proceed to:

```text id="q7c4m1"
Phase 4 — Security
```

Phase 4 will introduce:

```text id="a8f2k6"
PeerAuthentication
        ↓
Strict mTLS
        ↓
AuthorizationPolicy
        ↓
Service-to-service authorization
        ↓
Deny-by-default
```
