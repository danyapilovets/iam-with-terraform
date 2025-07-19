KUBECTL ?= kubectl

mk-start: ## Start local minikube
	minikube start --driver=docker --cpus=2 --memory=2g
	@echo "Installing multi-architecture support..."
	minikube ssh -- docker run --rm --privileged tonistiigi/binfmt --install amd64
	minikube addons enable ingress

mk-stop: ## Stop minikube
	minikube stop

mk-status: ## Cluster info
	$(KUBECTL) cluster-info; $(KUBECTL) get nodes -o wide

.PHONY: mk-start mk-stop mk-status
