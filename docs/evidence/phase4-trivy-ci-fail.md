# Phase 4 Evidence — Negative Test 2: Trivy HIGH/CRITICAL CI Gate Failure & Remediation

## 1. Test Objective

Verify that the GitHub Actions CI supply-chain pipeline (`.github/workflows/ci-supply-chain.yaml`) enforces `exit-code: "1"` on `HIGH` and `CRITICAL` vulnerabilities detected by **Aqua Trivy**, blocking container image push, SBOM attestation, and Cosign signing whenever vulnerable OS or Python packages exist in the image.

---

## 2. Negative Test Execution (Failed CI Run)

- **Commit SHA:** `cd8733aad05147bf189f4e935d5efbc25343537d`
- **GitHub Actions Run URL:** `https://github.com/arifraza128/K3s_Production_stack/commit/cd8733aad05147bf189f4e935d5efbc25343537d/checks`
- **Base Image Tested:** `python:3.12-alpine3.20` (without `apk upgrade` and with default bundled `pip`/`setuptools`/`wheel`)
- **Pipeline Stage Blocked:** Step 6 — `Run Trivy vulnerability scanner (Fail on HIGH/CRITICAL)`
- **Observed Result:**
  - Step 3 (`Run Test API unit tests`): `success`
  - Step 5 (`Build local image for Trivy & Syft scanning`): `success`
  - Step 6 (`Run Trivy vulnerability scanner (Fail on HIGH/CRITICAL)`): **`failure` (`exit-code: 1`)**
  - Steps 7–11 (`Syft SBOM`, `Login to GHCR`, `Build and Push Multi-Arch Image`, `Install Cosign`, `Sign container image keyless with Cosign`): **`skipped`** (supply-chain gate prevented publishing or signing the vulnerable artifact).

---

## 3. Remediation & Positive Verification (Passed CI Run)

- **Remediation Applied in `apps/test-api/Dockerfile`:**
  1. Upgraded base image from `python:3.12-alpine3.20` to `python:3.12-alpine3.21`.
  2. Added `apk update && apk upgrade --no-cache` to pull the latest Alpine security patches at build time.
  3. Uninstalled unused Python packaging libraries (`pip uninstall -y pip setuptools wheel`) since `test-api` uses only the Python 3.12 standard library.
- **Verified Passing Commit SHA:** `f8b5b99569a3df99e281846100dfa5e8af629696`
- **GitHub Actions Run URL:** `https://github.com/arifraza128/K3s_Production_stack/commit/f8b5b99569a3df99e281846100dfa5e8af629696/checks`
- **Observed Result:**
  - Step 3 (`Run Test API unit tests`): `success`
  - Step 6 (`Run Trivy vulnerability scanner (Fail on HIGH/CRITICAL)`): **`success` (0 HIGH/CRITICAL vulnerabilities)**
  - Step 7 (`Generate CycloneDX SBOM with Syft`): **`success`**
  - Step 9 (`Build and Push Multi-Arch Image`): **`success`**
  - Step 11 (`Sign container image keyless with Cosign (OIDC)`): **`success`**

