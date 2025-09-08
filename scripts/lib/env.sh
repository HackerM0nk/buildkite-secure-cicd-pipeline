# shellcheck shell=bash
set -euo pipefail

source_tag_or_die() {
  if [ -z "${TAG:-}" ]; then
    # Try meta-data first
    if TAG="$(buildkite-agent meta-data get tag 2>/dev/null)"; then
      export TAG
    else
      # Try artifact fallback
      buildkite-agent artifact download build.env . >/dev/null 2>&1 || true
      if [ -f build.env ]; then
        # shellcheck disable=SC1091
        source build.env
      fi
    fi
  fi

  if [ -z "${TAG:-}" ]; then
    if [ -n "${BUILDKITE_COMMIT:-}" ]; then
      TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
      export TAG
    fi
  fi

  if [ -z "${TAG:-}" ]; then
    echo "FATAL: TAG is not set and could not be recovered (meta-data/artifact/commit)."
    exit 1
  fi
}
