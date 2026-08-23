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

## Prerequisites

- Kubernetes 1.24+
- cert-manager (for TLS)
- nginx-ingress-controller (or compatible)
- A storage class supporting `ReadWriteOnce` PVCs
- `kubectl` with `kustomize` support (built into kubectl 1.14+)
- `kubeconform` for validation (optional but recommended)
- `kubeseal` for secret management (optional but recommended)

## Quick Start

1. Generate secrets:

```bash
make secrets
# Edit secrets.yaml with strong, unique values
```

2. Validate manifests:

```bash
make validate
```

3. Deploy:

```bash
make apply
```

On Windows PowerShell:

```powershell
.\make.ps1 apply
```

4. Complete Moodle setup:

Visit `https://moodle.localdomain` (update `ingress.yaml` with your domain first). Auto-install is disabled by default; run the Moodle CLI installer manually or set `MOODLE_DOCKER_AUTOINSTALL=1` temporarily.

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
│   ├── secrets.yaml          # Sensitive values (gitignored)
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
├── secrets.yaml.example      # Secret template
├── sealed-secrets.yaml       # Encrypted secrets for Git (optional)
├── Makefile                  # Deployment automation (Linux/macOS)
├── make.ps1                  # Deployment script (Windows)
├── .gitignore
└── README.md
```

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
| `TZ` | Timezone | `UTC` |

### Ingress

Update `base/ingress.yaml`:
- Change `moodle.localdomain` to your actual domain
- Ensure your ingress controller namespace matches the NetworkPolicy selector in `base/network-policies.yaml` (default: `ingress-nginx`)

### Storage

- `postgres-pvc`: 20Gi for database data
- `moodledata-pvc`: 50Gi for user uploads, logs, sessions
- `postgres-backup-pvc`: 10Gi for daily pg_dump backups
- `redis-pvc`: 5Gi for Redis persistence

All PVCs default to storage class `standard`. Override via Kustomize patches to match your cluster's storage class.

## Multi-Environment Deployments

This project uses [Kustomize](https://kustomize.io/) (built into `kubectl`) for environment overlays.

### Dev Environment

```bash
make apply-dev
```

### Production Environment

```bash
make apply-prod
```

### Custom Overlays

Create a new directory under `overlays/` with a `kustomization.yaml` that references `../../base` and applies patches for namespace, replicas, domain, and storage class.

## Secrets Management

### Option 1: Plaintext (Development Only)

```bash
make secrets
# Edit secrets.yaml with strong values
```

> **Security note:** Never commit `secrets.yaml` to version control. It is gitignored. If it was previously committed, rotate all passwords immediately and purge from git history.

### Option 2: Sealed Secrets (Recommended for GitOps)

[Sealed Secrets](https://sealed-secrets.netlify.app/) is an open source Kubernetes controller and CLI tool that encrypts secrets into a format safe for Git storage.

1. Install the Sealed Secrets controller in your cluster:

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

2. Seal your secrets:

```bash
make seal
```

3. Commit `sealed-secrets.yaml` to Git.

4. Apply sealed secrets:

```bash
make unseal
```

The Sealed Secrets controller automatically decrypts and creates the Kubernetes Secret in the cluster.

## Backups

Backups run daily at 02:00 UTC and retain 7 days of history.

### Manual Backup

```bash
make backup
```

### Restore

```bash
kubectl exec -n moodle deploy/postgres -- pg_restore -U moodleuser -d moodle /backups/<backup-file>.sql.gz
```

## Security

- Pods run as non-root users with dropped capabilities
- `readOnlyRootFilesystem` on all containers where possible
- `allowPrivilegeEscalation: false` on all containers
- Network policies restrict traffic to required paths only
- Pod Security Standards enforced at `baseline`
- TLS termination via cert-manager / Let's Encrypt
- Secrets separated from ConfigMaps
- Support for Sealed Secrets for Git-safe secret storage
- Topology spread constraints reduce blast radius

## Horizontal Scaling

To scale Moodle beyond 1 replica:
1. Replace `moodledata-pvc` with a `ReadWriteMany` capable storage (NFS, CephFS, or MinIO via s3fs)
2. Update the PVC `accessModes` to `ReadWriteMany`
3. Increase `replicas` in the dev or prod overlay

PgBouncer and Redis are already deployed as separate scalable services.

## Maintenance

```bash
make apply        # Deploy / update base manifests
make apply-dev    # Deploy dev environment
make apply-prod   # Deploy production environment
make delete       # Remove base manifests
make backup       # Trigger immediate backup
make status       # Show resource status
make logs         # Tail Moodle logs
make shell        # Exec into Moodle pod
make validate     # Validate all manifests with kubeconform
make diff         # Show diff before applying
make test         # Smoke test deployed Moodle
make seal         # Seal secrets for Git storage
make unseal       # Apply sealed secrets to cluster
make build-base   # Build base manifests
make build-dev    # Build dev overlay
make build-prod   # Build prod overlay
```

On Windows PowerShell, replace `make <target>` with `.\make.ps1 <target>`.

## Performance Tuning

- **Redis**: Moodle is configured to use Redis for session caching and application cache, significantly improving page load times.
- **PgBouncer**: PostgreSQL connections are pooled through PgBouncer, reducing connection overhead and preventing `max_connections` exhaustion.
- **Resource Limits**: All containers have explicit requests and limits for predictable scheduling.
- **Topology Spread**: Pods are spread across nodes to improve availability.

## Upgrade Procedure

1. Update image tags in the relevant deployment files (e.g., `moodle/deployment.yaml`, `postgres/deployment.yaml`).
2. Run `make validate` to catch schema errors.
3. Run `make diff` to review changes.
4. Run `make apply` to deploy.
5. Monitor with `make status` and `make logs`.

For Moodle version upgrades, also run the CLI upgrade script:

```bash
kubectl exec -it -n moodle deploy/moodle -- php /var/www/html/admin/cli/upgrade.php
```

## Troubleshooting

### Moodle shows "Site is being upgraded"

Run the CLI installer or upgrade script:

```bash
kubectl exec -it -n moodle deploy/moodle -- php /var/www/html/admin/cli/install.php
```

### Redis connection refused

Ensure the Redis StatefulSet is running:

```bash
kubectl get pods -n moodle -l app=redis
```

### PostgreSQL backup failing

Check the backup CronJob logs:

```bash
kubectl logs -n moodle -l job-name=postgres-backup
```

### Ingress returns 404

Verify the ingress controller namespace matches the NetworkPolicy selector:

```bash
kubectl get ns
```

## License

MIT
