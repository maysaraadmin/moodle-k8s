.PHONY: help apply apply-dev apply-prod delete backup status logs shell secrets validate diff test seal unseal build-base build-dev build-prod

NAMESPACE_BASE := moodle
NAMESPACE_DEV := moodle-dev
NAMESPACE_PROD := moodle
NAMESPACE ?= $(NAMESPACE_BASE)
KUSTOMIZE := kubectl kustomize
KUBECONFORM ?= $(shell command -v kubeconform 2>/dev/null || echo "$(HOME)/.local/bin/kubeconform")

help:
	@echo "moodle-k8s Makefile"
	@echo ""
	@echo "Commands:"
	@echo "  make apply        Deploy base manifests"
	@echo "  make apply-dev    Deploy dev overlay"
	@echo "  make apply-prod   Deploy prod overlay"
	@echo "  make delete       Remove base manifests"
	@echo "  make backup       Trigger immediate PostgreSQL backup"
	@echo "  make status       Show resource status"
	@echo "  make logs         Tail Moodle logs"
	@echo "  make shell        Exec into Moodle pod"
	@echo "  make secrets      Generate secrets.yaml from template"
	@echo "  make validate     Validate all manifests"
	@echo "  make diff         Show diff before applying"
	@echo "  make test         Smoke test deployed Moodle"
	@echo "  make seal         Seal secrets for Git storage"
	@echo "  make unseal       Apply sealed secrets to cluster"
	@echo "  make build-base   Build base manifests"
	@echo "  make build-dev    Build dev overlay"
	@echo "  make build-prod   Build prod overlay"

apply:
	$(KUSTOMIZE) base | kubectl apply -f -
	@if [ -f sealed-secrets.yaml ]; then kubectl apply -f sealed-secrets.yaml -n $(NAMESPACE_BASE); \
	elif [ -f secrets.yaml ]; then kubectl apply -f secrets.yaml -n $(NAMESPACE_BASE); fi

apply-dev:
	$(KUSTOMIZE) overlays/dev | kubectl apply -f -
	@if [ -f sealed-secrets.yaml ]; then kubectl apply -f sealed-secrets.yaml -n $(NAMESPACE_DEV); \
	elif [ -f secrets.yaml ]; then kubectl apply -f secrets.yaml -n $(NAMESPACE_DEV); fi

apply-prod:
	$(KUSTOMIZE) overlays/prod | kubectl apply -f -
	@if [ -f sealed-secrets.yaml ]; then kubectl apply -f sealed-secrets.yaml -n $(NAMESPACE_PROD); \
	elif [ -f secrets.yaml ]; then kubectl apply -f secrets.yaml -n $(NAMESPACE_PROD); fi

delete:
	$(KUSTOMIZE) base | kubectl delete -f -
	kubectl delete secret moodle-secrets -n $(NAMESPACE_BASE) --ignore-not-found=true

backup:
	kubectl create job --from=cronjob/postgres-backup -n $(NAMESPACE) postgres-backup-manual-$(shell date +%Y%m%d%H%M%S)

status:
	kubectl get all,pvc,pdb,cronjob,hpa,quota,limitrange -n $(NAMESPACE)

logs:
	kubectl logs -n $(NAMESPACE) -l app=moodle -f --tail=100

shell:
	kubectl exec -it -n $(NAMESPACE) deploy/moodle -- /bin/bash

secrets:
	@if [ ! -f secrets.yaml ]; then cp secrets.yaml.example secrets.yaml && echo "Created secrets.yaml from template. Edit it before applying."; else echo "secrets.yaml already exists."; fi

validate:
	@echo "Validating base overlay..."
	$(KUSTOMIZE) base | $(KUBECONFORM) -summary -ignore-missing-schemas -
	@echo "Validating dev overlay..."
	$(KUSTOMIZE) overlays/dev | $(KUBECONFORM) -summary -ignore-missing-schemas -
	@echo "Validating prod overlay..."
	$(KUSTOMIZE) overlays/prod | $(KUBECONFORM) -summary -ignore-missing-schemas -

diff:
	$(KUSTOMIZE) base | kubectl diff -f -

test:
	@echo "Waiting for Moodle to be ready..."
	kubectl wait --for=condition=available --timeout=300s deploy/moodle -n $(NAMESPACE)
	@echo "Running smoke test..."
	@INGRESS_HOST=$$(kubectl get ingress moodle-ingress -n $(NAMESPACE) -o jsonpath='{.spec.rules[0].host}' 2>/dev/null); \
	if [ -z "$$INGRESS_HOST" ]; then \
		echo "Warning: no ingress found, testing via ClusterIP service instead"; \
		INGRESS_HOST="moodle.$(NAMESPACE).svc.cluster.local"; \
		PORT="80"; \
		PROTOCOL="http"; \
	else \
		PORT="443"; \
		PROTOCOL="https"; \
	fi; \
	TEST_URL="$${PROTOCOL}://$${INGRESS_HOST}:$${PORT}/login/index.php"; \
	echo "Testing URL: $$TEST_URL"; \
	kubectl run curl-test --rm --restart=Never --image=curlimages/curl:latest -- curl -sf -o /dev/null -w "%{http_code}" $$TEST_URL

seal:
	@if [ ! -f secrets.yaml ]; then echo "Error: secrets.yaml not found. Run 'make secrets' first."; exit 1; fi
	kubeseal --format yaml < secrets.yaml > sealed-secrets.yaml
	@echo "Sealed secrets written to sealed-secrets.yaml"

unseal:
	@if [ ! -f sealed-secrets.yaml ]; then echo "Error: sealed-secrets.yaml not found."; exit 1; fi
	kubectl apply -f sealed-secrets.yaml
	@echo "Unsealed secrets applied to cluster"

build-base:
	$(KUSTOMIZE) base

build-dev:
	$(KUSTOMIZE) overlays/dev

build-prod:
	$(KUSTOMIZE) overlays/prod
