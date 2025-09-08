#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p artifacts

# Load TAG from build.env or derive from BUILDKITE_COMMIT
if [[ ! -f build.env ]]; then
  buildkite-agent artifact download build.env . || true
fi
[[ -f build.env ]] && source build.env || true

TAG="${TAG:-}"
if [[ -z "${TAG}" && -n "${BUILDKITE_COMMIT:-}" ]]; then TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"; fi
if [[ -z "${TAG}" ]]; then
  TAG="$(docker images hackermonk/order --format '{{.Tag}}' | head -n1 || true)"
fi
[[ -n "${TAG}" ]] || { echo "FATAL: TAG not set"; exit 1; }
echo "Using TAG=${TAG}"

# Pull down docker-archives produced by the build step
for svc in order payment; do
  buildkite-agent artifact download "artifacts/${svc}-${TAG}.tar.gz" artifacts/ || true
done

scan_from_archive () {
  local svc="$1"
  local gz="artifacts/${svc}-${TAG}.tar.gz"
  local tar="artifacts/${svc}-${TAG}.tar"
  local out="artifacts/sbom-hackermonk-${svc}-${TAG}.spdx.json"
  local log="artifacts/syft-${svc}-${TAG}.log"

  [[ -f "$gz" ]] || { echo "Archive missing: $gz"; return 1; }
  echo "SBOM (syft) for ${svc} from ${gz} -> ${out}"

  # Decompress to a plain .tar (syft expects docker-archive:<tar>, not gz)
  rm -f "$tar"
  gunzip -c "$gz" > "$tar"

  # Run syft and capture stderr to a log for diagnostics
  if ! syft -q "docker-archive:${tar}" -o spdx-json > "$out" 2> "$log"; then
    echo "Syft failed for ${svc}. See $log"
    cat "$log" || true
    return 1
  fi

  # Optional: sign the SBOM blob (local keyless via ambient provider if configured)
  if command -v cosign >/dev/null 2>&1; then
    cosign sign-blob --yes "$out" > "${out}.sig" 2>>"$log" || true
  fi
}

# Prefer archives (portable). If missing, fall back to local docker daemon.
have_archives=1
for svc in order payment; do [[ -f "artifacts/${svc}-${TAG}.tar.gz" ]] || have_archives=0; done

if [[ "$have_archives" -eq 1 ]]; then
  scan_from_archive order
  scan_from_archive payment
else
  echo "No docker-archive artifacts found; scanning from local docker daemon"
  for svc in order payment; do
    img="hackermonk/${svc}:${TAG}"
    out="artifacts/sbom-hackermonk-${svc}-${TAG}.spdx.json"
    log="artifacts/syft-${svc}-${TAG}.log"
    echo "SBOM (syft) for ${img} -> ${out}"
    if ! docker image inspect "$img" >/dev/null 2>&1; then
      echo "Image not found locally: $img"; exit 1
    fi
    syft -q "docker:${img}" -o spdx-json > "$out" 2> "$log" || {
      echo "Syft failed for ${img}. See $log"; cat "$log" || true; exit 1; }
    command -v cosign >/dev/null 2>&1 && cosign sign-blob --yes "$out" > "${out}.sig" 2>>"$log" || true
  done
fi

# Upload SBOMs + logs
buildkite-agent artifact upload "artifacts/sbom-*.json" || true
buildkite-agent artifact upload "artifacts/sbom-*.json.sig" || true
buildkite-agent artifact upload "artifacts/syft-*.log" || true
