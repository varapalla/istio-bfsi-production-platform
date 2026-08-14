#!/usr/bin/env bash

set -Eeuo pipefail

ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-istio-ingress}"
EGRESS_NAMESPACE="${EGRESS_NAMESPACE:-payments}"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_check() {
  printf '[FAIL] %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_resource() {
  local description="$1"
  local resource="$2"
  local namespace="$3"

  if kubectl get "${resource}" -n "${namespace}" >/dev/null 2>&1; then
    pass "${description}"
  else
    fail_check "${description}"
  fi
}

check_crd() {
  local crd="$1"

  if kubectl get crd "${crd}" >/dev/null 2>&1; then
    pass "Gateway API CRD: ${crd}"
  else
    fail_check "Gateway API CRD: ${crd}"
  fi
}

check_gateway_condition() {
  local description="$1"
  local gateway="$2"
  local namespace="$3"

  local status

  status="$(
    kubectl get gateway "${gateway}" \
      -n "${namespace}" \
      -o jsonpath='{range .status.conditions[?(@.type=="Programmed")]}{.status}{end}' \
      2>/dev/null || true
  )"

  if [[ "${status}" == "True" ]]; then
    pass "${description}"
  else
    fail_check "${description} (Programmed=${status:-Unknown})"
  fi
}

check_route_condition() {
  local description="$1"
  local resource="$2"
  local name="$3"
  local namespace="$4"

  local status

  status="$(
    kubectl get "${resource}" "${name}" \
      -n "${namespace}" \
      -o jsonpath='{range .status.parents[*].conditions[?(@.type=="Accepted")]}{.status}{end}' \
      2>/dev/null || true
  )"

  if [[ "${status}" == "True" ]]; then
    pass "${description}"
  else
    fail_check "${description} (Accepted=${status:-Unknown})"
  fi
}

verify_prerequisites() {
  if kubectl cluster-info >/dev/null 2>&1; then
    pass "Kubernetes connectivity"
  else
    fail_check "Kubernetes connectivity"
  fi

  if kubectl get namespace "${ISTIO_NAMESPACE}" >/dev/null 2>&1; then
    pass "Istio namespace"
  else
    fail_check "Istio namespace"
  fi

  if kubectl get gatewayclass istio >/dev/null 2>&1; then
    pass "Istio GatewayClass"
  else
    fail_check "Istio GatewayClass"
  fi
}

verify_gateway_api() {
  check_crd "gateways.gateway.networking.k8s.io"
  check_crd "httproutes.gateway.networking.k8s.io"
  check_crd "tlsroutes.gateway.networking.k8s.io"
}

verify_ingress() {
  check_resource \
    "Ingress namespace" \
    "namespace/istio-ingress" \
    "default"

  check_resource \
    "Ingress Gateway" \
    "gateway/bfsi-ingress" \
    "${INGRESS_NAMESPACE}"

  check_gateway_condition \
    "Ingress Gateway programmed" \
    "bfsi-ingress" \
    "${INGRESS_NAMESPACE}"

  check_resource \
    "Ingress HTTPRoute" \
    "httproute/payments" \
    "${EGRESS_NAMESPACE}"

  check_route_condition \
    "Ingress HTTPRoute accepted" \
    "httproute" \
    "payments" \
    "${EGRESS_NAMESPACE}"

  check_resource \
    "Ingress AuthorizationPolicy" \
    "authorizationpolicy/bfsi-ingress-authorization" \
    "${INGRESS_NAMESPACE}"
}

verify_egress() {
  check_resource \
    "Egress Gateway" \
    "gateway/payments-egress" \
    "${EGRESS_NAMESPACE}"

  check_gateway_condition \
    "Egress Gateway programmed" \
    "payments-egress" \
    "${EGRESS_NAMESPACE}"

  check_resource \
    "Payment Provider ServiceEntry" \
    "serviceentry/payment-provider" \
    "${EGRESS_NAMESPACE}"

  check_resource \
    "Egress TLSRoute" \
    "tlsroute/payment-provider-to-egress" \
    "${EGRESS_NAMESPACE}"

  check_resource \
    "Egress AuthorizationPolicy" \
    "authorizationpolicy/payments-egress-authorization" \
    "${EGRESS_NAMESPACE}"
}

verify_workloads() {
  if kubectl get pods \
    -n "${INGRESS_NAMESPACE}" \
    -l gateway.networking.k8s.io/gateway-name=bfsi-ingress \
    --field-selector=status.phase=Running \
    -o name 2>/dev/null | grep -q .; then

    pass "Ingress Gateway workload running"
  else
    fail_check "Ingress Gateway workload running"
  fi

  if kubectl get pods \
    -n "${EGRESS_NAMESPACE}" \
    -l gateway.networking.k8s.io/gateway-name=payments-egress \
    --field-selector=status.phase=Running \
    -o name 2>/dev/null | grep -q .; then

    pass "Egress Gateway workload running"
  else
    fail_check "Egress Gateway workload running"
  fi
}

print_summary() {
  echo
  echo "=========================================="
  echo "Phase 6 Verification Summary"
  echo "=========================================="
  echo "Passed : ${PASS_COUNT}"
  echo "Failed : ${FAIL_COUNT}"
  echo "=========================================="

  if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo "Phase 6 Verification FAILED"
    exit 1
  fi

  echo "Phase 6 Verification PASSED"
}

main() {
  echo "=========================================="
  echo "Phase 6 - Ingress & Egress Verification"
  echo "=========================================="

  verify_prerequisites
  verify_gateway_api
  verify_ingress
  verify_egress
  verify_workloads

  print_summary
}

main "$@"