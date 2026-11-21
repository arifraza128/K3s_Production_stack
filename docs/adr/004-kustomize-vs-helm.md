# ADR 004: Kustomize for First-Party Apps vs Helm for Third-Party Charts

- **Status:** Accepted
- **Date:** 2026-11-08
- **Evidence Link:** [`apps/test-api/k8s/kustomization.yaml`](../../apps/test-api/k8s/kustomization.yaml) · [`gitops/argocd-apps/`](../../gitops/argocd-apps/)

## Context
The platform manages both first-party resources (`test-api`, Kyverno `ClusterPolicy`, `PrometheusRule`, `ServiceMonitor`, `NetworkPolicy`, `Ingress`) and complex third-party upstream stacks (`Gitea` + `PostgreSQL`, `kube-prometheus-stack`, `Kyverno`, `ingress-nginx`, `cert-manager`).

## Decision
Follow [`AGENTS.md`](../../AGENTS.md) §3 strictly:
1. **Kustomize** for all own/first-party manifests (`apps/test-api/k8s/`, `security/`, `observability/`, `backup/`).
2. **Helm** only for third-party upstream charts referenced with pinned versions in `gitops/argocd-apps/*.yaml`.

## Alternatives Considered
1. **Helm for Everything:** Wrapping a 70-line `test-api` Deployment and Service in Go templates adds unnecessary boilerplate and obscures security contexts during code review.
2. **Kustomize for Everything (vendoring third-party YAML):** Checking in 15,000+ lines of rendered `kube-prometheus-stack` and `kyverno` YAML bloats Git history and makes chart upgrades brittle.

## Consequences
- ✅ **Clean GitOps CI bumps:** GitHub Actions updates the image tag in [`apps/test-api/k8s/deployment.yaml`](../../apps/test-api/k8s/deployment.yaml) with a 1-line commit (`44e5131`).
- ✅ **Pinned upstream reproducibility:** Third-party charts are pinned to exact versions (`kyverno 3.2.6`, `kube-prometheus-stack 65.1.1`, `ingress-nginx 4.11.3`, `cert-manager v1.16.2`, `gitea 12.7.0`).
- ❌ **Two manifest formats:** Engineers must understand both `kustomization.yaml` and Helm `valuesObject` blocks.
