# A Practical Security-First Go Microservices Stack on Buildkite + Minikube

**Author:** Your Name
**Repo:** `HackerM0nk/buildkite-secure-cicd-pipeline` (branch: `test`)
**Stack:** Go (Order/Payment, gRPC) · MySQL · Docker · Kubernetes/Minikube · Buildkite CI/CD
**Security:** Gitleaks (secrets) · Semgrep (SAST) · OSV (Go SCA) · Trivy (container) · SBOM (Syft/Trivy) · Cosign (sign-blob)

---

## Abstract

This project assembles a developer-friendly yet security-forward microservices platform:

* Two Go services—**order** (HTTP + gRPC gateway) and **payment** (gRPC)—talk to **MySQL**.
* Everything is containerized and deployed into **three Kubernetes namespaces** (`order`, `payment`, `mysql`) on **Minikube**.
* A **Buildkite pipeline** drives the workflow: **secret scanning**, **SAST**, **SCA**, **build**, **image scan**, **SBOM generation with signing**, and **deployment**—all reproducibly, with minimal local friction and **no external registry** dependency.

The result is a **secure-by-default inner-loop** that hiring managers can run locally to see both engineering strength and security discipline.

---

## 1. Architecture Overview

### 1.1 Services

**Order Service**

* HTTP health & API surface (via gRPC gateway in codebase)
* gRPC client to `payment` for payment processing
* Env: `ENV`, `APPLICATION_PORT`, `DATA_SOURCE_URL`, `PAYMENT_SERVICE_URL`

**Payment Service**

* gRPC server
* Env: `ENV`, `APPLICATION_PORT`, `DATA_SOURCE_URL`

**MySQL**

* Single instance, pre-created DBs and users via init SQL/ConfigMap
* Access controlled per service

### 1.2 Namespaces & Networking

* Namespaces: `mysql`, `order`, `payment`
* Services:

  * `mysql.mysql.svc.cluster.local:3306`
  * `order.order.svc.cluster.local:8080`
  * `payment.payment.svc.cluster.local:8081`
* Internal gRPC between **order → payment**

---

## 2. Repository Layout (high level)

```.
├── docker-compose.ci.yml
├── e2e
│   ├── create_order_e2e_test.go
│   ├── go.mod
│   ├── go.sum
│   └── resources
│       ├── docker-compose.yml
│       └── init.sql
├── kubernetes
│   ├── mysql-deployment.yaml
│   ├── namespaces.yaml
│   ├── order-deployment.yaml
│   ├── payment-deployment.yaml
│   └── services.yaml
├── mysql
├── order
│   ├── cmd
│   │   └── main.go
│   ├── config
│   │   └── config.go
│   ├── Dockerfile
│   ├── go.mod
│   ├── go.sum
│   └── internal
│       ├── adapters
│       │   ├── db
│       │   │   ├── db_integration_test.go
│       │   │   └── db.go
│       │   ├── grpc
│       │   │   ├── grpc.go
│       │   │   └── server.go
│       │   └── payment
│       │       └── payment.go
│       ├── application
│       │   └── core
│       │       ├── api
│       │       │   ├── api_test.go
│       │       │   └── api.go
│       │       └── domain
│       │           └── order.go
│       └── ports
│           ├── api.go
│           ├── db.go
│           └── payment.go
├── payment
│   ├── cmd
│   │   └── main.go
│   ├── config
│   │   └── config.go
│   ├── Dockerfile
│   ├── go.mod
│   ├── go.sum
│   └── internal
│       ├── adapters
│       │   ├── db
│       │   │   └── db.go
│       │   └── grpc
│       │       ├── grpc.go
│       │       └── server.go
│       ├── application
│       │   └── core
│       │       ├── api
│       │       │   └── api.go
│       │       └── domain
│       │           └── payment.go
│       └── ports
│           ├── api.go
│           └── db.go
├── README.md
└── skaffold.yaml
```

---

## 3. CI/CD Pipeline (Buildkite)

### Execution Order

**Setup**

* Establishes `TAG` (short commit), persists via meta-data + artifact (`build.env`), prints versions.

**Pre-build Security**

* **Gitleaks** (secrets) → SARIF
* **Semgrep** (SAST) → SARIF
* **OSV** (Go SCA) → text/JSON

**Build**

