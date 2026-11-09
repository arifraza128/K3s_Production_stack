# Operational Runbook — Phoenix Platform (K3s Production Stack)

## 1. Full Cluster Rebuild (Phoenix Recovery)
When an EC2 node in `ap-south-1` is lost or replaced:
```bash
# 1. Provision replacement EC2 node & attach Elastic IP (13.207.161.55)
make apply

# 2. Wait for cloud-init K3s bootstrap
ssh -i my-k3s-key.pem ubuntu@13.207.161.55 "cat /var/log/k3s-ready.log && kubectl get nodes"

# 3. CRITICAL: Restore Sealed Secrets master key BEFORE ArgoCD syncs workloads
kubectl apply -f /tmp/sealed-secrets-master-key-latest.yaml

# 4. Bootstrap ArgoCD and deploy Root Application (App-of-Apps)
make bootstrap-gitops

# 5. Restore Gitea PostgreSQL database dump (if PVC was recreated)
make dr-drill
```

---

## 2. Incident Response Playbooks

### Playbook A: `TestApiHigh5xxErrorRate` Alert Fires in Discord
1. **Verify symptom:**
   ```bash
   kubectl logs -n default -l app=test-api --tail=100
   ```
2. **Check if synthetic `/fail` test or image regression:**
   ```bash
   kubectl describe deployment test-api -n default
   ```
3. **Rollback via GitOps:** Revert the offending commit on `main` (`git revert HEAD && git push`); ArgoCD will reconcile within `15s`.

### Playbook B: Kyverno Blocks Pod Creation (`verify-cosign-image-signatures`)
1. **Symptom:** `admission webhook "mutate.kyverno.svc-fail" denied the request: image signature verification failed`.
2. **Resolution:** Ensure the image was built and signed by `.github/workflows/ci-supply-chain.yaml` and uses the `ghcr.io/arifraza128/*` image reference.

### Playbook C: Let's Encrypt TLS Certificate Stuck in `Pending`
1. **Inspect ACME challenge:**
   ```bash
   kubectl describe challenge -A
   kubectl get certificate -A
   ```
2. **Resolution:** Confirm port `80` is reachable from `0.0.0.0/0` in `aws_security_group.k3s_sg` so HTTP-01 challenge validation succeeds for `13.207.161.55.sslip.io`.

