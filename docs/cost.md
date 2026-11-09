# Cloud Cost Analysis & Budget Guardrails (`ap-south-1`)

## 1. Monthly Infrastructure Cost Breakdown

| Resource | Specification | Pricing Model | Monthly Cost (USD) |
| :--- | :--- | :--- | :--- |
| **EC2 Compute** | `t4g.small` (2 vCPU ARM64 Graviton2, 2 GiB RAM) | On-Demand (`$0.0152/hr` in `ap-south-1` / Free-Tier eligible) | `$11.10` (`$0.00` under AWS ARM64 Free Tier) |
| **EBS Root Storage** | `30 GB` `gp3` (3000 IOPS, 125 MB/s) | `$0.08/GB-month` (Free-Tier includes 30 GB) | `$2.40` (`$0.00` under Free Tier) |
| **Public IPv4 / EIP** | 1 Attached Elastic IP (`13.207.161.55`) | `$0.005/hr` (`~730 hrs/mo`) | `$3.65` |
| **S3 Backup Bucket** | `< 5 GB` (`Velero` + `pg_dump` + `SealedSecrets`) | `$0.023/GB-month` (`ap-south-1`) | `$0.12` |
| **Container Registry & CI** | GitHub Actions + GHCR (`ghcr.io`) | Public Repo Free Tier | `$0.00` |
| **TLS Certificates & DNS** | Let's Encrypt ACME + `sslip.io` | Free | `$0.00` |
| **Total Estimated Bill** | **Full 24/7 Production Operation** | **With / Without Free Tier** | **`$3.77 / $17.27`** |

## 2. Comparison vs Managed AWS EKS
- **Managed AWS EKS Baseline:** `$73.00` (EKS Control Plane) + `$22.20` (2x `t4g.small` nodes) + `$16.40` (ALB) = **`$111.60/month`**.
- **Phoenix K3s Stack Savings:** **`~85% – 96%` cost reduction** while preserving GitOps, supply-chain signing, observability SLOs, and automated S3 DR.

## 3. Cost Guardrails Implemented
1. **AWS Budgets Alert:** Configured at `$10.00` threshold (`80%` forecasted and `100%` actual) notifying `arif3raza@gmail.com`.
2. **Ephemeral Compute Destruction:** Running `make destroy` tears down EC2 & EBS when idle while retaining GitOps manifests in Git for `< 2 min` rebuilds.

