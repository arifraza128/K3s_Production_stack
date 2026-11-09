# ADR 004: Hybrid Kustomize + Helm Strategy

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
The platform deploys both bespoke first-party manifests (`test-api`, Kyverno `ClusterPolicies`, `PrometheusRules`, `CronJobs`) and complex third-party software packages (`Gitea` + `PostgreSQL`, `kube-prometheus-stack`, `Velero`).

## Decision
Adopt a **hybrid approach**:
1. **Kustomize** for first-party workloads (`apps/test-api/k8s`), policy bundles (`security/`), and ArgoCD bootstrap (`gitops/argocd-install/`).
2. **Helm** (via ArgoCD `source.helm` and `values.yaml`) for complex upstream charts (`apps/gitea/values.yaml`, `observability/prometheus/values.yaml`, `backup/velero/values.yaml`).

## Consequences
- **Pros:**
  - Zero template-escaping boilerplate for internal manifests (`kustomization.yaml` stays clean and readable).
  - Leverages upstream community maintenance for stateful subcharts (`postgresql` in Gitea, `grafana` in `kube-prometheus-stack`).
- **Cons:**
  - Operators must be familiar with both `kustomization.yaml` and Helm `values.yaml` conventions.

