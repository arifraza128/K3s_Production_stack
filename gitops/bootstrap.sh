#!/usr/bin/env bash
# ==============================================================================
# ArgoCD GitOps Bootstrap Script for K3s Production Stack
# ==============================================================================
set -euo pipefail

echo "==> [1/4] Ensuring 'argocd' namespace exists..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "==> [2/4] Installing ArgoCD via Kustomize..."
kubectl apply -k gitops/argocd-install

echo "==> [3/4] Waiting for ArgoCD Server deployment to be ready (timeout: 300s)..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "==> [4/4] Deploying Root Application (Application-of-Applications)..."
kubectl apply -f gitops/root-application.yaml

echo "=============================================================================="
echo "==> ArgoCD Bootstrap Completed Successfully!"
echo "=============================================================================="
echo "Access URLs:"
echo "  - Ingress: http://argocd.13.207.161.55.nip.io"
echo "  - Path Ingress: http://13.207.161.55/argocd"
echo "  - Port-Forward: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo ""
echo "Initial Credentials:"
echo "  - Username: admin"
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Secret not found or password changed")
echo "  - Password: ${ARGO_PWD}"
echo "=============================================================================="
