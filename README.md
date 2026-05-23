# Cloud-Native Secure CI/CD Pipeline with IaC

> **Assignment #2 — DevOps Engineering**  
> Automated software delivery: Containerization · Terraform IaC · GitHub Actions · Security Scanning · Zero-Downtime Deployment

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKSTATION                               │
│                                                                             │
│   git push origin main                                                      │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │  webhook trigger
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GITHUB ACTIONS RUNNER                               │
│                                                                             │
│  ┌─────────────────┐   ┌──────────────────┐   ┌──────────────────────────┐ │
│  │  STAGE 1        │   │  STAGE 2         │   │  STAGE 3                 │ │
│  │  Lint & Secret  │──▶│  Docker Build    │──▶│  Security Scan (Trivy)   │ │
│  │  Scan           │   │  (Multi-stage)   │   │  CRITICAL/HIGH → FAIL    │ │
│  │                 │   │                  │   │                          │ │
│  │  • Flake8       │   │  • BuildKit      │   │  • CVE scan (OS + pip)   │ │
│  │  • Hadolint     │   │  • Layer cache   │   │  • IaC miscfg scan       │ │
│  │  • Gitleaks     │   │  • Non-root img  │   │                          │ │
│  └─────────────────┘   └──────────────────┘   └──────────────────────────┘ │
│                                                          │                  │
│  ┌─────────────────┐   ┌──────────────────┐             │ (only on main)   │
│  │  STAGE 5        │   │  STAGE 4         │◀────────────┘                  │
│  │  Deploy         │◀──│  Push to         │                                │
│  │  (Rolling)      │   │  Docker Hub      │                                │
│  │                 │   │  :sha + :latest  │                                │
│  │  • Terraform    │   │                  │                                │
│  │  • SSH + health │   │                  │                                │
│  │    check gate   │   │                  │                                │
│  └────────┬────────┘   └──────────────────┘                                │
└───────────┼─────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS CLOUD (Terraform-provisioned)                   │
│                                                                             │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │  VPC  10.0.0.0/16                                                    │  │
│   │                                                                      │  │
│   │   ┌──────────────────────────────────────────────────────────────┐   │  │
│   │   │  Public Subnet  10.0.1.0/24                                  │   │  │
│   │   │                                                              │   │  │
│   │   │   ┌──────────────────────────────────────────────────────┐   │   │  │
│   │   │   │  Security Group                                      │   │   │  │
│   │   │   │  Inbound:  80/tcp ✓  443/tcp ✓  22/tcp (your IP) ✓  │   │   │  │
│   │   │   │  Outbound: all ✓                                     │   │   │  │
│   │   │   │                                                      │   │   │  │
│   │   │   │   ┌──────────────────────────────────────────────┐   │   │   │  │
│   │   │   │   │  EC2 t3.micro  (Ubuntu 22.04)                │   │   │   │  │
│   │   │   │   │                                              │   │   │   │  │
│   │   │   │   │  Docker Engine                               │   │   │   │  │
│   │   │   │   │  ┌────────────────────────────────────────┐  │   │   │   │  │
│   │   │   │   │  │  Container: cicd-demo-app              │  │   │   │   │  │
│   │   │   │   │  │  Image: dockerhub/cicd-demo-app:sha    │  │   │   │   │  │
│   │   │   │   │  │  Port: 5000 → host 80                  │  │   │   │   │  │
│   │   │   │   │  │  User: appuser (non-root)              │  │   │   │   │  │
│   │   │   │   │  │  /health  ← rolling update gate        │  │   │   │   │  │
│   │   │   │   │  └────────────────────────────────────────┘  │   │   │   │  │
│   │   │   │   └──────────────────────────────────────────────┘   │   │   │  │
│   │   │   └──────────────────────────────────────────────────────┘   │   │  │
│   │   └──────────────────────────────────────────────────────────────┘   │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
cicd-pipeline/
├── app/
│   ├── app.py              # Flask application with /health endpoint
│   └── requirements.txt    # Python dependencies
├── terraform/
│   ├── main.tf             # VPC, Subnet, Security Group, EC2
│   ├── variables.tf        # Input variable declarations
│   └── outputs.tf          # Post-apply output values
├── .github/
│   └── workflows/
│       └── cicd.yml        # 5-stage GitHub Actions pipeline
├── Dockerfile              # Multi-stage, non-root Docker build
├── docker-compose.yml      # Local testing stack
├── nginx.conf              # Reverse proxy config
├── .gitignore
└── README.md
```

---

## Task Summary

| Task | Description | Marks |
|------|-------------|-------|
| Task 1 | Multi-stage Dockerfile, non-root user | 5 |
| Task 2 | Terraform: VPC + Subnet + SG + EC2 | 5 |
| Task 3 | GitHub Actions: 5-stage CI/CD pipeline | 7 |
| Task 4 | `/health` endpoint + zero-downtime rolling update | 3 |

---

## Prerequisites

- [Docker Desktop](https://docs.docker.com/get-docker/)
- [Terraform CLI ≥ 1.6](https://developer.hashicorp.com/terraform/install)
- AWS account (or skip to local Docker Compose testing)
- Git

---

## Local Testing — Step by Step

### Option A: Docker Compose (Recommended, no AWS needed)

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/cicd-pipeline.git
cd cicd-pipeline

# 2. Build and start the full stack (app + nginx)
docker compose up --build

# 3. Verify the application is running
curl http://localhost/
# Expected: {"message": "Hello from CI/CD Pipeline Demo App", ...}

# 4. Verify the health endpoint
curl http://localhost/health
# Expected: {"status": "healthy", "uptime_seconds": X.X, ...}

# 5. Check container health status
docker inspect cicd-demo-app --format='{{.State.Health.Status}}'
# Expected: healthy

# 6. Tear down
docker compose down
```

