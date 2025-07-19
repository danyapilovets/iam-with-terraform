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

.PHONY: chartsye
# Build kafka-s3-consumer image from hidden apps/.docker directory and load into Minikube cache
build-consumer: ## Build image in Minikube Docker daemon
	@echo "▶ Switching docker-env to Minikube"
	eval $$(minikube -p minikube docker-env) && \
	docker build --platform=linux/amd64 -t kafka-s3-consumer:1.0.0 apps/.docker/kafka-s3-consumer
	@echo "✔ Image built inside Minikube; ready to use"

.PHONY: build-consumer

include .env
include k8s/local-cluster/cluster-settings/_cluster.mk
