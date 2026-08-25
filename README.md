# moodle-k8s

Production-grade Kubernetes manifests for deploying Moodle LMS on a Kubernetes cluster using open source tooling.

## Architecture

```
                      ┌──────────────┐
                      │   Ingress    │
                      │   (nginx)    │
                      └──────┬───────┘
                             │
                      ┌──────▼───────┐
                      │    Moodle    │
                      │  (PHP/Apache)│
                      └──────┬───────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
         ┌──────▼──────┐ ┌──▼─────┐ ┌─────▼──────┐
         │  moodledata │ │  cron  │ │  postgres  │
         │    (PVC)    │ │ (Cron) │ │   (PVC)    │
         └─────────────┘ └────────┘ └─────┬──────┘
                                           │
                                    ┌──────▼──────┐
                                    │  PgBouncer  │
                                    │  (pooling)  │
                                    └─────────────┘
                                           │
                                    ┌──────▼──────┐
                                    │    Redis    │
                                    │   (cache)   │
                                    └─────────────┘
```

Moodle, PgBouncer, and Redis run as non-root with dropped capabilities and read-only root filesystems. Pod Security Admission is enforced at `restricted`.

## Prerequisites

- Kubernetes 1.24+
- cert-manager (for TLS)
- nginx-ingress-controller (or compatible)
- A storage class supporting `ReadWriteOnce` PVCs
- `kubectl` with `kustomize` support (built into kubectl 1.14+)
- `kubeconform` for validation (optional but recommended)
- `kubeseal` for secret management (optional but recommended)
- `pre-commit` for local Git hooks (optional but recommended)
- Metrics Server (for HPA, optional but recommended)

## Continuous Integration

This project includes a GitHub Actions workflow (`.github/workflows/validate.yml`) that automatically validates all manifests with `kubeconform` and `kube-score` on every push and pull request to `main`.

## Pre-commit Hooks

Install `pre-commit` and run it before every commit to catch manifest errors early:

```powershell
pip install pre-commit
pre-commit install
```

This will run `kubeconform` on all YAML files before each commit.

## Quick Start

1. Generate secrets:

```powershell
.\make.ps1 secrets
# Edit secrets.yaml with strong, unique values
```

2. Validate manifests:

```powershell
.\make.ps1 validate
```

3. Deploy:

```powershell
.\make.ps1 apply
```

4. Complete Moodle setup:

Visit `https://moodle.localdomain` (or configure your domain via overlays). Auto-install is disabled by default; run the Moodle CLI installer manually or set `MOODLE_DOCKER_AUTOINSTALL=1` temporarily.

### Configuring Domains

Update domains in the overlay kustomization files rather than editing `base/ingress.yaml` directly:

- **Dev**: `overlays/dev/kustomization.yaml`
- **Prod**: `overlays/prod/kustomization.yaml`

## Directory Structure

```
.
├── base/                     # Kustomize base manifests
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── cronjob.yaml
│   ├── ingress.yaml
│   ├── network-policies.yaml
│   ├── rbac/
│   │   └── serviceaccount.yaml
│   ├── hpa/
│   │   └── moodle-hpa.yaml
│   ├── resource-quota.yaml
│   ├── limit-range.yaml
│   ├── moodle/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── postgres/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── backup-pvc.yaml
│   │   ├── backup-cronjob.yaml
│   │   ├── pgbouncer-configmap.yaml
│   │   ├── pgbouncer-deployment.yaml
│   │   └── pgbouncer-service.yaml
│   ├── redis/
│   │   ├── configmap.yaml
│   │   ├── pvc.yaml
│   │   ├── statefulset.yaml
│   │   └── service.yaml
│   ├── pvc/
│   │   ├── moodledata-pvc.yaml
│   │   └── postgres-pvc.yaml
│   └── pdb/
│       └── pdb.yaml
├── overlays/
│   ├── dev/                  # Development environment
│   │   └── kustomization.yaml
│   └── prod/                 # Production environment
│       └── kustomization.yaml
├── secrets.yaml              # Sensitive values (gitignored)
├── secrets.yaml.example      # Secret template
├── sealed-secrets.yaml       # Encrypted secrets for Git (optional)
├── Makefile                  # Cross-platform build script
├── make.ps1                  # Deployment script (Windows PowerShell)
├── .pre-commit-config.yaml   # Pre-commit hooks for validation
├── .gitignore
├── LICENSE
├── SECURITY.md
├── CHANGELOG.md
└── README.md
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make validate` or `.\make.ps1 validate` to ensure manifests are valid
5. Run `pre-commit run --all-files` to run local validation hooks
6. Commit and push your branch
7. Open a Pull Request

All PRs are automatically validated by GitHub Actions.

## Notes

