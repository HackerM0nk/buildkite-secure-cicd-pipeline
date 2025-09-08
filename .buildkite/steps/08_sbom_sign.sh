#!/usr/bin/env bash
set -euo pipefail
. scripts/lib/env.sh
source_tag_or_die

mkdir -p artifacts

IMAGES=("hackermonk/order:$TAG" "hackermonk/payment:$TAG")

# Prefer syft for SBOM; fallback to trivy if syft missing
have_syft=0
have_trivy=0
command -v syft >/dev/null 2>&1 && have_syft=1
command -v trivy >/dev/null 2>&1 && have_trivy=1

if [ "$have_syft" -eq 0 ] && [ "$have_trivy" -eq 0 ]; then
  echo "Neither syft nor trivy installed; cannot generate SBOM."
  exit 1
fi

for img in "${IMAGES[@]}"; do
  name="$(echo "$img" | sed 's|[:/]|-|g')" # e.g. hackermonk-order-abc1234

  if [ "$have_syft" -eq 1 ]; then
    echo "--- SBOM (syft) for $img → artifacts/sbom-${name}.spdx.json"
    syft "$img" -o spdx-json > "artifacts/sbom-${name}.spdx.json"
  else
    echo "--- SBOM (trivy) for $img → artifacts/sbom-${name}.cdx.json"
    # CycloneDX via trivy
    trivy image --timeout 10m --quiet --format cyclonedx --output "artifacts/sbom-${name}.cdx.json" "$img"
  fi
done

# Optional: sign SBOM files as blobs with cosign (works without a registry)
if [ -n "${COSIGN_PRIVATE_KEY:-}" ]; then
  if ! command -v cosign >/dev/null 2>&1; then
    echo "cosign not found; skipping signing"
  else
    echo "--- Signing SBOM files with cosign (sign-blob)"
    for f in artifacts/sbom-*.json; do
      [ -f "$f" ] || continue
      cosign sign-blob --yes --key env://COSIGN_PRIVATE_KEY "$f" > "${f}.sig"
      cosign verify-blob --key env://COSIGN_PRIVATE_KEY --signature "${f}.sig" "$f" >/dev/null
    done
  fi
else
  echo "--- COSIGN_PRIVATE_KEY not provided; skipping signing (SBOMs still produced)"
fi

echo "--- SBOM step complete; outputs in ./artifacts/"
