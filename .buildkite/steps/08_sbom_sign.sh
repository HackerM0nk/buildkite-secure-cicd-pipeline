#!/usr/bin/env bash
set -Eeuo pipefail

# --- Prepare workspace -------------------------------------------------------
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p artifacts

# --- Load TAG from build.env artifact (best path) ----------------------------
if [[ ! -f build.env ]]; then
  # Don't fail if it isn't there; we'll derive TAG below
  buildkite-agent artifact download build.env . || true
fi
if [[ -f build.env ]]; then
  # shellcheck disable=SC1091
  source build.env
fi

# --- Derive TAG if still empty ----------------------------------------------
TAG="${TAG:-}"
if [[ -z "${TAG}" && -n "${BUILDKITE_COMMIT:-}" ]]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
fi
if [[ -z "${TAG}" ]]; then
  # Last resort: look at local images we just built
  TAG="$(docker images hackermonk/order --format '{{.Tag}}' | head -n1 || true)"
fi
if [[ -z "${TAG}" ]]; then
  echo "FATAL: TAG is not set and could not be derived."
  echo "--- Debug:"
  echo "Have build.env?"; ls -l build.env || true
  echo "BUILDKITE_COMMIT=${BUILDKITE_COMMIT:-<unset>}"
  echo "Local images:"; docker images 'hackermonk/*' || true
  exit 1
fi
echo "--- Using TAG=${TAG}"

# --- Prefer docker-archive artifacts (cross-agent safe) ----------------------
# These should be created in 02_build.sh:
#   docker save ... > artifacts/order-${TAG}.tar.gz (and payment)
have_archives=1
for svc in order payment; do
  if [[ ! -f "artifacts/${svc}-${TAG}.tar.gz" ]]; then
    buildkite-agent artifact download "artifacts/${svc}-${TAG}.tar.gz" artifacts/ || true
  fi
  [[ -f "artifacts/${svc}-${TAG}.tar.gz" ]] || have_archives=0
done

scan_from_archive () {
  local svc="$1"
  local in="artifacts/${svc}-${TAG}.tar.gz"
  local out="artifacts/sbom-hackermonk-${svc}-${TAG}.spdx.json"
  echo "SBOM (syft) for ${svc} from ${in} -> ${out}"
  syft -q "docker-archive:${in}" -o spdx-json > "${out}"
  if command -v cosign >/dev/null 2>&1; then
    cosign sign-blob --yes "${out}" > "${out}.sig"
  fi
}

scan_from_docker () {
  local svc="$1"
  local image="hackermonk/${svc}:${TAG}"
  local out="artifacts/sbom-hackermonk-${svc}-${TAG}.spdx.json"

  echo "--- Ensuring local docker image exists: ${image}"
  if ! docker image inspect "${image}" >/dev/null 2>&1; then
    echo "ERROR: ${image} not present in local daemon and no archive provided."
    echo "Hint: ensure 02_build.sh ran on the same agent OR enable docker-archive artifacts."
    docker images 'hackermonk/*' || true
    exit 1
  fi

  echo "SBOM (syft) for ${image} -> ${out}"
  syft -q "docker:${image}" -o spdx-json > "${out}"
  if command -v cosign >/dev/null 2>&1; then
    cosign sign-blob --yes "${out}" > "${out}.sig"
  fi
}

if [[ "${have_archives}" -eq 1 ]]; then
  scan_from_archive order
  scan_from_archive payment
else
  scan_from_docker order
  scan_from_docker payment
fi

# Upload reports
buildkite-agent artifact upload "artifacts/sbom-*.json" || true
buildkite-agent artifact upload "artifacts/sbom-*.json.sig" || true
