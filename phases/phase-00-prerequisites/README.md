# Phase 0 — Production Prerequisites

This phase prepares the Kubernetes cluster and administration workstation before installing **Istio Ambient Mode**.

## Prerequisites

The following components are required:

```text
Kubernetes Cluster
      │
      ├── kubectl
      ├── Helm
      ├── istioctl
      ├── Gateway API CRDs
      └── Kubernetes CNI
```

---

## 0.1 Kubernetes Cluster

Verify the Kubernetes cluster:

```bash
kubectl cluster-info
```

Check the Kubernetes version:

```bash
kubectl version
```

Check cluster nodes:

```bash
kubectl get nodes -o wide
```

Verify all nodes are Ready:

```bash
kubectl get nodes
```

Expected:

```text
NAME       STATUS   ROLES    AGE   VERSION
worker-1   Ready    <none>   ...   v1.xx.x
worker-2   Ready    <none>   ...   v1.xx.x
worker-3   Ready    <none>   ...   v1.xx.x
```

Check all workloads:

```bash
kubectl get pods -A
```

---

## 0.2 kubectl

Verify the kubectl client:

```bash
kubectl version --client
```

Check the current Kubernetes context:

```bash
kubectl config current-context
```

List available contexts:

```bash
kubectl config get-contexts
```

Verify API server connectivity:

```bash
kubectl cluster-info
```

Verify the current identity has the required permissions:

```bash
kubectl auth can-i '*' '*'
```

> In production, use an appropriately scoped Kubernetes identity rather than unrestricted cluster-admin access.

---

## 0.3 Helm

Istio will be installed using Helm.

Verify Helm:

```bash
helm version
```

Verify Helm repositories:

```bash
helm repo list
```

Add the official Istio Helm repository:

```bash
helm repo add istio \
  https://istio-release.storage.googleapis.com/charts
```

Update the repository:

```bash
helm repo update
```

Verify Istio charts:

```bash
helm search repo istio
```

Expected charts include:

```text
istio/base
istio/istiod
istio/cni
istio/ztunnel
istio/gateway
```

---

## 0.4 Istio Version

Define the Istio version once and reuse it throughout the installation:

```bash
export ISTIO_VERSION=1.30.3
```

Verify:

```bash
echo ${ISTIO_VERSION}
```

> Keep the Istio version consistent across `istio/base`, `istiod`, `istio/cni`, and `ztunnel`.

---

## 0.5 istioctl

Download the Istio distribution:

```bash
curl -L https://istio.io/downloadIstio | sh -
```

Move into the downloaded directory:

```bash
cd istio-${ISTIO_VERSION}
```

Add `istioctl` to the PATH:

```bash
export PATH=$PWD/bin:$PATH
```

Verify:

```bash
istioctl version
```

Check the client:

```bash
istioctl version --remote=false
```

---

## 0.6 Istio Precheck

Before installing Istio, run:

```bash
istioctl x precheck
```

The cluster should pass the precheck without critical issues.

Example:

```text
✔ No issues found when checking the cluster.
```

If the precheck reports issues, resolve them before continuing with Phase 1.

---

## 0.7 Gateway API

Check whether Gateway API CRDs are installed:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

Check all Gateway API CRDs:

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

If Gateway API is not installed:

```bash
kubectl apply --server-side \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/experimental-install.yaml
```

Verify:

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

Expected CRDs include:

```text
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
```

---

## 0.8 Kubernetes CNI

Istio Ambient Mode requires a functioning Kubernetes CNI.

Identify the cluster CNI:

```bash
kubectl get pods -A | \
  grep -Ei 'calico|cilium|aws-node|flannel|canal'
```

### Amazon EKS

Check AWS VPC CNI:

```bash
kubectl get daemonset -n kube-system aws-node
```

Check AWS VPC CNI pods:

```bash
kubectl get pods -n kube-system \
  -l k8s-app=aws-node
```

### Cilium

```bash
kubectl get pods -n kube-system \
  -l k8s-app=cilium
```

### Calico

```bash
kubectl get pods -n kube-system \
  -l k8s-app=calico-node
```

The cluster CNI must be healthy before installing Istio CNI.

---

## 0.9 CoreDNS

Verify CoreDNS:

```bash
kubectl get pods -n kube-system \
  -l k8s-app=kube-dns
```

Check the CoreDNS service:

```bash
kubectl get svc -n kube-system kube-dns
```

Test Kubernetes DNS:

```bash
kubectl run dns-test \
  --image=busybox:1.36 \
  --rm -it \
  --restart=Never \
  -- nslookup kubernetes.default
```

Expected output should resolve the Kubernetes service.

---

## 0.10 Node Health

Check nodes:

```bash
kubectl get nodes -o wide
```

Check node conditions:

```bash
kubectl describe nodes
```

Check node resource availability:

```bash
kubectl top nodes
```

> `kubectl top nodes` requires Metrics Server. Metrics Server is not a prerequisite for Istio itself.

---

## 0.11 Cluster Connectivity

Verify the Kubernetes API:

```bash
kubectl cluster-info
```

Verify namespaces:

```bash
kubectl get namespaces
```

Verify system workloads:

```bash
kubectl get pods -n kube-system
```

Verify services:

```bash
kubectl get svc -A
```

---

# Phase 0 Validation

Run the following commands before moving to Phase 1:

```bash
kubectl cluster-info
```

```bash
kubectl get nodes
```

```bash
kubectl get pods -A
```

```bash
kubectl version --client
```

```bash
helm version
```

```bash
helm search repo istio
```

```bash
istioctl version
```

```bash
istioctl x precheck
```

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

```bash
kubectl get pods -n kube-system
```

---

# Phase 0 Checklist

* [ ] Kubernetes cluster is available
* [ ] All Kubernetes nodes are `Ready`
* [ ] `kubectl` is installed and configured
* [ ] Kubernetes API is reachable
* [ ] Helm is installed
* [ ] Istio Helm repository is configured
* [ ] `ISTIO_VERSION` is defined
* [ ] `istioctl` is installed
* [ ] `istioctl x precheck` passes
* [ ] Gateway API CRDs are installed
* [ ] Kubernetes CNI is healthy
* [ ] CoreDNS is healthy
* [ ] Cluster workloads are healthy

---

# Next Phase

Once all Phase 0 checks pass, proceed to:

```text
Phase 1 — Production Istio Ambient Installation with Helm
```

Phase 1 installs:

```text
istio-base
    ↓
istiod
    ↓
istio-cni
    ↓
ztunnel
```

