# Cloud Cost Analysis & Budget Guardrails (`ap-south-1`)

> Per [`PRD.md`](../PRD.md) §12 A1 & A2: We size the compute node at **`t4g.medium` (2 vCPU ARM64 Graviton2, 4 GiB RAM + 4 GiB swap)** so the full stack (K3s + ArgoCD + Gitea + PostgreSQL + Prometheus + Grafana + Alertmanager + Kyverno + cert-manager + ingress-nginx) runs without OOM thrashing, and we stop the instance between build/drill sessions to control cost.

## 1. Monthly Infrastructure Cost Breakdown (`ap-south-1`)

| Resource | Specification | Pricing Model | 24/7 Monthly Cost (USD) | On-Demand Session Cost (`~40 hrs/mo`) |
| :--- | :--- | :--- | :--- | :--- |
| **EC2 Compute** | `t4g.medium` (2 vCPU ARM64, 4 GiB RAM) | On-Demand (`$0.0304/hr` in `ap-south-1`) | `$22.19` | **`$1.22`** |
| **EBS Root Storage** | `30 GB` `gp3` (encrypted, 3000 IOPS) | `$0.08/GB-month` (Free-Tier eligible up to 30 GB) | `$2.40` (`$0.00` Free Tier) | **`$0.00 – $2.40`** |
| **Public IPv4 / EIP** | 1 Persistent Elastic IP (`13.207.161.55`) | `$0.005/hr` (`~730 hrs/mo`) | `$3.65` | **`$3.65`** |
| **S3 Backup Bucket** | `< 5 GB` (`Velero` + `pg_dump` + `SealedSecrets`) | `$0.023/GB-month` (`ap-south-1`) | `$0.12` | **`$0.12`** |
| **CI/CD & Registry** | GitHub Actions + GHCR + Cosign OIDC | Public Repository Free Tier | `$0.00` | **`$0.00`** |
| **DNS & TLS** | `13.207.161.55.sslip.io` + Let's Encrypt | Free | `$0.00` | **`$0.00`** |
| **Total Actual/Expected Bill** | **Full Phoenix Production Stack** | **24/7 vs Session-Based (`PRD.md` A6)** | **`$25.96 – $28.36/mo`** | **`$4.99 – $7.39/mo`** |

---

## 2. Comparison vs Managed AWS EKS

- **Managed AWS EKS Baseline:** `$73.00` (EKS Control Plane) + `$44.38` (2x `t4g.medium` nodes) + `$16.40` (ALB) = **`$133.78/month`**.
- **Phoenix K3s Stack Savings:** **`~79%` reduction (24/7) to `~95%` reduction (session-based)** while delivering GitOps self-healing, Cosign/Kyverno supply-chain verification, 3 SLOs with Discord/Healthchecks alerting, Let's Encrypt HTTPS, 5 measured chaos experiments, and 3 S3 DR drills.

---

## 3. Cost Guardrails Implemented

1. **AWS Budgets Alert ([`terraform/bootstrap/main.tf`](../terraform/bootstrap/main.tf)):** Configured at `$10.00/month` (`80%` threshold notification to `arif3raza@gmail.com`).
2. **Stop/Destroy Between Sessions ([`PRD.md`](../PRD.md) §12 A6):** Stopping `i-0ffd3360432bbacf3` (`aws ec2 stop-instances`) when not running drills eliminates EC2 hourly compute charges while preserving the EBS volume and Elastic IP `13.207.161.55`.
