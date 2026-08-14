# Phase 7 – Observability & Telemetry

## 1. Objective

Phase 7 establishes observability for the Istio Ambient production platform.

The objective is to provide visibility into:

* Service-to-service traffic
* Request rate
* Request latency
* HTTP response codes
* 4xx/5xx errors
* Ambient ztunnel traffic
* Ingress Gateway traffic
* Egress Gateway traffic
* Istio telemetry
* Prometheus metrics
* Grafana dashboards

The observability flow is:

```text
                    Istio Ambient
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
          ztunnel     Gateways    Workloads
             |           |           |
             +-----------+-----------+
                         |
                         v
                  Istio Metrics
                         |
                         v
                    Prometheus
                         |
                         v
                      Grafana
                         |
          +--------------+--------------+
          |              |              |
          v              v              v
       Istio          ztunnel        Gateway
      Dashboard      Dashboard      Dashboard
```

---

# 2. Scope

Phase 7 covers:

```text
Telemetry
├── Istio Telemetry API
└── Access logging

Metrics
├── Prometheus-compatible Istio metrics
└── ServiceMonitor where Prometheus Operator is installed

Dashboards
├── Mesh
├── Service
├── Workload
├── ztunnel
├── Ingress Gateway
└── Egress Gateway
```

Phase 7 does not install:

* Istio
* Istio CNI
* ztunnel
* Ingress Gateway
* Egress Gateway
* NetworkPolicy
* Cilium
* AuthorizationPolicy

Those are covered by previous phases.

---

# 3. Directory Structure

```text
phase-07-observability/
├── README.md
│
├── scripts/
│   ├── deploy.sh
│   └── verify.sh
│
├── telemetry/
│   ├── telemetry.yaml
│   └── access-logging.yaml
│
├── metrics/
│   └── service-monitor.yaml
│
└── dashboards/
    ├── istio/
    │   ├── mesh-overview.json
    │   ├── service-overview.json
    │   └── workload-overview.json
    │
    ├── ztunnel/
    │   └── ztunnel-overview.json
    │
    └── gateways/
        ├── ingress-gateway.json
        └── egress-gateway.json
```

---

# 4. Prerequisites

Phase 7 assumes the following phases are already completed:

```text
Phase 1 → Istio Ambient installation
Phase 2 → Namespace enrollment
Phase 3 → Application communication
Phase 4 → mTLS and authorization
Phase 5 → NetworkPolicy / Cilium
Phase 6 → Ingress and Egress
```

Verify Kubernetes:

```bash
kubectl cluster-info
```

Verify Istio:

```bash
kubectl get pods -n istio-system
```

Verify ztunnel:

```bash
kubectl get pods \
  -n istio-system \
  -l app=ztunnel
```

---

# 5. Observability Architecture

The application traffic is:

```text
orders
   |
   | mTLS
   v
payments
   |
   | egress
   v
Egress Gateway
   |
   v
Payment Provider
```

Observability is collected across this path:

```text
orders
   |
   v
ztunnel
   |
   v
payments
   |
   v
ztunnel
   |
   v
Egress Gateway
   |
   v
External Provider
```

Metrics are exposed to Prometheus.

---

# 6. Istio Telemetry

Istio Telemetry API is used to configure mesh-level telemetry.

File:

```text
telemetry/telemetry.yaml
```

Example:

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  metrics:
    - providers:
        - name: prometheus
```

The configuration should remain minimal initially.

Avoid creating excessive custom metric dimensions because high-cardinality metrics can significantly increase Prometheus resource consumption.

---

# 7. Access Logging

File:

```text
telemetry/access-logging.yaml
```

Example:

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-access-logging
  namespace: istio-system
spec:
  accessLogging:
    - providers:
        - name: envoy
```

Access logs are used for request-level troubleshooting.

Example:

```text
Client
  |
  v
Ingress Gateway
  |
  v
payments
  |
  v
Egress Gateway
  |
  v
External Provider
```

Access logs help identify:

* Request source
* Destination
* Response code
* Request duration
* Protocol
* Connection failures

---

# 8. BFSI Logging Security

Do not log sensitive financial or customer information.

Never intentionally place the following into access logs:

```text
PAN
CVV
PIN
Authentication tokens
Authorization headers
Session credentials
Customer PII
Payment payloads
Secrets
```

Logging should contain operational metadata rather than sensitive transaction data.

Recommended:

```text
timestamp
source
destination
method
path
response code
latency
request ID
trace ID
```

---

# 9. Prometheus

Istio exposes Prometheus-compatible metrics.

Typical Istio metrics include:

```text
istio_requests_total
istio_request_duration_milliseconds
```

The basic flow is:

```text
Istio
  |
  v
Metrics endpoint
  |
  v
Prometheus
```

Verify Prometheus exists in the platform:

```bash
kubectl get pods -A | grep prometheus
```

Verify services:

```bash
kubectl get svc -A | grep prometheus
```