### Option B: Build the Docker Image Manually

```bash
# Build the image
docker build -t cicd-demo-app:local .

# Confirm non-root user
docker run --rm cicd-demo-app:local whoami
# Expected: appuser

# Run the container
docker run -d -p 5000:5000 --name myapp cicd-demo-app:local

# Test endpoints
curl http://localhost:5000/
curl http://localhost:5000/health
curl http://localhost:5000/ready

# Clean up
docker rm -f myapp
```

### Option C: Run the Trivy Security Scan Locally

```bash
# Install Trivy (Linux/macOS)
brew install trivy           # macOS
# or: https://aquasecurity.github.io/trivy/latest/getting-started/installation/

# Build image first
docker build -t cicd-demo-app:local .

# Scan for vulnerabilities
trivy image --severity CRITICAL,HIGH cicd-demo-app:local
```

---

## Deploying to AWS

### Step 1 — Configure AWS credentials

```bash
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

### Step 2 — Set variables

Create `terraform/terraform.tfvars`:

```hcl
aws_region       = "us-east-1"
key_pair_name    = "your-ec2-keypair"
docker_image     = "yourdockerhubuser/cicd-demo-app"
ssh_allowed_cidr = "YOUR_IP/32"
```

### Step 3 — Provision infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform will output the `app_url` and `health_check_url`.

### Step 4 — Verify deployment

```bash
curl $(terraform output -raw health_check_url)
```

---

## GitHub Actions Setup

Add these secrets to your repository (**Settings → Secrets → Actions**):

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `EC2_HOST` | Public IP of your EC2 instance |
| `EC2_SSH_KEY` | Private SSH key content (PEM) |

Once set, every `git push` to `main` automatically triggers all 5 pipeline stages.

---

## Pipeline Stages

```
Stage 1: Lint & Secret Scan
  ├── Flake8          (Python syntax & style)
  ├── Hadolint        (Dockerfile best practices)
  └── Gitleaks        (leaked API keys / secrets)

Stage 2: Build
  └── Docker BuildKit (multi-stage, cached layers)

Stage 3: Security Scan
  ├── Trivy image scan (CVEs in OS packages + pip deps)
  └── Trivy fs scan   (IaC misconfigurations)
        ↓ FAIL on CRITICAL/HIGH CVEs

Stage 4: Push
  └── Docker Hub  →  :git-sha  +  :latest

Stage 5: Deploy
  ├── Terraform apply (infrastructure update)
  └── SSH rolling update:
        1. Pull new image
        2. Start new container on port 5001
        3. Poll /health until 200 OK
        4. Swap containers (zero downtime)
        5. Prune old images
```

---

## Security Highlights

- **Non-root container**: `appuser` runs the app; root escalation is impossible
- **Multi-stage build**: final image contains zero build tools or pip metadata
- **Gitleaks**: blocks commits with hardcoded secrets before they reach CI
- **Trivy**: fails the pipeline if CRITICAL or HIGH CVEs are found in the image
- **Security Group**: only ports 80, 443, and 22 (restricted CIDR) are open
- **Terraform state**: `.tfstate` is gitignored; use S3 remote backend in production

---

## Health Check & Zero-Downtime Deployment

The Flask app exposes three endpoints:

| Endpoint | Purpose |
|----------|---------|
| `/` | Application root |
| `/health` | Liveness probe — returns `{"status":"healthy"}` with HTTP 200 |
| `/ready` | Readiness probe — confirms app has fully started |

The rolling update script in Stage 5 starts a new container, polls `/health` every 5 seconds (up to 30 attempts = 150 s), and only promotes it to production traffic once it passes. If health never passes, the new container is deleted and the old one continues serving traffic — **zero downtime, automatic rollback**.

---

## License

MIT
