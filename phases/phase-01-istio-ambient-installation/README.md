# Phase 1 — Production Istio Ambient Installation with Helm

This phase installs the Istio Ambient data plane using Helm.

## Components

```text
Istio Base
    │
    ▼
Istiod
    │
    ▼
Istio CNI
    │
    ▼
Ztunnel
```

Istio recommends Helm for production Ambient installations because the control-plane and data-plane components are installed and upgraded separately.

---

## 1.1 Set Istio Version

```bash
export ISTIO_VERSION=1.30.3
```

Verify:

```bash
echo ${ISTIO_VERSION}
```

---

## 1.2 Add Istio Helm Repository

```bash
helm repo add istio \
  https://istio-release.storage.googleapis.com/charts

helm repo update
```

Verify:

```bash
helm search repo istio
```

---

## 1.3 Create Istio Namespace

```bash
kubectl create namespace istio-system
```

Verify:

```bash
kubectl get namespace istio-system
```

---

# 1.4 Install Istio Base

The `base` chart installs Istio CRDs and the cluster-scoped resources required by Istio.

```bash
helm upgrade --install istio-base istio/base \
  --namespace istio-system \
  --version ${ISTIO_VERSION} \
  --wait
```

Verify:

```bash
helm status istio-base -n istio-system
```

Check Istio CRDs:

```bash
kubectl get crd | grep istio.io
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

The values file enables the Ambient profile.

Verify:

```bash
helm status istiod -n istio-system
```

```bash
kubectl get deployment istiod -n istio-system
```

```bash
kubectl get pods -n istio-system -l app=istiod
```

---

# 1.6 Install Istio CNI

Istio CNI configures traffic redirection for workloads enrolled into Ambient Mode.

```bash
helm upgrade --install istio-cni istio/cni \
  --namespace istio-system \
  --version ${ISTIO_VERSION} \
  --values values/cni-values.yaml \
  --wait
```

Verify:

```bash
helm status istio-cni -n istio-system
```

```bash
kubectl get daemonset -n istio-system
```

Check CNI:

```bash
kubectl get pods -n istio-system \
  -l k8s-app=istio-cni-node
```

---

# 1.7 Install Ztunnel

Ztunnel is the node-level Layer 4 proxy used by Istio Ambient Mode.

```bash
helm upgrade --install ztunnel istio/ztunnel \
  --namespace istio-system \
  --version ${ISTIO_VERSION} \
  --values values/ztunnel-values.yaml \
  --wait
```

Verify:

```bash
helm status ztunnel -n istio-system
```

```bash
kubectl get daemonset ztunnel -n istio-system
```

Check ztunnel pods:

```bash
kubectl get pods \
  -n istio-system \
  -l app=ztunnel \
  -o wide
```

---

# 1.8 Verify Installation

Check all Helm releases:

```bash
helm list -n istio-system
```

Expected:

```text
istio-base
istiod
istio-cni
ztunnel
```

Check pods:

```bash
kubectl get pods -n istio-system
```

Check deployments:

```bash
kubectl get deployments -n istio-system
```

Check DaemonSets:

```bash
kubectl get daemonsets -n istio-system
```

---

# 1.9 Istio Validation

Run:

```bash
istioctl version
```

Run the cluster precheck:

```bash
istioctl x precheck
```

Verify the installation:

```bash
istioctl verify-install
```

---

# 1.10 Verify Ztunnel

List Ambient workloads:

```bash
istioctl ztunnel-config workloads
```

Check ztunnel logs:

```bash
kubectl logs \
  -n istio-system \
  -l app=ztunnel \
  --tail=100
```

---

# 1.11 Installation Script

The complete installation can be executed through:

```bash
./scripts/install.sh
```

Make the script executable:

```bash
chmod +x scripts/install.sh
```

---

# 1.12 Verification Script

Run:

```bash
./scripts/verify.sh
```

The script validates:

* Kubernetes connectivity
* Istio Helm releases
* Istiod
* Istio CNI
* Ztunnel
* Istio precheck
* Istio installation
* Ambient workloads

---

# Installation Order

```text
istio-base
    │
    ▼
istiod
    │
    ▼
istio-cni
    │
    ▼
ztunnel
```

After Phase 1 is complete, proceed to:

```text
Phase 2 — Ambient Namespace Enrollment
```

