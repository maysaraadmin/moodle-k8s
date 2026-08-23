.PHONY: apply delete backup status logs shell secrets

NAMESPACE := moodle

apply:
	kubectl apply -f namespace.yaml
	kubectl apply -f secrets.yaml
	kubectl apply -f configmap.yaml
	kubectl apply -f pvc/
	kubectl apply -f postgres/
	kubectl apply -f moodle/
	kubectl apply -f pdb/
	kubectl apply -f cronjob.yaml
	kubectl apply -f network-policies.yaml
	kubectl apply -f ingress.yaml

delete:
	kubectl delete -f ingress.yaml
	kubectl delete -f network-policies.yaml
	kubectl delete -f cronjob.yaml
	kubectl delete -f pdb/
	kubectl delete -f moodle/
	kubectl delete -f postgres/
	kubectl delete -f pvc/
	kubectl delete -f configmap.yaml
	kubectl delete -f secrets.yaml
	kubectl delete -f namespace.yaml

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
