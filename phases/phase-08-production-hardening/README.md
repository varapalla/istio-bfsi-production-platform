# Phase 8 — Production Hardening & Resilience

## 1. Objective

Harden the Istio Ambient BFSI platform for production by implementing:

- Strict mTLS
- Authorization policies
- Optional JWT authentication
- Pod Disruption Budgets
- Gateway disruption protection
- PriorityClass
- ResourceQuota
- LimitRange
- Pod Security Admission audit/warn controls

Phase 8 does not modify application Deployment manifests.

Application-specific configuration such as:

- replicas
- resource requests/limits
- topology spread
- affinity
- tolerations
- priorityClassName

remains owned by the application GitOps manifests.

---

## 2. Architecture

```text
                         Internet
                            |
                            v
                    +---------------+
                    | Ingress       |
                    | Gateway       |
                    +-------+-------+
                            |
                            v
                  +-------------------+
                  | Istio Ambient     |
                  | STRICT mTLS       |
                  +---------+---------+
                            |
              +-------------+-------------+
              |             |             |
              v             v             v
           orders        payments        cart
                            |
                            v
                    +---------------+
                    | Egress Gateway|
                    +-------+-------+
                            |
                            v
                    External Provider