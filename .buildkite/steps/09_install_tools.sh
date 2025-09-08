#!/usr/bin/env bash
set -euo pipefail

TOOLS="$PWD/.tools/bin"; mkdir -p "$TOOLS"; chmod 755 "$TOOLS"

# Helper: die if a fetched file looks like HTML
is_html() { head -n1 "$1" | grep -qiE '<!doctype html>|<html'; }

# --- Gitleaks (darwin arm64)
GL_VER="8.18.4"
curl -fsSL -o /tmp/gitleaks.tar.gz \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_darwin_arm64.tar.gz"
tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
mv /tmp/gitleaks "$TOOLS/"

# --- Trivy (darwin arm64)
TV_VER="0.49.1"
curl -fsSL -o /tmp/trivy.tar.gz \
  "https://github.com/aquasecurity/trivy/releases/download/v${TV_VER}/trivy_${TV_VER}_macOS-ARM64.tar.gz"
tar -xzf /tmp/trivy.tar.gz -C /tmp trivy
mv /tmp/trivy "$TOOLS/"

# --- Syft (darwin arm64)
SYFT_VER="1.18.0"
curl -fsSL -o "$TOOLS/syft" \
  "https://github.com/anchore/syft/releases/download/v${SYFT_VER}/syft_${SYFT_VER}_darwin_arm64"
chmod +x "$TOOLS/syft"

# --- Cosign (darwin arm64)
CS_VER="v2.2.4"
curl -fsSL -o "$TOOLS/cosign" \
  "https://github.com/sigstore/cosign/releases/download/${CS_VER}/cosign-darwin-arm64"
chmod +x "$TOOLS/cosign"

# --- Semgrep: try 3 strategies, else mark for container fallback ---
SEM_OK=0

# Strategy A: Homebrew
if command -v brew >/dev/null 2>&1; then
  brew install semgrep || true
  if command -v semgrep >/dev/null 2>&1; then SEM_OK=1; fi
fi

# Strategy B: pipx (local user) if brew failed
if [ "$SEM_OK" -eq 0 ] && command -v python3 >/dev/null 2>&1; then
  python3 -m pip install --user -q pipx || true
  python3 -m pipx ensurepath || true
  export PATH="$HOME/.local/bin:$PATH"
  python3 -m pipx install "semgrep==1.77.0" || true
  if command -v semgrep >/dev/null 2>&1; then SEM_OK=1; fi
fi

# Strategy C: download official install script *safely* (no pipe)
if [ "$SEM_OK" -eq 0 ]; then
  curl -fsSL -o /tmp/semgrep-install.sh "https://semgrep.dev/install.sh" || true
  if [ -s /tmp/semgrep-install.sh ] && ! is_html /tmp/semgrep-install.sh; then
    bash /tmp/semgrep-install.sh --version 1.77.0 || true
    if [ -x "$HOME/.local/bin/semgrep" ]; then
      ln -sf "$HOME/.local/bin/semgrep" "$TOOLS/semgrep"
      SEM_OK=1
    fi
  fi
fi

# If still not OK, mark fallback
if [ "$SEM_OK" -eq 0 ]; then
  echo "SEMGR_EP_FALLBACK=1" >> "$BUILDKITE_ENV_FILE"
  echo "Semgrep native install failed; will use container fallback."
else
  echo "Semgrep installed."
fi

# Persist PATH for later steps
echo "PATH=$TOOLS:\$PATH" >> "$BUILDKITE_ENV_FILE"

# Smoke test
export PATH="$TOOLS:$PATH"
gitleaks version
trivy --version
syft version
cosign version
command -v semgrep >/dev/null && semgrep --version || echo "Semgrep will use container fallback"
