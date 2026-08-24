# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | Yes                |
| < 1.0   | No                 |

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, please report it
responsibly by opening a private security advisory on GitHub:

https://github.com/maysaraadmin/moodle-k8s/security/advisories/new

Do not open a public issue for security vulnerabilities.

## Security Considerations

### Secrets Management

- Never commit `secrets.yaml` to version control. It is gitignored.
- Use `make.ps1 seal` to generate `sealed-secrets.yaml` for Git storage.
- Rotate all passwords immediately if `secrets.yaml` was ever committed.
- Purge secrets from git history using `git filter-repo` or `bfg`.

### Container Images

- All container images use pinned tags, not `latest`.
- Update image tags manually after testing in a non-production environment.

### Kubernetes Security

- Pods run as non-root users with dropped capabilities.
- NetworkPolicies restrict traffic to required paths only.
- Pod Security Standards are enforced at `baseline`.
- TLS termination is configured via cert-manager / Let's Encrypt.

### Cluster Hardening

- Enable audit logging on your Kubernetes cluster.
- Use RBAC to restrict access to the `moodle` namespace.
- Consider enabling Pod Security Admission at `restricted` level.
- Enable encryption at rest for PersistentVolumeClaims if supported by your storage class.