Phase 7 does not assume that Prometheus must be installed by this phase.

Prometheus should normally be managed as part of the platform monitoring stack.

---

# 10. ServiceMonitor

File:

```text
metrics/service-monitor.yaml
```

`ServiceMonitor` is only applicable when Prometheus Operator is installed.

Verify:

```bash
kubectl get crd servicemonitors.monitoring.coreos.com
```

If the CRD exists:

```bash
kubectl get servicemonitor -A
```

If Prometheus Operator is not installed, the ServiceMonitor should not be deployed.

---

# 11. Dashboards

Dashboards provide the operational view of the metrics collected by Prometheus.

```text
Prometheus
    |
    v
Grafana
    |
    +── Istio Mesh
    |
    +── Service
    |
    +── Workload
    |
    +── ztunnel
    |
    +── Ingress Gateway
    |
    └── Egress Gateway
```

Dashboard JSON files contain:

* Grafana panels
* PromQL queries
* Variables
* Units
* Dashboard layout
* Panel configuration

They do not contain metric data.

The actual data comes from Prometheus.

---

# 12. Mesh Dashboard

File:

```text
dashboards/istio/mesh-overview.json
```

Purpose:

```text
Overall mesh health
```

Important signals:

```text
Request rate
5xx rate
P95 latency
Response codes
Destination services
```

Use this dashboard for high-level incident detection.

---

# 13. Service Dashboard

File:

```text
dashboards/istio/service-overview.json
```

Purpose:

```text
Individual service health
```

Example:

```text
payments
orders
cart
customers
```

Important signals:

```text
Request rate
5xx rate
P95 latency
Source workloads
```

Example troubleshooting:

```text
payments
   |
   +── Request rate      2,000 req/s
   |
   +── 5xx               8%
   |
   +── P95 latency       1.8 sec
```

This immediately indicates a potential service problem.

---

# 14. Workload Dashboard

File:

```text
dashboards/istio/workload-overview.json
```

Purpose:

```text
Individual workload-level visibility
```

Signals:

```text
Inbound traffic
Outbound traffic
mTLS traffic
5xx responses
```

This is useful when one workload is unhealthy while the overall service appears healthy.

---

# 15. ztunnel Dashboard

File:

```text
dashboards/ztunnel/ztunnel-overview.json
```

Ambient does not place an Envoy sidecar in every application Pod.

Instead:

```text
Node
 |
 +── ztunnel
      |
      +── workload A
      +── workload B
      +── workload C
```

Therefore ztunnel needs its own operational visibility.

The dashboard should cover:

```text
TCP connections
Traffic volume
Bytes sent
Bytes received
ztunnel resource usage
```

This helps identify Ambient dataplane problems.

---

# 16. Ingress Gateway Dashboard

File:

```text
dashboards/gateways/ingress-gateway.json
```

Traffic:

```text
Internet
   |
   v
Ingress Gateway
   |
   v
Application
```

Monitor:

```text
Request rate
5xx rate
P95 latency
HTTP response codes
```

This helps identify whether a problem is occurring at the external entry point or inside the application.

---

# 17. Egress Gateway Dashboard

File:

```text
dashboards/gateways/egress-gateway.json
```

Traffic:

```text
payments
   |
   v
Egress Gateway
   |
   v
Payment Provider
```

Monitor:

```text
Egress request rate
Egress errors
P95 latency
External destinations
```

This is particularly important for BFSI applications with external:

```text
Payment Providers
Fraud Providers
KYC Providers
Banking APIs
Credit Providers
```

---

# 18. Deployment

Deployment follows the same pattern as previous phases.

```bash
cd /home/laborant/istio-bfsi-production-platform/phases/phase-07-observability
```

Make scripts executable:

```bash
chmod +x scripts/deploy.sh
chmod +x scripts/verify.sh
```

Deploy:

```bash
./scripts/deploy.sh
```

The deployment script performs:

```text
Prerequisites
    |
    v
Telemetry
    |
    v
Access Logging
    |
    v
ServiceMonitor
```

`ServiceMonitor` is deployed only when Prometheus Operator is available.

---

# 19. Verification

Run:

```bash
./scripts/verify.sh
```

The verification script checks:

```text
Telemetry CRD
Telemetry resources
Access logging
Prometheus Operator
ServiceMonitor
Istio system Pods
ztunnel
Ingress Gateway
Egress Gateway
```

---

# 20. Manual Verification

Verify Telemetry:

```bash
kubectl get telemetry -A
```

Verify:

```bash
kubectl describe telemetry \
  mesh-default \
  -n istio-system
```

Verify access logging:

```bash
kubectl get telemetry \
  -n istio-system
```

Verify ztunnel:

```bash
kubectl get pods \
  -n istio-system \
  -l app=ztunnel
```

Verify gateways:

```bash
kubectl get pods \
  -n istio-ingress
```

```bash
kubectl get pods \
  -n payments
```

