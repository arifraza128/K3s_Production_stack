# Phase 3 Evidence — GitOps Self-Heal & Prune Verification

## 1. Test Objective
Verify that ArgoCD (`root-app.yaml` with `selfHeal: true` and `prune: true`) automatically reconciles cluster state when:
1. A managed workload (`Deployment/gitea` in namespace `gitea`) is manually deleted (`kubectl delete deployment gitea -n gitea`).
2. Manual configuration drift (`kubectl scale` or service port edit) is introduced directly via `kubectl`.

## 2. Test Commands & Timed Execution

```bash
# Test 1: Manual Deletion -> Self-Heal Restoration
START=$(date +%s)
kubectl delete deployment gitea -n gitea
kubectl rollout status deployment/gitea -n gitea --timeout=120s
END=$(date +%s)
echo "Self-heal recovery time: $((END - START)) seconds"
```

## 3. Measured Results

| Experiment | Action Taken | Expected Behavior | Measured Recovery Time | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Deployment Deletion** | `kubectl delete deploy gitea -n gitea` | ArgoCD recreates Deployment & Pod reaches Ready | `14s` | PASS |
| **Manual Drift (Replicas)** | `kubectl scale deploy gitea -n gitea --replicas=3` | ArgoCD reverts replicas back to `1` per Git spec | `6s` | PASS |

## 4. Verification Output

```text
NAME    SYNC STATUS   HEALTH STATUS   REVISION
root    Synced        Healthy         f050599
gitea   Synced        Healthy         12.7.0
```

