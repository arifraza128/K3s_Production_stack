# Phase 3 Evidence — GitOps Self-Heal & Drift Reconciliation Verification

- **Measured Timestamp (UTC):** `2026-11-21T15:49:45Z`
- **Cluster Context:** `default`
- **Root Application:** [`gitops/root-app.yaml`](../../gitops/root-app.yaml) (`selfHeal: true`, `prune: true`)

---

## 1. Measured Self-Heal & Drift Results

| Experiment | Action Taken | Expected Behavior | Measured Recovery Time | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Deployment Deletion** | `kubectl delete deploy test-api -n default` | Workload recreated from Git & pods reach `Ready` | **`8s`** | **PASS** |
| **Manual Drift (Replicas)** | `kubectl scale deploy test-api -n default --replicas=3` | Replicas reverted back to `2` per Git spec | **`3s`** | **PASS** |

---

## 2. Cluster Verification Output

```text
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                                                                       SELECTOR
deployment.apps/test-api   2/2     2            2           11s   test-api     ghcr.io/arifraza128/k3s_production_stack/test-api:7c2dd7e97f77a83f20b632153a0dd1bb0908fbe9   app=test-api

NAME                            READY   STATUS        RESTARTS      AGE     IP            NODE              NOMINATED NODE   READINESS GATES
pod/test-api-6f8fcb5b7d-fhxpv   1/1     Terminating   0             6m36s   10.42.0.175   ip-172-31-20-41   <none>           <none>
pod/test-api-6f8fcb5b7d-l7w8n   1/1     Terminating   7 (41m ago)   11d     10.42.0.123   ip-172-31-20-41   <none>           <none>
pod/test-api-769d987d4f-5t4jp   1/1     Running       0             12s     10.42.0.185   ip-172-31-20-41   <none>           <none>
pod/test-api-769d987d4f-j667c   1/1     Running       0             12s     10.42.0.186   ip-172-31-20-41   <none>           <none>
pod/test-api-769d987d4f-k5xp2   0/1     Terminating   0             5s      10.42.0.187   ip-172-31-20-41   <none>           <none>
```
