.PHONY: help apply apply-dev apply-prod delete backup status logs shell secrets validate diff test seal unseal build-base build-dev build-prod

NAMESPACE := moodle
KUSTOMIZE := kubectl kustomize
KUBECONFORM := $(USERPROFILE)\.local\bin\kubeconform.exe
KUBESEAL := $(USERPROFILE)\.local\bin\kubeseal.exe

help:
	@echo "moodle-k8s Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  apply          Deploy base manifests to current cluster"
	@echo "  apply-dev      Deploy dev overlay"
	@echo "  apply-prod     Deploy prod overlay"
	@echo "  delete         Remove base manifests"
	@echo "  backup         Trigger immediate PostgreSQL backup"
	@echo "  status         Show resource status"
	@echo "  logs           Tail Moodle logs"
	@echo "  shell          Exec into Moodle pod"
	@echo "  secrets        Generate secrets.yaml from template"
	@echo "  validate       Validate all manifests with kubeconform"
	@echo "  diff           Show diff before applying"
	@echo "  test           Smoke test deployed Moodle"
	@echo "  seal           Seal secrets.yaml into sealed-secrets.yaml"
	@echo "  unseal         Unseal sealed-secrets.yaml into secrets.yaml"
	@echo "  build-base     Build base manifests with Kustomize"
	@echo "  build-dev      Build dev overlay with Kustomize"
	@echo "  build-prod     Build prod overlay with Kustomize"

apply:
	$(KUSTOMIZE) base | kubectl apply -f -
	kubectl apply -f secrets.yaml

apply-dev:
	$(KUSTOMIZE) overlays/dev | kubectl apply -f -
	kubectl apply -f secrets.yaml

apply-prod:
	$(KUSTOMIZE) overlays/prod | kubectl apply -f -
	kubectl apply -f secrets.yaml

delete:
	$(KUSTOMIZE) base | kubectl delete -f -
	kubectl delete -f secrets.yaml --ignore-not-found=true

backup:
	kubectl create job --from=cronjob/postgres-backup -n $(NAMESPACE) postgres-backup-manual-$$(date +%s)

status:
	kubectl get all,pvc,pdb,cronjob -n $(NAMESPACE)

logs:
	kubectl logs -n $(NAMESPACE) -l app=moodle -f --tail=100

shell:
	kubectl exec -it -n $(NAMESPACE) deploy/moodle -- /bin/bash

secrets:
	@if [ ! -f secrets.yaml ]; then \
		cp secrets.yaml.example secrets.yaml; \
		echo "Created secrets.yaml from template. Edit it before applying."; \
	else \
		echo "secrets.yaml already exists."; \
	fi

validate:
	$(KUSTOMIZE) base | $(KUBECONFORM) -summary -ignore-missing-schemas -
	@echo "Base overlay validation passed"
	$(KUSTOMIZE) overlays/dev | $(KUBECONFORM) -summary -ignore-missing-schemas -
	@echo "Dev overlay validation passed"
	$(KUSTOMIZE) overlays/prod | $(KUBECONFORM) -summary -ignore-missing-schemas -
	@echo "Prod overlay validation passed"

diff:
	$(KUSTOMIZE) base | kubectl diff -f -

test:
	@echo "Waiting for Moodle to be ready..."
	@kubectl wait --for=condition=available --timeout=300s deploy/moodle -n $(NAMESPACE)
	@echo "Running smoke test..."
	@kubectl run curl-test --rm -it --restart=Never --image=curlimages/curl:latest -- curl -sf -o /dev/null -w "%{http_code}" https://moodle.localdomain/login/index.php || (echo "Smoke test failed"; exit 1)
	@echo "Smoke test passed"

seal:
	@if [ ! -f secrets.yaml ]; then \
		echo "Error: secrets.yaml not found. Run 'make secrets' first."; \
		exit 1; \
	fi
	cat secrets.yaml | $(KUBESEAL) --format yaml > sealed-secrets.yaml
	@echo "Sealed secrets written to sealed-secrets.yaml"

unseal:
	@if [ ! -f sealed-secrets.yaml ]; then \
		echo "Error: sealed-secrets.yaml not found."; \
		exit 1; \
	fi
	kubectl apply -f sealed-secrets.yaml
	@echo "Unsealed secrets applied to cluster"

build-base:
	$(KUSTOMIZE) base

build-dev:
	$(KUSTOMIZE) overlays/dev

build-prod:
	$(KUSTOMIZE) overlays/prod
