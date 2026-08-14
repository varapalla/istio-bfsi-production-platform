# Phase 6 – Ingress & Egress

Production-grade north-south ingress and controlled egress traffic management for Istio Ambient Mesh.

## 1. Objective

This phase implements:

- Kubernetes Gateway API based ingress
- HTTPS ingress Gateway
- HTTPRoute based application routing
- Ingress AuthorizationPolicy
- Controlled egress Gateway
- External ServiceEntry definitions
- TLSRoute based HTTPS egress routing
- Egress AuthorizationPolicy
- Positive and negative traffic validation
- GitOps-ready deployment

Traffic model:

                    Internet
                       |
                       v
                Ingress Gateway
                       |
                   HTTPRoute
                       |
                       v
                Istio Ambient
                       |
             +---------+---------+
             |         |         |
             v         v         v
          orders    payments    cart
                       |
                       v
                 Egress Gateway
                       |
              +--------+--------+
              |        |        |
              v        v        v
             KYC     Fraud    Payment
                              Provider


## 2. Directory Structure

phase-06-ingress-egress/
|
├── README.md
├── scripts/
│   ├── deploy.sh
│   └── verify.sh
├── ingress/
│   ├── namespace.yaml
│   ├── gateway.yaml
│   ├── http-route.yaml
│   └── authorization-policy.yaml
└── egress/
    ├── gateway.yaml
    ├── service-entry.yaml
    ├── tls-route.yaml
    └── authorization-policy.yaml


## 3. Prerequisites

Phase 6 assumes:

- Kubernetes cluster is available
- Istio Ambient is already installed
- Istio CNI is installed
- ztunnel is healthy
- Application namespaces are already enrolled into Ambient
- Phase 5 NetworkPolicy/Cilium controls are available
- `kubectl` is configured
- `helm` is installed
- `istioctl` is installed

Expected Istio version:

    ISTIO_VERSION=1.30.3


## 4. Gateway API

Istio 1.30 uses Gateway API v1.5.x.

Verify:

    kubectl get crd gateways.gateway.networking.k8s.io
    kubectl get crd httproutes.gateway.networking.k8s.io
    kubectl get crd tlsroutes.gateway.networking.k8s.io

Verify GatewayClass:

    kubectl get gatewayclass

Expected:

    NAME    CONTROLLER
    istio   istio.io/gateway-controller

Istio 1.30 upgraded its Gateway API dependency to v1.5.1 and reads TLSRoute from the standard Gateway API channel.


## 5. Deployment

Deployment is performed using:

    scripts/deploy.sh

Make the script executable:

    chmod +x scripts/deploy.sh

Run:

    ./scripts/deploy.sh

The script:

1. Validates kubectl access.
2. Validates Istio.
3. Validates Gateway API CRDs.
4. Validates Istio GatewayClass.
5. Deploys the ingress namespace.
6. Deploys the ingress Gateway.
7. Deploys HTTPRoute.
8. Deploys ingress AuthorizationPolicy.
9. Deploys egress Gateway.
10. Deploys ServiceEntry.
11. Deploys TLSRoute.
12. Deploys egress AuthorizationPolicy.
13. Performs basic resource validation.


## 6. Deployment Order

The deployment order is intentionally controlled.

    Gateway API
          |
          v
    Ingress Namespace
          |
          v
    Ingress Gateway
          |
          v
    HTTPRoute
          |
          v
    Ingress AuthorizationPolicy
          |
          v
    Egress Gateway
          |
          v
    ServiceEntry
          |
          v
    TLSRoute
          |
          v
    Egress AuthorizationPolicy


## 7. Verification

Verification is performed using:

    scripts/verify.sh

Make the script executable:

    chmod +x scripts/verify.sh

Run:

    ./scripts/verify.sh

The verification script validates:

- Kubernetes connectivity
- Istio installation
- Gateway API CRDs
- Istio GatewayClass
- Ingress Gateway
- Ingress Gateway status
- HTTPRoute
- Ingress AuthorizationPolicy
- Egress Gateway
- Egress Gateway status
- ServiceEntry
- TLSRoute
- Egress AuthorizationPolicy
- Gateway workloads
- Gateway Services


## 8. Ingress Verification

Verify Gateway:

    kubectl get gateway bfsi-ingress -n istio-ingress

Detailed:

    kubectl describe gateway bfsi-ingress -n istio-ingress

Expected:

    Accepted=True
    Programmed=True

Verify HTTPRoute:

    kubectl get httproute -A

Detailed:

    kubectl describe httproute payments -n payments

Expected:

    Accepted=True
    ResolvedRefs=True

Verify AuthorizationPolicy:

    kubectl get authorizationpolicy -n istio-ingress