---

# 21. Prometheus Verification

Check Prometheus:

```bash
kubectl get pods -A | grep prometheus
```

Port-forward if required:

```bash
kubectl port-forward \
  -n monitoring \
  svc/prometheus \
  9090:9090
```

Then query:

```promql
istio_requests_total
```

Request rate:

```promql
sum(rate(istio_requests_total[5m]))
```

5xx rate:

```promql
sum(
  rate(
    istio_requests_total{
      response_code=~"5.."
    }[5m]
  )
)
```

---

# 22. Grafana Verification

Verify Grafana:

```bash
kubectl get pods -A | grep grafana
```

Port-forward if required:

```bash
kubectl port-forward \
  -n monitoring \
  svc/grafana \
  3000:3000
```

Open Grafana and verify the Prometheus datasource.

Then import the dashboard JSON files.

---

# 23. Dashboard Validation

Before considering the dashboards production-ready, verify the PromQL queries directly in Prometheus.

For example:

```promql
sum(rate(istio_requests_total[5m]))
```

Then verify:

```promql
sum(
  rate(
    istio_requests_total{
      response_code=~"5.."
    }[5m]
  )
)
```

Then verify latency:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(
      istio_request_duration_milliseconds_bucket[5m]
    )
  )
)
```

Only dashboards whose queries return valid data should be promoted to production.

---

# 24. Production Troubleshooting Flow

For an application incident:

```text
Alert
  |
  v
Mesh Dashboard
  |
  v
Service Dashboard
  |
  v
Workload Dashboard
  |
  v
ztunnel Dashboard
  |
  v
Ingress / Egress Dashboard
  |
  v
Application Logs
```

Example:

```text
payments latency increased
          |
          v
Service Dashboard
          |
          v
P95 increased
          |
          v
Workload Dashboard
          |
          v
Outbound latency increased
          |
          v
Egress Dashboard
          |
          v
Payment Provider latency
          |
          v
External dependency issue
```

---

# 25. Observability Security

Prometheus and Grafana should not be publicly exposed.

Use:

```text
Internal Load Balancer
VPN
SSO
RBAC
NetworkPolicy
```

Grafana access should be restricted according to platform RBAC.

Prometheus should also remain an internal platform service.

---

# 26. GitOps

Production flow:

```text
Developer
    |
    v
Git Pull Request
    |
    v
CI
    |
    v
Review
    |
    v
Argo CD
    |
    v
Kubernetes
```

Dashboard JSON files are also stored in Git.

This provides:

* Version control
* Review
* Rollback
* Auditability
* Environment consistency

---

# 27. Production Checklist

* [ ] Istio Telemetry CRD available
* [ ] Mesh Telemetry deployed
* [ ] Access logging configured
* [ ] Sensitive data excluded from logs
* [ ] Prometheus available
* [ ] Istio metrics visible
* [ ] ztunnel metrics visible
* [ ] Ingress Gateway metrics visible
* [ ] Egress Gateway metrics visible
* [ ] ServiceMonitor deployed where applicable
* [ ] Grafana available
* [ ] Prometheus datasource configured
* [ ] Mesh dashboard validated
* [ ] Service dashboard validated
* [ ] Workload dashboard validated
* [ ] ztunnel dashboard validated
* [ ] Ingress dashboard validated
* [ ] Egress dashboard validated
* [ ] PromQL queries validated
* [ ] Grafana access protected
* [ ] Prometheus access protected
* [ ] Dashboards stored in Git
* [ ] Changes managed through GitOps

---

# 28. Phase 7 Success Criteria

Phase 7 is complete when the platform can answer:

```text
How much traffic is flowing?
        ✓

Which services are receiving traffic?
        ✓

What is the request latency?
        ✓

Which services are returning 5xx?
        ✓

Is Ambient ztunnel healthy?
        ✓

Is ingress healthy?
        ✓

Is egress healthy?
        ✓

Is an external dependency slow?
        ✓

Can SRE troubleshoot an incident using metrics?
        ✓

Are dashboards version-controlled?
        ✓
```

The final observability architecture is:

```text
                         BFSI APPLICATIONS
                                |
                                v
                         ISTIO AMBIENT
                                |
              +-----------------+----------------+
              |                 |                |
              v                 v                v
           ztunnel          Ingress           Egress
              |             Gateway           Gateway
              |                 |                |
              +-----------------+----------------+
                                |
                                v
                         Istio Telemetry
                                |
                  +-------------+-------------+
                  |                           |
                  v                           v
              Metrics                     Access Logs
                  |                           |
                  v                           v
             Prometheus                   Log Platform
                  |
                  v
               Grafana
                  |
       +----------+----------+
       |          |          |
       v          v          v
     Istio      ztunnel    Gateway
   Dashboards  Dashboard  Dashboards
```

**Phase 7 is therefore the observability layer for the security and traffic controls established in Phases 1–6.**
