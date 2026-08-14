# Phase 1 — Production Istio Ambient Installation with Helm

This phase installs **Istio Ambient Mode** on the Kubernetes cluster using Helm.

The installation consists of four primary components:

```text
Istio Base
    │
    ▼
Istiod
    │
    ├── Istio CNI
    │
    └── Ztunnel
```

## Components

| Component    | Purpose                                |
| ------------ | -------------------------------------- |
| `istio/base` | Installs Istio CRDs and base resources |
| `istiod`     | Istio control plane                    |
| `istio/cni`  | Configures Ambient traffic redirection |
| `ztunnel`    | Ambient Layer 4 zero-trust proxy       |

---

# 1.1 Set Istio Version

Use the same Istio version validated during Phase 0.

```bash
export ISTIO_VERSION=1.30.3
```

Verify:

```bash
echo ${ISTIO_VERSION}
```

Expected:

```text
1.30.3
```

---

# 1.2 Verify Helm Repository

Check the Istio repository:

```bash
helm repo list
```

If it does not exist:

```bash
helm repo add istio \
  https://istio-release.storage.googleapis.com/charts
```

Update the repository:

```bash
helm repo update
```

Verify the available charts:

```bash
helm search repo istio
```

Expected charts:

```text
istio/base
istio/istiod
istio/cni
istio/ztunnel
istio/gateway
```

---

# 1.3 Create Istio Namespace

Create the Istio system namespace:

```bash
kubectl create namespace istio-system
```

If the namespace already exists:

```bash
kubectl get namespace istio-system
```

Verify:

```bash
kubectl get namespace istio-system
```

---

# 1.4 Install Istio Base

Install the Istio base chart:

```bash
helm upgrade --install istio-base istio/base \
  --namespace istio-system \
  --version ${ISTIO_VERSION} \
  --wait
```

Verify the Helm release:

```bash
helm status istio-base \
  --namespace istio-system
```

Check Istio CRDs:

```bash
kubectl get crd | grep istio.io
```

Verify the Helm release:

```bash
helm list -n istio-system
```

---

# 1.5 Install Istiod

Install the Istio control plane using the Ambient profile.

```bash
helm upgrade --install istiod istio/istiod \
  --namespace istio-system \
  --version ${ISTIO_VERSION} \
  --values values/istiod-values.yaml \
  --wait
```

The values file contains:

```yaml
profile: ambient
```

Verify the deployment:

```bash
kubectl get deployment istiod \
  -n istio-system
```

Verify the pod:

```bash
kubectl get pods \
  -n istio-system \
  -l app=istiod
```

Check Istiod logs if required:

```bash
kubectl logs \
  -n istio-system \
  -l app=istiod \
  --tail=100
```

---

# 1.6 Install Istio CNI

Istio CNI is required for Ambient Mode traffic redirection.

Install:

```bash
helm upgrade --install istio-cni istio/cni \
  --namespace istio-system \
  --version ${ISTIO_VERSION} \
  --values values/cni-values.yaml \
  --wait
```

Verify the Helm release:

```bash
helm status istio-cni \
  -n istio-system
```

Check the DaemonSet:

```bash
kubectl get daemonset \
  -n istio-system
```

Check CNI pods:

```bash
kubectl get pods \
  -n istio-system \
  -l k8s-app=istio-cni-node \
  -o wide
```

Check CNI logs:

```bash
kubectl logs \
  -n istio-system \
  -l k8s-app=istio-cni-node \
  --tail=100
```

---

# 1.7 Install Ztunnel

Ztunnel is the Ambient data-plane proxy deployed as a DaemonSet on the Kubernetes nodes.

Install:

```bash
helm upgrade --install ztunnel istio/ztunnel \
  --namespace istio-system \
  --version ${ISTIO_VERSION} \
  --values values/ztunnel-values.yaml \
  --wait
```

Verify:

```bash
helm status ztunnel \
  -n istio-system
```

Check the DaemonSet:

```bash
kubectl get daemonset ztunnel \
  -n istio-system
```

Check ztunnel pods:

```bash
kubectl get pods \
  -n istio-system \
  -l app=ztunnel \
  -o wide
```

Check ztunnel logs:

```bash
kubectl logs \
  -n istio-system \
  -l app=ztunnel \
  --tail=100
```

---

# 1.8 Verify Istio Helm Releases

List all Istio Helm releases:

```bash
helm list \
  -n istio-system
```

Expected:

```text
NAME
istio-base
istiod
istio-cni
ztunnel
```

Check each release:

