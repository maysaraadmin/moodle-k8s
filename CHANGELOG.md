# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-08-25

### Added
- Cross-platform Makefile for Linux/macOS/Windows
- HorizontalPodAutoscaler for Moodle (2-10 replicas, CPU 70% / memory 80%)
- RBAC ServiceAccounts with automount disabled
- ResourceQuota and LimitRange for namespace constraints
- PodDisruptionBudgets for PgBouncer and Redis
- Redis authentication via init container with secret injection
- Redis binds to 127.0.0.1 with requirepass
- readOnlyRootFilesystem on all application containers
- In-memory tmpfs for /tmp on Moodle and CronJob pods
- Pod Security Admission enforced at restricted
- backoffLimit and activeDeadlineSeconds on CronJobs
- set -euo pipefail in CronJob shell commands

### Changed
- Removed entire moodle/ source tree from Git (29K files)
- Pinned all container images to specific versions
- Moodle imagePullPolicy changed from Never to IfNotPresent
- Moodle requests/limits separated (256Mi/250m -> 512Mi/500m)
- PgBouncer image pinned to 1.22.0
- Postgres init container removed; fsGroup handles permissions
- NetworkPolicies: removed permissive TCP 443 egress
- Redis eviction policy changed from allkeys-lru to volatile-lru
- make.ps1 namespace handling fixed for dev/prod overlays
- secrets.yaml.example no longer contains hardcoded namespace
- CronJob security contexts hardened

### Fixed
- Critical: Redis authentication was disabled despite password secret existing
- Critical: PgBouncer used latest tag with no reproducibility
- Critical: moodle/ directory bloated repo with 29K application files
- High: imagePullPolicy: Never broke scheduling on standard clusters
- High: Postgres init container ran as root with CHOWN capability
- High: NetworkPolicy allowed unrestricted TCP 443 egress
- Medium: PgBouncer ConfigMap was defined but never mounted
- Medium: CronJobs lacked security contexts
- Medium: Dev/prod overlays had incompatible namespace handling
- Medium: No HPA existed for load-based scaling
- Medium: No ResourceQuota or LimitRange for namespace protection

## [1.0.0] - 2026-08-24

### Added
- Production-hardened Kubernetes manifests for Moodle LMS
- Redis 7 StatefulSet for session and application caching
- PgBouncer for PostgreSQL connection pooling
- Daily PostgreSQL backup CronJob with 7-day retention
- NetworkPolicies with default-deny and service-specific rules
- Pod Security Standards baseline labels
- Pod Disruption Budgets for moodle and postgres
- Security contexts: runAsNonRoot, drop ALL capabilities, readOnlyRootFilesystem
- Graceful shutdown (terminationGracePeriodSeconds: 30)
- RollingUpdate strategy with maxSurge/maxUnavailable
- Topology spread constraints and pod anti-affinity
- Prometheus scrape annotations
- MOODLE_DOCKER_WWWROOT and Redis environment variables
- storageClassName on all PVCs
- Kustomize base with dev/prod overlays for multi-environment
- Sealed Secrets support (seal/unseal)
- kubeconform validation (make.ps1 validate)
- make.ps1 for Windows PowerShell
- .gitignore, secrets.yaml.example, and comprehensive README
- GitHub Actions CI workflow for manifest validation

### Fixed
- Duplicate Service definition in postgres/deployment.yaml
- Invalid env schema (configMapRef inside env instead of envFrom)
