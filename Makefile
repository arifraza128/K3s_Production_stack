# ==============================================================================
# Phoenix Platform — K3s Production Stack Makefile
# ==============================================================================

SHELL := /bin/bash
TF_DIR := terraform

.PHONY: help init validate plan apply destroy bootstrap-gitops lint chaos dr-drill backup-keys test-api phase4-verify

help: ## Show available Make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform working directory
	terraform -chdir=$(TF_DIR) init

validate: ## Validate and format-check Terraform configurations
	terraform -chdir=$(TF_DIR) fmt -check
	terraform -chdir=$(TF_DIR) validate

plan: ## Run Terraform plan
	terraform -chdir=$(TF_DIR) plan

apply: ## Apply Terraform infrastructure
	terraform -chdir=$(TF_DIR) apply -auto-approve

destroy: ## Destroy Terraform infrastructure
	terraform -chdir=$(TF_DIR) destroy -auto-approve

bootstrap-gitops: ## Bootstrap ArgoCD and deploy Root Application (App-of-Apps)
	bash gitops/bootstrap.sh

backup-keys: ## Backup Sealed Secrets master encryption key from kube-system
	bash security/sealed-secrets/backup-sealed-secrets-key.sh

test-api: ## Run Phase 4 Test API unit tests
	python3 -m unittest discover -s apps/test-api -v

phase4-verify: ## Run Phase 4 end-to-end verification (unit tests + Kyverno + Sealed Secrets + Test API)
	bash scripts/verify-phase4.sh

chaos: ## Run Phase 7 reliability chaos experiments (5 experiments)
	bash chaos/scripts/chaos.sh

dr-drill: ## Execute Phase 8 Disaster Recovery drill and generate RTO/RPO JSON evidence
	bash backup/scripts/dr-drill.sh

lint: ## Lint Terraform and Kubernetes YAML manifests
	terraform -chdir=$(TF_DIR) fmt -check
	@command -v kubeconform >/dev/null 2>&1 && kubeconform -summary -ignore-missing-schemas apps/ security/ observability/ backup/ gitops/ || echo "kubeconform not installed, skipping schema check"

