# Phase 4 Evidence — Negative Test 1: Kyverno Admission Webhook Denial

- **Measured Timestamp (UTC):** `2026-11-09T17:05:04Z`
- **Cluster Context:** `default`
- **Verification Script:** `scripts/verify-phase4.sh`

---

## 1. Active Kyverno ClusterPolicies

```text
NAME                                      ADMISSION   BACKGROUND   READY   AGE   MESSAGE
disallow-privileged-and-host-namespaces   true        true         True    66s   Ready
require-pod-requests-and-limits           true        true         True    65s   Ready
verify-cosign-image-signatures            true        false        True    64s   Ready
```

---

## 2. Negative Test 1a: Unsigned Container Image (`verify-cosign-image-signatures`)

**Command:** `kubectl apply` of Pod `default/unsigned-image-test` using unsigned image `ghcr.io/arifraza128/unsigned-test:v1`

**Result:** **PASS (Rejected by Admission Webhook, exit code 1)**

```text
Error from server: error when creating "/tmp/tmp.WzFMU8YBxo": admission webhook "mutate.kyverno.svc-fail" denied the request: 

resource Pod/default/unsigned-image-test was blocked due to the following policies 

verify-cosign-image-signatures:
  verify-ghcr-keyless-signature: 'failed to verify image ghcr.io/arifraza128/unsigned-test:v1: .attestors[0].entries[0].keyless: GET https://ghcr.io/token?scope=repository%3Aarifraza128%2Funsigned-test%3Apull&service=ghcr.io: DENIED: requested access to the resource is denied'
```

---

## 3. Negative Test 1b: Privileged Container (`disallow-privileged-and-host-namespaces`)

**Command:** `kubectl apply` of Pod `default/privileged-pod-test` with `securityContext.privileged: true`

**Result:** **PASS (Rejected by Admission Webhook, exit code 1)**

```text
Error from server: error when creating "/tmp/tmp.08fdPaAqGn": admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Pod/default/privileged-pod-test was blocked due to the following policies 

disallow-privileged-and-host-namespaces:
  deny-privileged-containers: 'validation error: Privileged mode and privilege escalation are disallowed. rule deny-privileged-containers failed at path /spec/containers/0/securityContext/privileged/'
```

---

## 4. Negative Test 1c: Missing Resource Requests & Limits (`require-pod-requests-and-limits`)

**Command:** `kubectl apply` of Pod `default/no-limits-pod-test` without CPU/memory requests and limits

**Result:** **PASS (Rejected by Admission Webhook, exit code 1)**

```text
Error from server: error when creating "/tmp/tmp.iBUHlz4QvX": admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Pod/default/no-limits-pod-test was blocked due to the following policies 

require-pod-requests-and-limits:
  validate-resources: 'validation error: CPU and memory resource requests and limits are required for all containers. rule validate-resources failed at path /spec/containers/0/resources/limits/'
```
