KUBECTL ?= kubectl

# ---- FluxCD GitOps management (local-cluster) ----

flux-install: ## Install Flux controllers (CRDs + controllers)
	flux install

flux-apply: ## Apply GitRepository + Kustomization bootstrap
	$(KUBECTL) apply -f k8s/local-cluster/flux/flux.yaml

flux-status: ## Display status of Flux sources and kustomizations
	flux get sources all -A | cat
	flux get kustomizations all -A | cat