* `docker buildx build` for `order` and `payment`, `--platform linux/arm64`, tags `hackermonk/<svc>:$TAG`.

**Post-build Security**

* **Trivy** (image scan) → SARIF/JSON
* **SBOM** via **Syft** (SPDX JSON) (fallback: **Trivy** CycloneDX) → `artifacts/sbom-*.json`
* **Cosign** (optional) signs SBOMs as blobs → `*.sig`

**Deploy**

* `minikube image load` for both images
* `envsubst`-templated manifests apply to `mysql`, `order`, `payment`

**Reports**

* Buildkite annotation links every artifact (SARIF, SBOMs, logs) in one place.
* All reports live under `artifacts/` and are uploaded automatically.

---

## 4. Security Controls (What reviewers care about)

* **Secrets hygiene:** Gitleaks gates accidental key commits (SARIF uploaded).
* **Static analysis:** Semgrep runs Go rules; configurable policies allow time-boxed soft-fail.
* **Dependency posture:** OSV scanner flags vulnerable Go modules.
* **Container hygiene:** Trivy scans final images (OS + libs + Go deps).
* **SBOMs:** SPDX JSON (Syft) or CycloneDX (Trivy) emitted per image; cryptographic signatures (**cosign sign-blob**) ensure tamper evidence even without a registry.
* **Least-privileged DB:** Each service uses scoped MySQL credentials for its own schema.
* **No-registry local flow:** Reduces external supply-chain risk during demos.

---

## 5. Reproduce Locally (5–10 minutes)

### Prereqs

* Docker Desktop (Mac)
* Minikube + `kubectl`
* Buildkite Agent (point at your fork)

### Run the pipeline

1. Push a commit; Buildkite triggers.
2. Watch steps pass: **setup → scans → build → image scan → sbom/sign → deploy**.

### Verify deployment

```bash
kubectl -n mysql   get pods,svc
kubectl -n order   get pods,svc
kubectl -n payment get pods,svc
```

### Sanity checks

* Health (internal service IPs):

  ```bash
  kubectl -n order logs deploy/order --tail=100
  ```
* DB initialized:

  ```bash
  kubectl -n mysql run mysql-client --rm -it --image=mysql:8.0 -- \
    sh -lc 'mysql -h mysql -uroot -ppassword -e "SHOW DATABASES"'
  ```

> **Note:** The sample code from the referenced repo exposes gRPC and a gRPC-gateway. Health endpoints are HTTP; business APIs are gRPC. See **Troubleshooting** below for `grpcurl` tips.

---

## 6. Troubleshooting Quick Hits

* **Pods CrashLoopBackOff** with “`DATA_SOURCE_URL environment variable is missing`”
  → Confirm envs in the Deployment manifests; we template them and apply with `envsubst`.

* **MySQL access denied**
  → Ensure init SQL matches **user/DB names** used by both services.

* **`grpcurl` can’t connect**
  → Port-forward the service or deploy a test pod and call the in-cluster DNS name:

  ```bash
  # in-cluster discovery test
  kubectl -n order run grpcurl --restart=Never --rm -it \
    --image=fullstorydev/grpcurl:v1.9.1 -- \
    sh -lc 'grpcurl -plaintext payment.payment.svc.cluster.local:8081 list || true'
  ```

---

## 7. Roadmap (AuthN/Z & Mesh)

**Service-to-service AuthN/Z with Cilium or Istio**

* mTLS between `order` and `payment` (workload identity)
* L7 policies for gRPC methods (`OrderService/CreateOrder`, etc.)

**Policy-as-code with OPA/Gatekeeper**

* Disallow `latest` tags, require resource limits, enforce SBOM/signing.

**Supply chain with Sigstore/Cosign + Rekor**

* Push to a real registry (e.g., GHCR) with `cosign sign` + policy enforcement at admission.

**Observability**

* Wire OpenTelemetry to Jaeger in-cluster for traces across order→payment calls.

---

## 8. Why This Matters (and how I think)

This repo shows I can:

* Design microservices with **clear boundaries** and **clean deployments**.
* Build a CI/CD that **fails early** on real security issues and produces **auditable artifacts**.
* Reduce demo friction (no external registry) while keeping **best practices**: SBOMs, scans, signatures.
* Communicate clearly with docs, scripts, and sensible defaults so others can extend it quickly.
