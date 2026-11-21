# Phase 3 Evidence — GitOps Self-Heal & Drift Reconciliation Verification

- **Measured Timestamp (UTC):** `2026-11-21T15:58:01Z`
- **Cluster Context:** `default`
- **Root Application:** [`gitops/root-app.yaml`](../../gitops/root-app.yaml) (`selfHeal: true`, `prune: true`)

---

## 1. Measured Self-Heal & Drift Results

| Experiment | Action Taken | Expected Behavior | Measured Recovery Time | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Deployment Deletion** | `kubectl delete deploy test-api -n default` | Workload recreated from Git & pods reach `Ready` | **`8s`** | **PASS** |
| **Manual Drift (Replicas)** | `kubectl scale deploy test-api -n default --replicas=3` | Replicas reverted back to `2` per Git spec | **`2s`** | **PASS** |

---

## 2. Cluster Verification Output

```text
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                                                                       SELECTOR
deployment.apps/test-api   2/2     2            2           11s   test-api     ghcr.io/arifraza128/k3s_production_stack/test-api:7c2dd7e97f77a83f20b632153a0dd1bb0908fbe9   app=test-api

NAME                            READY   STATUS        RESTARTS   AGE     IP            NODE              NOMINATED NODE   READINESS GATES
pod/test-api-56d9d4b985-7ld9v   1/1     Terminating   0          7m59s   10.42.0.191   ip-172-31-20-41   <none>           <none>
pod/test-api-56d9d4b985-hm9m7   1/1     Terminating   0          7m53s   10.42.0.192   ip-172-31-20-41   <none>           <none>
pod/test-api-769d987d4f-cxbtg   0/1     Terminating   0          4s      10.42.0.203   ip-172-31-20-41   <none>           <none>
pod/test-api-769d987d4f-hd69t   1/1     Running       0          10s     10.42.0.202   ip-172-31-20-41   <none>           <none>
pod/test-api-769d987d4f-tqqlj   1/1     Running       0          10s     10.42.0.201   ip-172-31-20-41   <none>           <none>
```
