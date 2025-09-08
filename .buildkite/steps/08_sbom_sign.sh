#!/usr/bin/env bash
set -euo pipefail

# Load TAG
if [[ -f build.env ]]; then
  # shellcheck disable=SC1091
  source build.env
fi
: "${TAG:?TAG not set}"
mkdir -p artifacts

echo "--- Downloading image archives"
buildkite-agent artifact download "artifacts/order-${TAG}.tar.gz" .
buildkite-agent artifact download "artifacts/payment-${TAG}.tar.gz" .

scan_from_archive () {
  local name="$1"       # order | payment
  local in="artifacts/${name}-${TAG}.tar.gz"
  local out="artifacts/sbom-hackermonk-${name}-${TAG}.spdx.json"

  [[ -f "${in}" ]] || { echo "Missing ${in}"; exit 1; }

  echo "SBOM (syft) for ${name} (${in}) → ${out}"
  syft -q "docker-archive:${in}" -o spdx-json > "${out}"

  if command -v cosign >/dev/null 2>&1; then
    echo "Signing SBOM for ${name}"
    cosign sign-blob --yes "${out}" > "${out}.sig"
  fi
}

scan_from_archive order
scan_from_archive payment

buildkite-agent artifact upload "artifacts/sbom-*.json" || true
buildkite-agent artifact upload "artifacts/sbom-*.json.sig" || true
