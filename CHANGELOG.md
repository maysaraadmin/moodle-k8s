# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
