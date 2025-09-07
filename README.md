# Secure Microservices with Buildkite CI/CD

A production-grade microservices demo showcasing secure CI/CD practices with Buildkite, Kubernetes, and security scanning.

## 🛡️ Security Features

- **Secrets Management**: Environment-based configuration with secure defaults
- **Container Security**: Non-root users, read-only filesystems, and minimal base images
- **Network Policies**: Zero-trust network model between services
- **Security Scanning**: SAST, SCA, and container vulnerability scanning
- **Kubernetes Hardening**: Pod security policies and network policies

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Kubernetes (Docker Desktop or Minikube)
- kubectl
- Buildkite Agent (for local testing)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/secure-microservices.git
   cd secure-microservices
   ```

2. **Set up environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Start local Kubernetes** (if using Minikube)
   ```bash
   minikube start
   minikube addons enable ingress
   ```

4. **Run locally with Skaffold**
   ```bash
   skaffold dev
   ```

## 🛠️ CI/CD Pipeline

The Buildkite pipeline includes:

1. **Security Scanning**
   - SAST with gosec
   - Dependency scanning with govulncheck
   - Container vulnerability scanning
   - Static analysis with golangci-lint

2. **Build & Test**
   - Multi-stage Docker builds
   - Unit and integration tests
   - Code coverage reports

3. **Deployment**
   - Staging environment for PRs
   - Production deployment from main branch
   - Manual approval gates

## 🔒 Security Best Practices

### Secrets Management
- Never commit secrets to version control
- Use Buildkite's secret management for CI/CD
- Store local secrets in `.env` (gitignored)

### Container Security
- Minimal base images (scratch/distroless)
- Non-root user execution
- Read-only root filesystem
- No shell access in production

### Kubernetes Security
- Network policies for least privilege
- Pod security policies
- Resource limits and requests
- Liveness and readiness probes

## Local Development

1. **Start local Kubernetes cluster** (if using Minikube):
   ```bash
   minikube start
   ```

2. **Build and deploy services locally**:
   ```bash
   skaffold dev
   ```

## Buildkite CI/CD Setup

1. **Fork this repository** to your GitHub account

2. **Set up Buildkite pipeline**:
   - Create a new pipeline in Buildkite
   - Connect it to your GitHub repository
   - Add the following environment variables in Buildkite:
     - `DOCKER_USERNAME`: Your Docker Hub username
     - `DOCKER_PASSWORD`: Your Docker Hub password/token
     - `KUBE_CONFIG`: Your base64-encoded kubeconfig file

3. **Deploy to Kubernetes**:
   The pipeline includes manual approval steps for staging and production deployments.

## Project Structure

```
.
├── .buildkite/           # Buildkite pipeline configuration
│   ├── pipeline.yml      # Build and deployment pipeline
│   └── deploy.sh         # Deployment script
├── order/                # Order service
├── payment/              # Payment service
├── mysql/                # MySQL configuration
├── docker-compose.ci.yml # CI environment configuration
└── skaffold.yaml         # Local development configuration
```

## Pipeline Workflow

1. **Build and Test**:
   - Builds Docker images for all services
   - Runs unit and integration tests

2. **Manual Approval**:
   - Requires manual approval for staging deployment

3. **Deploy to Staging**:
   - Deploys to staging Kubernetes cluster
   - Runs smoke tests

4. **Manual Approval**:
   - Requires manual approval for production deployment

5. **Deploy to Production**:
   - Deploys to production Kubernetes cluster

# How to Run
You can run project with following command
```bash
skaffold dev