- The `moodle/` directory is no longer tracked in Git. The base Docker image `moodlehq/moodle-php-apache:8.3.7` contains the Moodle source code. If you need custom plugins or themes, build a custom image in CI.
- The HPA is configured with `minReplicas: 1` by default. To scale beyond 1 replica, you must use `ReadWriteMany` storage for `moodledata-pvc`.
- Use `-Namespace` parameter with `make.ps1` for non-default namespaces: `.\make.ps1 logs -Namespace moodle-dev`

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MOODLE_DOCKER_DB_TYPE` | Database driver | `pgsql` |
| `MOODLE_DOCKER_DB_HOST` | Database hostname (PgBouncer) | `pgbouncer` |
| `MOODLE_DOCKER_DB_NAME` | Database name | `moodle` |
| `MOODLE_DOCKER_DB_USER` | Database user | `moodleuser` |
| `MOODLE_DOCKER_DB_PORT` | Database port | `5432` |
| `MOODLE_DOCKER_SSLTERMINATED` | TLS terminated at ingress | `1` |
| `MOODLE_DOCKER_AUTOINSTALL` | Auto-run Moodle installer | `0` |
| `MOODLE_DOCKER_ADMIN_USER` | Admin username | `admin` |
| `MOODLE_DOCKER_ADMIN_EMAIL` | Admin email | `admin@example.com` |
| `MOODLE_DOCKER_WWWROOT` | Public Moodle URL | `https://moodle.localdomain` |
| `MOODLE_DOCKER_REDIS_HOST` | Redis hostname | `redis` |
| `MOODLE_DOCKER_REDIS_PORT` | Redis port | `6379` |
| `MOODLE_DOCKER_REDIS_DB` | Redis database index | `0` |
| `MOODLE_DOCKER_REDIS_PASSWORD` | Redis password (empty = no auth) | `""` |
| `TZ` | Timezone | `UTC` |

### Ingress

Update domains in the overlay kustomization files:
- `overlays/dev/kustomization.yaml`
- `overlays/prod/kustomization.yaml`

Ensure your ingress controller namespace matches the NetworkPolicy selector in `base/network-policies.yaml` (default: `ingress-nginx`).

### Storage

- `postgres-pvc`: 20Gi for database data
- `moodledata-pvc`: 50Gi for user uploads, logs, sessions
- `postgres-backup-pvc`: 10Gi for daily pg_dump backups
- `redis-pvc`: 5Gi for Redis persistence

All PVCs default to storage class `standard`. Override via Kustomize patches to match your cluster's storage class.

## Multi-Environment Deployments