## 9. Egress Verification

Verify Gateway:

    kubectl get gateway payments-egress -n payments

Detailed:

    kubectl describe gateway payments-egress -n payments

Expected:

    Accepted=True
    Programmed=True

Verify ServiceEntry:

    kubectl get serviceentry payment-provider -n payments

Verify TLSRoute:

    kubectl get tlsroute -n payments

Verify AuthorizationPolicy:

    kubectl get authorizationpolicy -n payments


## 10. Gateway Workload Verification

Gateway API creates and manages the gateway workload.

Verify ingress:

    kubectl get pods -n istio-ingress
    kubectl get svc -n istio-ingress

Verify egress:

    kubectl get pods -n payments
    kubectl get svc -n payments

Gateway-generated workloads can be identified using:

    gateway.networking.k8s.io/gateway-name


## 11. Functional Verification

### Ingress positive test

From an external client:

    curl -vk https://payments.bfsi.example.com/payments

Expected:

    Client
      |
      v
    Load Balancer
      |
      v
    Ingress Gateway
      |
      v
    HTTPRoute
      |
      v
    payments Service
      |
      v
    payments Pod


### Egress positive test

From the payments workload:

    kubectl exec -n payments <payments-pod> -- \
      curl -vk https://api.payment-provider.example

Expected:

    payments
       |
       v
    Ambient
       |
       v
    Egress Gateway
       |
       v
    External Payment Provider


### Egress negative test

Attempt to access an unauthorized destination:

    kubectl exec -n payments <payments-pod> -- \
      curl -vk https://unauthorized.example.com

Expected:

    DENIED


## 12. NetworkPolicy / Cilium Integration

Istio and NetworkPolicy/Cilium provide defense in depth.

Istio controls application-aware traffic:

    Service
    Route
    Host
    Identity
    Authorization

NetworkPolicy/Cilium controls network-level communication:

    Namespace
    Pod
    IP/CIDR
    Port
    Network path

The egress gateway must not be treated as the only control preventing Internet bypass.

NetworkPolicy/Cilium should prevent workloads from bypassing the approved egress path.


## 13. GitOps

For production:

    Git
      |
      v
    Pull Request
      |
      v
    CI Validation
      |
      v
    Argo CD
      |
      v
    Kubernetes

The manifests under this phase are the GitOps source of truth.

Direct `kubectl apply` is intended for controlled development/validation only.

Production changes should be promoted through the GitOps workflow.


## 14. Troubleshooting

### Gateway not programmed

    kubectl describe gateway <gateway-name> -n <namespace>

Check:

- GatewayClass
- listener
- hostname
- allowedRoutes
- certificate references
- Gateway API CRDs


### HTTPRoute not accepted

    kubectl describe httproute <route-name> -n <namespace>

Check:

- parentRefs
- Gateway namespace
- hostname
- backendRefs
- allowedRoutes


### Egress not working

Check:

    kubectl get serviceentry -n payments
    kubectl get gateway -n payments
    kubectl get tlsroute -n payments

Then check NetworkPolicy/Cilium.

Also inspect the generated gateway:

    kubectl get pods -n payments
    kubectl logs -l gateway.networking.k8s.io/gateway-name=payments-egress -n payments


## 15. Final Verification

Run:

    ./scripts/verify.sh

Expected result:

    ==========================================
    Phase 6 Verification
    ==========================================

    [PASS] Kubernetes connectivity
    [PASS] Istio installation
    [PASS] Gateway API CRDs
    [PASS] Istio GatewayClass
    [PASS] Ingress Gateway
    [PASS] Ingress Gateway programmed
    [PASS] HTTPRoute
    [PASS] Ingress AuthorizationPolicy
    [PASS] Egress Gateway
    [PASS] Egress Gateway programmed
    [PASS] ServiceEntry
    [PASS] TLSRoute
    [PASS] Egress AuthorizationPolicy

    ==========================================
    Phase 6 Verification PASSED
    ==========================================


## 16. Production Checklist

- [ ] Gateway API CRDs installed
- [ ] Istio GatewayClass available
- [ ] Ingress Gateway programmed
- [ ] HTTPRoute accepted
- [ ] Ingress AuthorizationPolicy applied
- [ ] Egress Gateway programmed
- [ ] ServiceEntry registered
- [ ] TLSRoute accepted
- [ ] Egress AuthorizationPolicy applied
- [ ] Gateway workloads healthy
- [ ] Gateway Services available
- [ ] Ingress positive test successful
- [ ] Approved egress positive test successful
- [ ] Unauthorized egress negative test denied
- [ ] NetworkPolicy/Cilium bypass protection verified
- [ ] GitOps source of truth established
- [ ] Production changes performed through PR and Argo CD