```bash
helm status istio-base -n istio-system
helm status istiod -n istio-system
helm status istio-cni -n istio-system
helm status ztunnel -n istio-system
```

---

# 1.9 Verify Istio Pods

```bash
kubectl get pods \
  -n istio-system \
  -o wide
```

Expected core components:

```text
istiod-xxxxxxxxxx-xxxxx       Running
istio-cni-node-xxxxx          Running
istio-cni-node-xxxxx          Running
ztunnel-xxxxx                 Running
ztunnel-xxxxx                 Running
```

Check for non-running pods:

```bash
kubectl get pods \
  -n istio-system \
  --field-selector=status.phase!=Running
```

---

# 1.10 Verify Deployments and DaemonSets

Deployments:

```bash
kubectl get deployments \
  -n istio-system
```

DaemonSets:

```bash
kubectl get daemonsets \
  -n istio-system
```

Expected:

```text
istiod
istio-cni-node
ztunnel
```

---

# 1.11 Verify Istio Installation

Check Istio version:

```bash
istioctl version
```

Run the Istio precheck:

```bash
istioctl x precheck
```

Verify installation:

```bash
istioctl verify-install
```

The installation should complete without critical errors.

---

# 1.12 Verify Ztunnel

Check ztunnel configuration:

```bash
istioctl ztunnel-config workloads
```

Check ztunnel endpoints:

```bash
istioctl ztunnel-config endpoints
```

Check ztunnel clusters:

```bash
istioctl ztunnel-config clusters
```

Check ztunnel listeners:

```bash
istioctl ztunnel-config listeners
```

At this stage, there may be no application workloads enrolled in Ambient Mode yet.

That is expected.

Application namespace enrollment happens in **Phase 2**.

---

# 1.13 Run Installation Script

The installation can also be automated using:

```bash
./scripts/install.sh
```

If required:

```bash
chmod +x scripts/install.sh
```

Execute:

```bash
./scripts/install.sh
```

The script installs:

```text
istio-base
    ↓
istiod
    ↓
istio-cni
    ↓
ztunnel
```

---

# 1.14 Run Verification Script

Make the script executable:

```bash
chmod +x scripts/verify.sh
```

Run:

```bash
./scripts/verify.sh
```

The script validates:

```text
Kubernetes connectivity
        ↓
Helm releases
        ↓
Istiod
        ↓
Istio CNI
        ↓
Ztunnel
        ↓
Istio version
        ↓
Istio precheck
        ↓
Istio installation
        ↓
Ambient workloads
```

---

# 1.15 Production Verification

Verify the complete Istio system:

```bash
kubectl get pods -n istio-system
```

```bash
kubectl get deployments -n istio-system
```

```bash
kubectl get daemonsets -n istio-system
```

```bash
helm list -n istio-system
```

```bash
istioctl version
```

```bash
istioctl x precheck
```

```bash
istioctl verify-install
```

```bash
istioctl ztunnel-config workloads
```

---

# Phase 1 Checklist

* [ ] `ISTIO_VERSION` is defined
* [ ] Istio Helm repository is configured
* [ ] `istio-system` namespace exists
* [ ] `istio-base` Helm release is installed
* [ ] Istio CRDs are installed
* [ ] `istiod` Helm release is installed
* [ ] Istiod pod is `Running`
* [ ] `istio-cni` Helm release is installed
* [ ] Istio CNI DaemonSet is healthy
* [ ] Ztunnel Helm release is installed
* [ ] Ztunnel DaemonSet is healthy
* [ ] All Istio system pods are `Running`
* [ ] `istioctl x precheck` passes
* [ ] `istioctl verify-install` passes
* [ ] Ztunnel configuration is accessible
* [ ] No application namespace is enrolled yet
* [ ] Installation scripts execute successfully
* [ ] Verification script passes

---

# Phase 1 Architecture

After completing this phase:

```text
                    Kubernetes Cluster
                           │
                           │
                  ┌────────▼────────┐
                  │     Istiod      │
                  │ Control Plane   │
                  └────────┬────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
       ┌──────▼──────┐          ┌──────▼──────┐
       │ Istio CNI   │          │   Ztunnel   │
       │             │          │  Data Plane │
       └─────────────┘          └──────┬──────┘
                                       │
                              Ambient Workloads
                              (Phase 2)
```

---

# Next Phase

Once all Phase 1 checklist items pass, proceed to:

```text
Phase 2 — Ambient Namespace Enrollment
```

Phase 2 will cover:

```text
Namespace labeling
        ↓
Ambient enrollment
        ↓
Workload deployment
        ↓
Ztunnel workload discovery
        ↓
Ambient traffic validation
```

