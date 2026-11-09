# Phase 3 Evidence — GitOps Self-Heal & Prune Verification

## 1. Test Objective
Verify that ArgoCD ([`gitops/root-app.yaml`](../../gitops/root-app.yaml) with `selfHeal: true` and `prune: true`) automatically reconciles cluster state when:
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

> Per [`AGENTS.md`](../../AGENTS.md) Golden Rule #3: Values remain `"not yet measured"` until the live cluster command output and screenshot are captured.

| Experiment | Action Taken | Expected Behavior | Measured Recovery Time | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Deployment Deletion** | `kubectl delete deploy gitea -n gitea` | ArgoCD recreates Deployment & Pod reaches Ready | `not yet measured` | Pending live run |
| **Manual Drift (Replicas)** | `kubectl scale deploy gitea -n gitea --replicas=3` | ArgoCD reverts replicas back to `1` per Git spec | `not yet measured` | Pending live run |
