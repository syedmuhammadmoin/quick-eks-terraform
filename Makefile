SHELL := /bin/bash
.DEFAULT_GOAL := help

TF := terraform

.PHONY: help bootstrap init plan apply up kubeconfig verify clean-k8s destroy down fmt validate

help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## One-time: create the S3 state bucket and backend.hcl
	./scripts/bootstrap-state-bucket.sh

init: ## terraform init against the S3 backend
	@test -f backend.hcl || { echo "backend.hcl missing - run 'make bootstrap' first"; exit 1; }
	$(TF) init -backend-config=backend.hcl

plan: init ## Plan into ./tfplan
	$(TF) plan -out=tfplan

apply: ## Apply ./tfplan (15-20 min, mostly the EKS control plane)
	$(TF) apply tfplan
	@rm -f tfplan

up: plan apply kubeconfig verify ## Create everything and point kubectl at it

kubeconfig: ## Write kubeconfig for the cluster
	aws eks update-kubeconfig \
	  --region $$($(TF) output -raw region) \
	  --name $$($(TF) output -raw cluster_name)

verify: ## Quick health check
	kubectl get nodes -o wide
	kubectl get pods -A
	kubectl top nodes || echo "metrics-server not ready yet - give it a minute and retry 'make verify'"

clean-k8s: ## Delete K8s-created AWS resources (LBs, PVs) that block VPC deletion
	-kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --wait=true --timeout=5m
	-kubectl delete ingress --all-namespaces --all --wait=true --timeout=5m
	-kubectl delete pvc --all-namespaces --all --wait=true --timeout=5m

destroy: init ## terraform destroy (run clean-k8s first, or use 'make down')
	$(TF) destroy

down: clean-k8s destroy ## Tear everything down safely

fmt: ## terraform fmt
	$(TF) fmt -recursive

validate: ## terraform validate (no backend needed)
	$(TF) init -backend=false -input=false >/dev/null
	$(TF) validate
