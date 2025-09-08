````markdown
# A Practical Security-First Go Microservices Stack on Buildkite + Minikube

**Author:** Your Name  
**Repo:** `HackerM0nk/buildkite-secure-cicd-pipeline` (branch: `test`)  
**Stack:** Go (Order/Payment, gRPC) · MySQL · Docker · Kubernetes/Minikube · Buildkite  
**Security:** Gitleaks · Semgrep · OSV (Go SCA) · Trivy (image) · SBOM (Syft/Trivy) · Cosign (sign-blob)

---

## What this is

Two Go services — **order** (HTTP REST + gRPC gateway) and **payment** (gRPC) — talk to **MySQL**.  
Everything is **containerized and continuously deployed** to **Minikube** across three namespaces (`order`, `payment`, `mysql`) on every Buildkite run.

The pipeline is **security-first** and **end-to-end**:
**secret scanning → SAST → SCA → build → image scan → SBOM & cryptographic signing → deploy** — all **without any external registry**.  
Images are built with short, reproducible commit tags, loaded directly into Minikube, manifests are templated via `envsubst`, and the result is live pods you can verify with `kubectl` in minutes.  
All scans and SBOMs are uploaded as artifacts for auditability.

---

## Architecture (at a glance)

- **Order service**
  - Serves health on HTTP; calls `payment` over gRPC
  - Env: `ENV`, `APPLICATION_PORT`, `DATA_SOURCE_URL`, `PAYMENT_SERVICE_URL`

- **Payment service**
  - gRPC server
  - Env: `ENV`, `APPLICATION_PORT`, `DATA_SOURCE_URL`

- **MySQL**
  - Bootstrapped via init SQL (DBs + users created)

- **Networking**
  - `mysql.mysql.svc.cluster.local:3306`
  - `order.order.svc.cluster.local:8080`
  - `payment.payment.svc.cluster.local:8081`
  - Order → Payment uses internal gRPC

---

## CI/CD (Buildkite) — flow

1. **Setup**: compute `TAG`, print versions, persist `build.env`.
2. **Pre-build security**:
   - **Gitleaks** (secrets) → SARIF
   - **Semgrep** (SAST) → SARIF
   - **OSV** (Go SCA) → JSON/TXT
3. **Build**: `docker buildx` images for `order` and `payment` (`linux/arm64`), tag `hackermonk/<svc>:$TAG`.
4. **Post-build security**:
   - **Trivy** image scan → SARIF/JSON
   - **SBOM** (Syft SPDX JSON; fallback Trivy CycloneDX) → `artifacts/`
   - **Cosign** `sign-blob` SBOMs → `*.sig`
5. **Deploy**: `minikube image load`, `envsubst` manifests, `kubectl apply`.
6. **Reports**: All artifacts uploaded under `artifacts/` and linked in a Buildkite annotation.

---

## Quickstart

**Prereqs**: Docker Desktop (Mac), Minikube + `kubectl`, Buildkite Agent.

**Run**
1. `minikube start`
2. Push a commit → pipeline runs end-to-end.

**Verify**
```bash
kubectl -n mysql   get pods,svc
kubectl -n order   get pods,svc
kubectl -n payment get pods,svc
````

**DB sanity**

```bash
kubectl -n mysql run mysql-client --rm -it --image=mysql:8.0 -- \
  sh -lc 'mysql -h mysql -uroot -ppassword -e "SHOW DATABASES"'
```

**gRPC sanity (in-cluster)**

```bash
kubectl -n order run grpcurl --restart=Never --rm -it \
  --image=fullstorydev/grpcurl:v1.9.1 -- \
  sh -lc 'grpcurl -plaintext payment.payment.svc.cluster.local:8081 list || true'
```

---

## Troubleshooting

* **`DATA_SOURCE_URL environment variable is missing`**
  Make sure Deployments set all required env vars (templated via `envsubst`).

* **`Access denied for user … to database`**
  Ensure MySQL init SQL creates the same DB/user/password your env points to.

* **gRPC reflection not available**
  Use `grpcurl` with protos or keep reflection enabled in the service.

---

## Why it’s useful

* **Security first**: secrets, SAST, SCA, image scanning, SBOMs, signatures—built in.
* **Reproducible**: no external registry; `minikube image load` for fast local demos.
* **Extensible**: clean scripts, artifacts, and docs to build on.

---

## Roadmap

* **mTLS & L7 authz** with Cilium/Istio between order↔payment
* **OPA/Gatekeeper** policies (no `latest`, resource limits, signed SBOM required)
* **Sigstore** (cosign sign & verify; Rekor transparency log) with GHCR
* **Observability**: in-cluster Jaeger + OTEL traces across calls

```
::contentReference[oaicite:0]{index=0}
```
