# ADR 001: Single-Node K3s on ARM64 EC2 vs Managed AWS EKS

- **Status:** Accepted
- **Date:** 2026-11-07

## Context
We need a production-grade Kubernetes control plane in `ap-south-1` capable of running GitOps (ArgoCD), supply-chain admission control (Kyverno), observability (Prometheus/Grafana), and stateful workloads (Gitea + PostgreSQL) under a strict cloud cost ceiling (`< $20/month`).

## Decision
Provision **K3s** on an AWS Graviton2 ARM64 EC2 instance (`t4g.small` / `t4g.medium`) with a 30GB `gp3` root volume via Terraform and Cloud-Init, rather than AWS EKS.

## Consequences
- **Pros:**
  - Eliminates the `$73/month` AWS EKS control-plane fee (`~90%` cost reduction).
  - Single binary (`< 70MB`) with lower control-plane RAM overhead (`~450MB` vs `1.5GB+`).
  - Full control over API server flags, TLS SANs (`/etc/rancher/k3s/config.yaml.d/tls-san.yaml`), and node lifecycle.
- **Cons:**
  - Single control-plane node introduces a single point of failure (mitigated by immutable Terraform + S3 Velero/`pg_dump` backups with `68s` RTO).

