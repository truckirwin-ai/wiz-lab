# Wiz Lab — Technical Exercise

**Candidate:** Robert Irwin
**Date:** February 2026

## Architecture

A deliberately misconfigured two-tier AWS environment demonstrating cloud security risks detectable by Wiz.

| Layer | Technology |
|-------|-----------|
| VM | EC2 (Amazon Linux 2023) + MongoDB 6.0 |
| Container | 2048 game on EKS Auto Mode |
| IaC | Terraform |
| CI/CD | GitHub Actions (Checkov + Trivy) |

## Live Endpoints

- **App:** http://k8s-game2048-ingress2-55550fa939-1037300369.us-east-1.elb.amazonaws.com/
- **wizexercise.txt:** http://k8s-game2048-ingress2-55550fa939-1037300369.us-east-1.elb.amazonaws.com/wizexercise.txt

## Intentional Misconfigurations

| # | Finding | Location |
|---|---------|----------|
| 1 | SSH open to 0.0.0.0/0 | EC2 Security Group |
| 2 | Outdated MongoDB 6.0 (EOL July 2024) | EC2 Instance |
| 3 | Overly permissive IAM role (AdministratorAccess) | EC2 Instance Profile |
| 4 | Public S3 bucket with MongoDB backups | S3 |
| 5 | cluster-admin ClusterRoleBinding on app service account | EKS |
| 6 | Plaintext MongoDB URI as environment variable (MONGO_URI) | EKS |

## CI/CD Pipelines

| Pipeline | Tool | Trigger | Scans |
|----------|------|---------|-------|
| IaC Security Scan | Checkov | Push to terraform/ or k8s/ | Terraform + Kubernetes manifests |
| Container Security Scan | Trivy | Push to app/ | Docker image vulnerabilities |

Results are uploaded to GitHub Security → Code scanning alerts (SARIF format).

## Repository Structure

```
wiz-lab/
├── .github/workflows/
│   ├── checkov.yml     # IaC scanning pipeline
│   └── trivy.yml       # Container scanning pipeline
├── terraform/
│   ├── main.tf         # VPC, EC2, S3, IAM, Security Groups
│   ├── variables.tf
│   └── outputs.tf
├── k8s/
│   └── deployment.yaml # EKS deployment with intentional misconfigs
└── app/
    ├── app.py
    ├── Dockerfile
    ├── requirements.txt
    └── wizexercise.txt
```
