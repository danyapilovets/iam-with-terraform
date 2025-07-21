.DEFAULT_GOAL := help

ENV ?= dev
TF_DIR := infra/$(ENV)

.PHONY: help fmt init plan apply destroy validate lint

help: ## Show this help message
	@grep -Eh '^[a-zA-Z_\-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

fmt: ## Run terraform fmt recursively
	terraform fmt -recursive

init: ## Terraform init in selected environment
	terraform -chdir=$(TF_DIR) init

plan: ## Terraform plan in selected environment
	terraform -chdir=$(TF_DIR) plan

apply: ## Terraform apply in selected environment
	terraform -chdir=$(TF_DIR) apply -auto-approve

destroy: ## Terraform destroy in selected environment
	terraform -chdir=$(TF_DIR) destroy -auto-approve

validate: ## Terraform validate in selected environment
	terraform -chdir=$(TF_DIR) validate

lint: ## Run tflint recursively
	tflint --recursive

charts:
	helm dependency update apps/.helm/airflow
	helm package apps/.helm/airflow -d apps/.helm/airflow/.charts
	helm package apps/.helm/kafka-consumer -d apps/.helm/kafka-consumer/.charts
	helm package apps/.helm/producer -d apps/.helm/producer/.charts

deploy: charts ## Deploy banking system
	$(MAKE) apply
	kubectl apply -k k8s/local-cluster/environments/dev/

.PHONY: chartsye

include .env
include k8s/local-cluster/cluster-settings/_cluster.mk
include k8s/local-cluster/flux/_flux.mk

