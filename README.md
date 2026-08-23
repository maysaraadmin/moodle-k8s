# moodle-k8s

Production-hardened Kubernetes manifests for deploying Moodle LMS on a Kubernetes cluster.

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
        └─────────────┘ └────────┘ └────────────┘
```

## Prerequisites

- Kubernetes 1.24+
- cert-manager (for TLS)
- nginx-ingress-controller (or compatible)
- A storage class supporting `ReadWriteOnce` PVCs

## Quick Start

1. Generate secrets:

```bash
cp secrets.yaml.example secrets.yaml
# Edit secrets.yaml with strong, unique values
```

> **Security note:** If `secrets.yaml` was previously committed to version control, rotate all passwords immediately and purge the file from git history using `git filter-branch` or `git filter-repo`.

2. Deploy:

```bash
make apply
```

3. Complete Moodle setup:

Visit `https://moodle.localdomain` (update `ingress.yaml` with your domain first). Auto-install is disabled by default; run the Moodle CLI installer manually or set `MOODLE_DOCKER_AUTOINSTALL=1` temporarily.

## Directory Structure

```
.
├── configmap.yaml          # Non-sensitive configuration
├── cronjob.yaml            # Moodle background task scheduler
├── ingress.yaml            # Ingress + TLS configuration
├── namespace.yaml          # Namespace with PSS labels
├── network-policies.yaml   # Network isolation rules
├── secrets.yaml            # Sensitive values (gitignored)
├── secrets.yaml.example    # Secret template
├── moodle/
│   ├── deployment.yaml     # Moodle web app
│   └── service.yaml        # ClusterIP service
├── postgres/
│   ├── deployment.yaml     # PostgreSQL database
│   ├── service.yaml        # Headless service
│   ├── backup-pvc.yaml     # Backup storage
│   └── backup-cronjob.yaml # Daily pg_dump backup
├── pvc/
│   ├── moodledata-pvc.yaml # Moodle file uploads (50Gi)
│   └── postgres-pvc.yaml   # PostgreSQL data (20Gi)
├── pdb/
│   └── pdb.yaml            # Pod Disruption Budgets
└── Makefile                # Deployment automation
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MOODLE_DOCKER_DB_TYPE` | Database driver | `pgsql` |
| `MOODLE_DOCKER_DB_HOST` | Database hostname | `postgres` |
| `MOODLE_DOCKER_DB_NAME` | Database name | `moodle` |
| `MOODLE_DOCKER_DB_USER` | Database user | `moodleuser` |
| `MOODLE_DOCKER_DB_PORT` | Database port | `5432` |
| `MOODLE_DOCKER_SSLTERMINATED` | TLS terminated at ingress | `1` |
| `MOODLE_DOCKER_AUTOINSTALL` | Auto-run Moodle installer | `0` |
| `MOODLE_DOCKER_ADMIN_USER` | Admin username | `admin` |
| `MOODLE_DOCKER_ADMIN_EMAIL` | Admin email | `admin@example.com` |
| `TZ` | Timezone | `UTC` |

### Ingress

Update `ingress.yaml`:
- Change `moodle.localdomain` to your actual domain
- Ensure your ingress controller namespace matches the NetworkPolicy selector in `network-policies.yaml` (default: `ingress-nginx`)

### Storage

- `postgres-pvc`: 20Gi for database data
- `moodledata-pvc`: 50Gi for user uploads, logs, sessions
- `postgres-backup-pvc`: 10Gi for daily pg_dump backups

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

- Pods run as non-root users
- All capabilities dropped
- Network policies restrict traffic to required paths only
- Secrets are separated from ConfigMaps
- Pod Security Standards enforced at `baseline`
- TLS termination via cert-manager / Let's Encrypt

## Horizontal Scaling

To scale Moodle beyond 1 replica, replace the `ReadWriteOnce` `moodledata-pvc` with a `ReadWriteMany` capable storage (NFS, CephFS, or MinIO via s3fs). Update the PVC `accessModes` to `ReadWriteMany` and increase `replicas` in `moodle/deployment.yaml`.

## Maintenance

```bash
make apply      # Deploy / update resources
make delete     # Remove all resources
make backup     # Trigger immediate backup
make status     # Show resource status
make logs       # Tail Moodle logs
make shell      # Exec into Moodle pod
```
