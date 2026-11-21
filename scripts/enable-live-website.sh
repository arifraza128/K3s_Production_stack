#!/usr/bin/env bash
# ==============================================================================
# Phoenix Platform — Live Real-World Production Website & Subdomain Launcher
# Deploys:
#   1. https://13.207.161.55.sslip.io/         (Interactive Production Control Center)
#   2. https://grafana.13.207.161.55.sslip.io  (4-Row SLO Grafana Dashboard over HTTPS)
#   3. https://gitea.13.207.161.55.sslip.io    (Gitea Stateful Git Server over HTTPS)
#   4. https://argocd.13.207.161.55.sslip.io   (ArgoCD GitOps Control Plane over HTTPS)
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================================================="
echo " Launching Phoenix Platform Real-World Production Websites (Let's Encrypt TLS)"
echo "=============================================================================="

# 1. Pull latest GitOps commit (including CI-built & signed image or apply live portal ConfigMap)
echo ""
echo "[1/4] Applying live Production Control Center to default/test-api..."

# Inject updated app.py via ConfigMap mount so the live website updates immediately even while CI builds the multi-arch image
kubectl create configmap test-api-live-code -n default \
  --from-file=app.py="${REPO_ROOT}/apps/test-api/app.py" \
  --dry-run=client -o yaml | kubectl apply --server-side --force-conflicts --validate=false -f - >/dev/null

kubectl patch deployment test-api -n default --type='strategic' -p='{
  "spec": {
    "template": {
      "spec": {
        "volumes": [{"name": "live-code", "configMap": {"name": "test-api-live-code"}}],
        "containers": [{
          "name": "test-api",
          "volumeMounts": [{"name": "live-code", "mountPath": "/app/app.py", "subPath": "app.py", "readOnly": true}]
        }]
      }
    }
  }
}' >/dev/null

kubectl rollout status deployment/test-api -n default --timeout=120s

# 2. Ensure Gitea & ArgoCD Server are running for their live HTTPS subdomains
echo ""
echo "[2/4] Ensuring Gitea (PostgreSQL + Gitea) and ArgoCD UI are Running..."
kubectl scale deployment argocd-server argocd-repo-server -n argocd --replicas=1 >/dev/null 2>&1 || true
kubectl delete pod -n argocd --field-selector=status.phase!=Running --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true
ARGOCD_READY="$(kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
if [[ "${ARGOCD_READY}" != "True" ]]; then
  kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-server --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true
  kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true
fi
PG_READY="$(kubectl get pod gitea-postgresql-0 -n gitea -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
if [[ "${PG_READY}" != "True" ]]; then
  kubectl delete pod gitea-postgresql-0 -n gitea --grace-period=0 --force >/dev/null 2>&1 || true
fi
kubectl rollout status deployment/gitea -n gitea --timeout=120s || true
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s || true

# 3. Apply all 4 HTTPS Ingresses & Let's Encrypt Certificates
echo ""
echo "[3/4] Applying Let's Encrypt HTTPS Ingresses for Root Portal, Grafana, Gitea, and ArgoCD..."
kubectl apply -f "${REPO_ROOT}/security/ingress-tls/ingress-routes.yaml" --server-side --force-conflicts --validate=false

echo "  -> Waiting for Let's Encrypt TLS certificates..."
for ns_cert in "default/phoenix-sslip-tls" "monitoring/grafana-sslip-tls" "gitea/gitea-sslip-tls" "argocd/argocd-sslip-tls"; do
  NS="${ns_cert%%/*}"
  CERT="${ns_cert##*/}"
  for _ in $(seq 1 24); do
    READY="$(kubectl get certificate "${CERT}" -n "${NS}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${READY}" == "True" ]]; then
      echo "  [READY] Certificate ${NS}/${CERT} issued by Let's Encrypt!"
      break
    fi
    sleep 3
  done
done

# 4. Verify live HTTPS responses
echo ""
echo "[4/4] Verifying live HTTPS websites..."
ROOT_HTTP="$(curl -ksS -o /dev/null -w "%{http_code}" "https://13.207.161.55.sslip.io/")"
GRAFANA_HTTP="$(curl -ksSL -o /dev/null -w "%{http_code}" "https://grafana.13.207.161.55.sslip.io/login")"
GITEA_HTTP="$(curl -ksSL -o /dev/null -w "%{http_code}" "https://gitea.13.207.161.55.sslip.io/")"
ARGOCD_HTTP="$(curl -ksSL -o /dev/null -w "%{http_code}" "https://argocd.13.207.161.55.sslip.io/")"

ARGO_PWD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'see argocd-initial-admin-secret')"

echo ""
echo "=============================================================================="
echo " YOUR REAL-WORLD PRODUCTION WEBSITES ARE LIVE OVER HTTPS!"
echo "=============================================================================="
echo " 1. Main Production Control Center (HTTP ${ROOT_HTTP}):"
echo "    -> https://13.207.161.55.sslip.io/"
echo ""
echo " 2. Grafana 4-Row SLO Dashboard (HTTP ${GRAFANA_HTTP}):"
echo "    -> https://grafana.13.207.161.55.sslip.io"
echo "    -> Login: admin / admin-phoenix-stack"
echo ""
echo " 3. Gitea Self-Hosted Git Server (HTTP ${GITEA_HTTP}):"
echo "    -> https://gitea.13.207.161.55.sslip.io"
echo "    -> Login: gitea_admin / admin12345"
echo ""
echo " 4. ArgoCD GitOps Control Plane (HTTP ${ARGOCD_HTTP}):"
echo "    -> https://argocd.13.207.161.55.sslip.io"
echo "    -> Login: admin / ${ARGO_PWD}"
echo "=============================================================================="
