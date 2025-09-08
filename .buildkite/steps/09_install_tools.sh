#!/usr/bin/env bash
set -euo pipefail

TOOLS_DIR="$PWD/.tools/bin"
mkdir -p "$TOOLS_DIR"
chmod 755 "$TOOLS_DIR"

# --- Gitleaks (arm64)
GL_VER="8.18.4"
curl -sSL -o /tmp/gitleaks.tar.gz \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_darwin_arm64.tar.gz"
tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
mv /tmp/gitleaks "$TOOLS_DIR/"

# --- Semgrep (official installer drops into ~/.local/bin)
curl -sSL https://semgrep.dev/install.sh | bash -s -- --version 1.77.0
# Symlink into tools dir for predictability
if [ -x "$HOME/.local/bin/semgrep" ]; then ln -sf "$HOME/.local/bin/semgrep" "$TOOLS_DIR/semgrep"; fi

# --- Trivy (arm64)
TV_VER="0.49.1"
curl -sSL -o /tmp/trivy.tar.gz \
  "https://github.com/aquasecurity/trivy/releases/download/v${TV_VER}/trivy_${TV_VER}_macOS-ARM64.tar.gz"
tar -xzf /tmp/trivy.tar.gz -C /tmp trivy
mv /tmp/trivy "$TOOLS_DIR/"

# --- Syft (arm64)
SYFT_VER="1.18.0"
curl -sSL -o "$TOOLS_DIR/syft" \
  "https://github.com/anchore/syft/releases/download/v${SYFT_VER}/syft_${SYFT_VER}_darwin_arm64"
chmod +x "$TOOLS_DIR/syft"

# --- Cosign (arm64)
CS_VER="v2.2.4"
curl -sSL -o "$TOOLS_DIR/cosign" \
  "https://github.com/sigstore/cosign/releases/download/${CS_VER}/cosign-darwin-arm64"
chmod +x "$TOOLS_DIR/cosign"

# Export PATH for later steps
echo "PATH=$TOOLS_DIR:\$PATH" >> "$BUILDKITE_ENV_FILE"

# Smoke test
export PATH="$TOOLS_DIR:$PATH"
gitleaks version
semgrep --version
trivy --version
syft version
cosign version
