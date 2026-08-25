# moodle-k8s build script for Windows PowerShell
param(
    [string]$Command = "help",
    [string]$Namespace = "moodle"
)

$ErrorActionPreference = "Stop"
$KUSTOMIZE = "kubectl kustomize"
$KUBECONFORM = "$env:USERPROFILE\.local\bin\kubeconform.exe"
$KUBESEAL = "$env:USERPROFILE\.local\bin\kubeseal.exe"

function Get-Namespace {
    param([string]$Overlay)
    switch ($Overlay) {
        "dev" { return "moodle-dev" }
        "prod" { return "moodle" }
        default { return "moodle" }
    }
}

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
        $namespace = Get-Namespace "base"
        kubectl kustomize base | kubectl apply -f -
        if (Test-Path "sealed-secrets.yaml") {
            kubectl apply -f sealed-secrets.yaml -n $namespace
        } elseif (Test-Path "secrets.yaml") {
            kubectl apply -f secrets.yaml -n $namespace
        }
    }
    "apply-dev" {
        $namespace = Get-Namespace "dev"
        kubectl kustomize overlays\dev | kubectl apply -f -
        if (Test-Path "sealed-secrets.yaml") {
            kubectl apply -f sealed-secrets.yaml -n $namespace
        } elseif (Test-Path "secrets.yaml") {
            kubectl apply -f secrets.yaml -n $namespace
        }
    }
    "apply-prod" {
        $namespace = Get-Namespace "prod"
        kubectl kustomize overlays\prod | kubectl apply -f -
        if (Test-Path "sealed-secrets.yaml") {
            kubectl apply -f sealed-secrets.yaml -n $namespace
        } elseif (Test-Path "secrets.yaml") {
            kubectl apply -f secrets.yaml -n $namespace
        }
    }
    "delete" {
        $namespace = Get-Namespace "base"
        kubectl kustomize base | kubectl delete -f -
        kubectl delete secret moodle-secrets -n $namespace --ignore-not-found=true
    }
    "backup" {
        $jobName = "postgres-backup-manual-$(Get-Date -Format 'yyyyMMddHHmmss')"
        kubectl create job --from=cronjob/postgres-backup -n $Namespace $jobName
    }
    "status" {
        kubectl get all,pvc,pdb,cronjob,hpa,quota,limitrange -n $Namespace
    }
    "logs" {
        kubectl logs -n $Namespace -l app=moodle -f --tail=100
    }
    "shell" {
        kubectl exec -it -n $Namespace deploy/moodle -- /bin/bash
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
        kubectl wait --for=condition=available --timeout=300s deploy/moodle -n $Namespace
        Write-Host "Running smoke test..."
        $ingressHost = (kubectl get ingress moodle-ingress -n $Namespace -o jsonpath='{.spec.rules[0].host}' 2>$null)
        if (-not $ingressHost) {
            Write-Host "Warning: no ingress found, testing via ClusterIP service instead"
            $ingressHost = "moodle.$Namespace.svc.cluster.local"
            $port = "80"
            $protocol = "http"
        } else {
            $port = "443"
            $protocol = "https"
        }
        $testUrl = "${protocol}://${ingressHost}:${port}/login/index.php"
        Write-Host "Testing URL: $testUrl"
        kubectl run curl-test --rm --restart=Never --image=curlimages/curl:latest -- curl -sf -o /dev/null -w "%{http_code}" $testUrl
    }
    "seal" {
        if (-not (Test-Path "secrets.yaml")) {
            Write-Error "Error: secrets.yaml not found. Run .\make.ps1 secrets first."
            exit 1
        }
        Get-Content "secrets.yaml" -Raw | & $KUBESEAL --format yaml | Set-Content "sealed-secrets.yaml"
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