This project uses [Kustomize](https://kustomize.io/) (built into `kubectl`) for environment overlays.

### Dev Environment

```powershell
.\make.ps1 apply-dev
```

### Production Environment

```powershell
.\make.ps1 apply-prod
```

### Custom Overlays

Create a new directory under `overlays/` with a `kustomization.yaml` that references `../../base` and applies patches for namespace, replicas, domain, and storage class.

## Secrets Management

### Option 1: Plaintext (Development Only)

```powershell
.\make.ps1 secrets
# Edit secrets.yaml with strong values
```

> **Security note:** Never commit `secrets.yaml` to version control. It is gitignored. If it was previously committed, rotate all passwords immediately and purge from git history.

### Option 2: Sealed Secrets (Recommended for GitOps)

[Sealed Secrets](https://sealed-secrets.netlify.app/) is an open source Kubernetes controller and CLI tool that encrypts secrets into a format safe for Git storage.

1. Install the Sealed Secrets controller in your cluster:

```powershell
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

2. Seal your secrets:

```powershell
.\make.ps1 seal
```

3. Commit `sealed-secrets.yaml` to Git.

4. Apply sealed secrets:

```powershell
.\make.ps1 unseal
```

The Sealed Secrets controller automatically decrypts and creates the Kubernetes Secret in the cluster.

## Backups

Backups run daily at 02:00 UTC and retain 7 days of history.

### Manual Backup

```powershell
.\make.ps1 backup
```

### Restore

```powershell
kubectl exec -n moodle deploy/postgres -- pg_restore -U moodleuser -d moodle /backups/<backup-file>.sql.gz
```

## Security

- Pods run as non-root users with dropped capabilities
- `readOnlyRootFilesystem` on all application containers
- `allowPrivilegeEscalation: false` on all containers
- Network policies restrict traffic to required paths only
- Pod Security Standards enforced at `restricted`
- TLS termination via cert-manager / Let's Encrypt
- Redis requires password authentication and binds to loopback
- Secrets separated from ConfigMaps
- Support for Sealed Secrets for Git-safe secret storage
- Topology spread constraints reduce blast radius
- ServiceAccounts with automount disabled
- ResourceQuota and LimitRange enforce namespace constraints
- PgBouncer image pinned to specific version

## Horizontal Scaling

To scale Moodle beyond 1 replica:
1. Replace `moodledata-pvc` with a `ReadWriteMany` capable storage (NFS, CephFS, or MinIO via s3fs)
2. Update the PVC `accessModes` to `ReadWriteMany`
3. Increase `replicas` in the dev or prod overlay
4. The HPA will automatically scale pods based on CPU and memory utilization

PgBouncer and Redis are already deployed as separate scalable services. For higher load, increase their replicas in the overlay.

## Maintenance

### PowerShell (Windows)

```powershell
.\make.ps1 apply        # Deploy / update base manifests
.\make.ps1 apply-dev    # Deploy dev environment
.\make.ps1 apply-prod   # Deploy production environment
.\make.ps1 delete       # Remove base manifests
.\make.ps1 backup       # Trigger immediate backup
.\make.ps1 status       # Show resource status
.\make.ps1 logs         # Tail Moodle logs
.\make.ps1 shell        # Exec into Moodle pod
.\make.ps1 validate     # Validate all manifests
.\make.ps1 diff         # Show diff before applying
.\make.ps1 test         # Smoke test deployed Moodle
.\make.ps1 seal         # Seal secrets for Git storage
.\make.ps1 unseal       # Apply sealed secrets to cluster
.\make.ps1 build-base   # Build base manifests
.\make.ps1 build-dev    # Build dev overlay
.\make.ps1 build-prod   # Build prod overlay
```

### Makefile (Linux / macOS / Windows with make)

```bash
make apply        # Deploy / update base manifests
make apply-dev    # Deploy dev environment
make apply-prod   # Deploy production environment
make delete       # Remove base manifests
make backup       # Trigger immediate backup
make status       # Show resource status
make logs         # Tail Moodle logs
make shell        # Exec into Moodle pod
make validate     # Validate all manifests
make diff         # Show diff before applying
make test         # Smoke test deployed Moodle
make seal         # Seal secrets for Git storage
make unseal       # Apply sealed secrets to cluster
make build-base   # Build base manifests
make build-dev    # Build dev overlay
make build-prod   # Build prod overlay
```

## Performance Tuning

- **Redis**: Moodle is configured to use Redis for session caching and application cache, significantly improving page load times. Redis uses `volatile-lru` eviction policy to preserve active sessions.
- **PgBouncer**: PostgreSQL connections are pooled through PgBouncer, reducing connection overhead and preventing `max_connections` exhaustion.
- **HPA**: Moodle deployment has a HorizontalPodAutoscaler that scales between 2-10 replicas based on CPU (70%) and memory (80%) utilization.
- **Resource Limits**: All containers have explicit requests and limits for predictable scheduling. Moodle can burst to 512Mi / 500m under load.
- **Topology Spread**: Pods are spread across nodes to improve availability.
- **In-memory tmpfs**: `/tmp` uses `emptyDir` with `medium: Memory` for faster temporary file operations.

## Upgrade Procedure

1. Update image tags in the relevant deployment files (e.g., `moodle/deployment.yaml`, `postgres/deployment.yaml`).
2. Run `make validate` to catch schema errors.
3. Run `make diff` to review changes.
4. Run `make apply` to deploy.
5. Monitor with `make status` and `make logs`.

For Moodle version upgrades, also run the CLI upgrade script:

```powershell
kubectl exec -it -n moodle deploy/moodle -- php /var/www/html/admin/cli/upgrade.php
```

For major version upgrades, test in the dev overlay first:

```powershell
.\make.ps1 apply-dev
```

## Troubleshooting

### Moodle shows "Site is being upgraded"

Run the CLI installer or upgrade script:

```powershell
kubectl exec -it -n moodle deploy/moodle -- php /var/www/html/admin/cli/install.php
```

### Redis connection refused

Ensure the Redis StatefulSet is running:

```powershell
kubectl get pods -n moodle -l app=redis
```

Check Redis authentication:

```powershell
kubectl logs -n moodle -l app=redis
```

### PostgreSQL backup failing

Check the backup CronJob logs:

```powershell
kubectl logs -n moodle -l job-name=postgres-backup
```

### Ingress returns 404

Verify the ingress controller namespace matches the NetworkPolicy selector:

```powershell
kubectl get ns
```

### Pods fail to schedule with imagePullPolicy: Never

The Moodle image is now pulled from Docker Hub by default (`IfNotPresent`). If you built a custom image, push it to a registry accessible by your cluster.

### HPA not scaling

Ensure Metrics Server is installed in your cluster:

```powershell
kubectl top nodes
kubectl top pods -n moodle
```

## License

MIT
