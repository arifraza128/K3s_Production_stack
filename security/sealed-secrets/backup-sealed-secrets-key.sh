#!/usr/bin/env bash
# ==============================================================================
# Phase 4 & Phase 8 — Sealed Secrets Master Key Backup Script
# Backs up the active sealed-secrets-key from kube-system to S3 (and local tmp)
# ==============================================================================
set -euo pipefail

BACKUP_FILE="/tmp/sealed-secrets-master-key-$(date -u +%Y%m%dT%H%M%SZ).yaml"
S3_BUCKET="${S3_BACKUP_BUCKET:-}"

echo "==> Exporting active Sealed Secrets master key from kube-system..."
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "${BACKUP_FILE}"
chmod 600 "${BACKUP_FILE}"

echo "==> Saved Sealed Secrets master key locally to: ${BACKUP_FILE}"

if [[ -n "${S3_BUCKET}" ]]; then
  echo "==> Uploading Sealed Secrets master key backup to s3://${S3_BUCKET}/sealed-secrets/..."
  aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/sealed-secrets/$(basename "${BACKUP_FILE}")" --sse AES256
  echo "==> S3 upload complete."
else
  echo "==> Note: S3_BACKUP_BUCKET not set; skipping S3 upload."
fi

