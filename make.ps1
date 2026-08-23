# moodle-k8s build script for Windows
param(
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"
$NAMESPACE = "moodle"
$KUSTOMIZE = "kubectl kustomize"
$KUBECONFORM = "$env:USERPROFILE\.local\bin\kubeconform.exe"
$KUBESEAL = "$env:USERPROFILE\.local\bin\kubeseal.exe"

switch ($Command) {
    "help" {
        Write-Host "moodle-k8s build script"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  apply        Deploy base manifests"
        Write-Host "  apply-dev    Deploy dev overlay"
        Write-Host "  apply-prod   Deploy prod overlay"
        Write-Host "  delete       Remove base manifests"
        Write-Host "  backup       Trigger immediate PostgreSQL backup"
        Write-Host "  status       Show resource status"
        Write-Host "  logs         Tail Moodle logs"
        Write-Host "  shell        Exec into Moodle pod"
        Write-Host "  secrets      Generate secrets.yaml from template"
        Write-Host "  validate     Validate all manifests"
        Write-Host "  diff         Show diff before applying"
        Write-Host "  test         Smoke test deployed Moodle"
        Write-Host "  seal         Seal secrets for Git storage"
        Write-Host "  unseal       Apply sealed secrets to cluster"
        Write-Host "  build-base   Build base manifests"
        Write-Host "  build-dev    Build dev overlay"
        Write-Host "  build-prod   Build prod overlay"
    }
    "apply" {
        kubectl kustomize base | kubectl apply -f -
        kubectl apply -f secrets.yaml
    }
    "apply-dev" {
        kubectl kustomize overlays\dev | kubectl apply -f -
        kubectl apply -f secrets.yaml
    }
    "apply-prod" {
        kubectl kustomize overlays\prod | kubectl apply -f -
        kubectl apply -f secrets.yaml
    }
    "delete" {
        kubectl kustomize base | kubectl delete -f -
        kubectl delete -f secrets.yaml --ignore-not-found=true
    }
    "backup" {
        $jobName = "postgres-backup-manual-$(Get-Date -Format 'yyyyMMddHHmmss')"
        kubectl create job --from=cronjob/postgres-backup -n $NAMESPACE $jobName
    }
    "status" {
        kubectl get all,pvc,pdb,cronjob -n $NAMESPACE
    }
    "logs" {
        kubectl logs -n $NAMESPACE -l app=moodle -f --tail=100
    }
    "shell" {
        kubectl exec -it -n $NAMESPACE deploy/moodle -- /bin/bash
    }
    "secrets" {
        if (-not (Test-Path "secrets.yaml")) {
            Copy-Item "secrets.yaml.example" "secrets.yaml"
            Write-Host "Created secrets.yaml from template. Edit it before applying."
        } else {
            Write-Host "secrets.yaml already exists."
        }
    }
    "validate" {
        Write-Host "Validating base overlay..."
        kubectl kustomize base | & $KUBECONFORM -summary -ignore-missing-schemas -
        Write-Host "Validating dev overlay..."
        kubectl kustomize overlays\dev | & $KUBECONFORM -summary -ignore-missing-schemas -
        Write-Host "Validating prod overlay..."
        kubectl kustomize overlays\prod | & $KUBECONFORM -summary -ignore-missing-schemas -
    }
    "diff" {
        kubectl kustomize base | kubectl diff -f -
    }
    "test" {
        Write-Host "Waiting for Moodle to be ready..."
        kubectl wait --for=condition=available --timeout=300s deploy/moodle -n $NAMESPACE
        Write-Host "Running smoke test..."
        kubectl run curl-test --rm -it --restart=Never --image=curlimages/curl:latest -- curl -sf -o /dev/null -w "%{http_code}" https://moodle.localdomain/login/index.php
    }
    "seal" {
        if (-not (Test-Path "secrets.yaml")) {
            Write-Error "Error: secrets.yaml not found. Run .\make.ps1 secrets first."
            exit 1
        }
        Get-Content "secrets.yaml" | & $KUBESEAL --format yaml | Set-Content "sealed-secrets.yaml"
        Write-Host "Sealed secrets written to sealed-secrets.yaml"
    }
    "unseal" {
        if (-not (Test-Path "sealed-secrets.yaml")) {
            Write-Error "Error: sealed-secrets.yaml not found."
            exit 1
        }
        kubectl apply -f "sealed-secrets.yaml"
        Write-Host "Unsealed secrets applied to cluster"
    }
    "build-base" {
        kubectl kustomize base
    }
    "build-dev" {
        kubectl kustomize overlays\dev
    }
    "build-prod" {
        kubectl kustomize overlays\prod
    }
    default {
        Write-Host "Unknown command: $Command"
        Write-Host "Run .\make.ps1 help for available commands."
        exit 1
    }
}
