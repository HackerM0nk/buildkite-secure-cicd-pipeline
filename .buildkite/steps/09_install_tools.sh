#!/usr/bin/env bash
set -euo pipefail

# Where we install local binaries (if not via brew)
TOOLS="$PWD/.tools/bin"
mkdir -p "$TOOLS"; chmod 755 "$TOOLS"

# Write results to env for downstream steps
ENV_OUT="$BUILDKITE_ENV_FILE"

# Helpful flags for later steps (default = use local binaries)
USE_GITLEAKS_CONTAINER=0
USE_TRIVY_CONTAINER=0
USE_SEMGREP_CONTAINER=0

export HOMEBREW_NO_AUTO_UPDATE=1
export PATH="$TOOLS:$HOME/.local/bin:$PATH"

echo "--- Detecting platform"
OS="$(uname -s)"; ARCH="$(uname -m)"
echo "OS=$OS ARCH=$ARCH"

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- Try Homebrew first on macOS ----------
if [ "$OS" = "Darwin" ] && have brew; then
  echo "--- Installing via Homebrew"
  set +e
  brew install -q gitleaks trivy syft cosign python@3.11 pipx
  BREW_RC=$?
  set -e
  if [ $BREW_RC -ne 0 ]; then
    echo "Brew install had issues; will use selective fallbacks."
  else
    # Ensure pipx on PATH (brew puts it under ~/.local/bin typically)
    python3 -m pipx ensurepath || true
  fi

  # Semgrep via pipx (more reliable than brew in CI)
  set +e
  python3 -m pipx install "semgrep==1.77.0"
  SEM_PIPX_RC=$?
  set -e
  if [ $SEM_PIPX_RC -ne 0 ]; then
    echo "pipx semgrep failed; will container-fallback for semgrep."
    USE_SEMGREP_CONTAINER=1
  fi
else
  echo "--- Homebrew not available or not macOS; will use pinned binaries/fallbacks."
fi

# ---------- Verify/install binaries if brew wasn’t enough ----------
install_gitleaks() {
  # macOS arm64 URL patterns for gitleaks v8.18.4
  local ver="8.18.4"
  for url in \
    "https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_darwin_arm64.tar.gz" \
    "https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_darwin_arm64.zip"
  do
    echo "Trying $url"
    if curl -fsSL -o /tmp/gitleaks.pkg "$url"; then
      if [[ "$url" == *.tar.gz ]]; then
        tar -xzf /tmp/gitleaks.pkg -C /tmp gitleaks && mv /tmp/gitleaks "$TOOLS/"
        return 0
      else
        command -v unzip >/dev/null 2>&1 || (echo "Install unzip"; exit 1)
        unzip -o /tmp/gitleaks.pkg -d /tmp >/dev/null && mv /tmp/gitleaks "$TOOLS/"
        return 0
      fi
    fi
  done
  return 1
}

install_trivy() {
  local ver="0.49.1"
  local url="https://github.com/aquasecurity/trivy/releases/download/v${ver}/trivy_${ver}_macOS-ARM64.tar.gz"
  if curl -fsSL -o /tmp/trivy.tar.gz "$url"; then
    tar -xzf /tmp/trivy.tar.gz -C /tmp trivy && mv /tmp/trivy "$TOOLS/"
    return 0
  fi
  return 1
}

install_syft() {
  local ver="1.18.0"
  local url="https://github.com/anchore/syft/releases/download/v${ver}/syft_${ver}_darwin_arm64"
  if curl -fsSL -o "$TOOLS/syft" "$url"; then
    chmod +x "$TOOLS/syft"
    return 0
  fi
  return 1
}

install_cosign() {
  local ver="v2.2.4"
  local url="https://github.com/sigstore/cosign/releases/download/${ver}/cosign-darwin-arm64"
  if curl -fsSL -o "$TOOLS/cosign" "$url"; then
    chmod +x "$TOOLS/cosign"
    return 0
  fi
  return 1
}

need_gitleaks=0
need_trivy=0
need_syft=0
need_cosign=0

have gitleaks || need_gitleaks=1
have trivy   || need_trivy=1
have syft    || need_syft=1
have cosign  || need_cosign=1

if [ "$need_gitleaks" -eq 1 ]; then
  echo "--- gitleaks: brew missing; trying pinned binaries"
  if ! install_gitleaks; then
    echo "gitleaks install failed -> will use container fallback"
    USE_GITLEAKS_CONTAINER=1
  fi
fi

if [ "$need_trivy" -eq 1 ]; then
  echo "--- trivy: brew missing; trying pinned binaries"
  if ! install_trivy; then
    echo "trivy install failed -> will use container fallback"
    USE_TRIVY_CONTAINER=1
  fi
fi

if [ "$need_syft" -eq 1 ]; then
  echo "--- syft: brew missing; trying pinned binaries"
  install_syft || echo "WARN: syft missing; SBOM step will degrade gracefully"
fi

if [ "$need_cosign" -eq 1 ]; then
  echo "--- cosign: brew missing; trying pinned binaries"
  install_cosign || echo "WARN: cosign missing; signing step will degrade gracefully"
fi

# ---------- Semgrep last-resort container fallback marker ----------
if ! command -v semgrep >/dev/null 2>&1; then
  USE_SEMGREP_CONTAINER=1
fi

# Export flags for later steps
{
  echo "PATH=$TOOLS:\$HOME/.local/bin:\$PATH"
  echo "USE_GITLEAKS_CONTAINER=$USE_GITLEAKS_CONTAINER"
  echo "USE_TRIVY_CONTAINER=$USE_TRIVY_CONTAINER"
  echo "USE_SEMGREP_CONTAINER=$USE_SEMGREP_CONTAINER"
} >> "$ENV_OUT"

echo "--- Final tool versions"
command -v gitleaks >/dev/null && gitleaks version || echo "gitleaks=container"
command -v trivy   >/dev/null && trivy --version   || echo "trivy=container"
command -v syft    >/dev/null && syft version      || echo "syft=missing"
command -v cosign  >/dev/null && cosign version    || echo "cosign=missing"
command -v semgrep >/dev/null && semgrep --version || echo "semgrep=container"
