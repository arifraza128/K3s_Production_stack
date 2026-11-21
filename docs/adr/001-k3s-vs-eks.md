# ADR 001: Single-Node K3s on ARM64 EC2 vs Managed AWS EKS

- **Status:** Accepted
- **Date:** 2026-11-07
- **Evidence Link:** [`docs/cost.md`](../cost.md) · [`docs/evidence/dr-drill/scorecard.md`](../evidence/dr-drill/scorecard.md)

## Context
We need a production-grade Kubernetes control plane in `ap-south-1` capable of running GitOps (ArgoCD), supply-chain admission control (Kyverno), observability (Prometheus/Grafana/Alertmanager), ingress/TLS (`ingress-nginx` + `cert-manager`), and stateful workloads (Gitea + PostgreSQL) under a strict cloud budget ceiling (`< $20/month`).

## Decision
Provision **K3s (`v1.37.2+k3s1`)** on an AWS Graviton2 ARM64 EC2 instance (`t4g.medium`, 2 vCPU, 4 GiB RAM + 4 GiB persistent swapfile) with a 30 GB `gp3` root volume via two-stack Terraform (`bootstrap` + `platform`) and `cloud-init`.

## Alternatives Considered
1. **Managed AWS EKS:** `$73.00/month` control-plane fee alone (before worker nodes or ALB), exceeding our budget by `>5x`.
2. **Kubeadm on EC2:** Higher control-plane memory footprint (`~1.4 GB` vs `~550 MB` for K3s) leaving insufficient headroom on a single 4 GiB node.
3. **Local Kind / Minikube:** Cannot demonstrate real cloud IAM instance profiles, Elastic IP preservation across `terraform destroy`, or public Let's Encrypt ACME HTTP-01 TLS certificates.

## Consequences
- ✅ **Eliminates the `$73/month` EKS control-plane fee** (`~85%` total cost reduction; instance can also be stopped between sessions).
- ✅ **Fast recovery:** Single binary control plane + GitOps allows full workload recovery in `11s–15s` RTO ([`scorecard.md`](../evidence/dr-drill/scorecard.md)).
- ❌ **Single-node control plane:** No multi-AZ control-plane HA; mitigated by decoupling persistent resources (`terraform/bootstrap`) from disposable compute (`terraform/platform`) and automated S3 backups.
