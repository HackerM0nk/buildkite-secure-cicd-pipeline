#!/usr/bin/env bash
set -euo pipefail
: "${TAG:?TAG not set}"
mkdir -p artifacts

# SBOMs with Syft
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/work" anchore/syft:latest \
  "docker:hackermonk/order:${TAG}" -o spdx-json > artifacts/sbom-order.spdx.json
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/work" anchore/syft:latest \
  "docker:hackermonk/payment:${TAG}" -o spdx-json > artifacts/sbom-payment.spdx.json

# Sign the SBOMs (no registry needed)
docker run --rm -e COSIGN_PASSWORD -v "$PWD:/work" --entrypoint sh ghcr.io/sigstore/cosign:v2.2.4 -lc '
  set -e
  cosign generate-key-pair --yes --output-key /work/artifacts/cosign.key --output-pub /work/artifacts/cosign.pub
  cosign sign-blob --key /work/artifacts/cosign.key /work/artifacts/sbom-order.spdx.json   > /work/artifacts/sbom-order.sig
  cosign sign-blob --key /work/artifacts/cosign.key /work/artifacts/sbom-payment.spdx.json > /work/artifacts/sbom-payment.sig
'
