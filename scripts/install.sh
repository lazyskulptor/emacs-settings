#!/bin/bash
# Install dependencies and set up local configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMACS_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib.sh"

log "Setting up Emacs configuration..."

# ── Optional: warn about missing tools ──────────────────────────

check::git || {
  error "Cannot continue without git"
  exit 1
}

check::emacs29 || true
check::native_comp || true

# ── Mandatory: check for Python and Node.js ────────────────────

check::uv || {
  error "uv is required for Python dependency management"
  echo ""
  echo "Install from: https://docs.astral.sh/uv/getting-started/installation/"
  echo ""
  echo "Quick install (macOS/Linux):"
  echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
}

check::node || {
  error "Node.js is required"
  echo ""
  echo "Install from: https://nodejs.org/"
  exit 1
}

check::npm || {
  error "npm is required (ships with Node.js)"
  exit 1
}

# ── Install dependencies ─────────────────────────────────────────

install_deps "$EMACS_DIR" || {
  error "Failed to install dependencies"
  exit 1
}

# ── Install direnv (optional) ────────────────────────────────────

log "Setting up optional tools..."
install_direnv || true

# ── Set up properties.local.el ───────────────────────────────────

ensure_properties_local "$EMACS_DIR" || {
  error "Failed to set up properties.local.el"
  exit 1
}

# ── Summary ──────────────────────────────────────────────────────

echo ""
success "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.emacs.d/properties.local.el with your machine-specific paths"
echo "  2. Run: bash scripts/doctor.sh (to verify setup)"
echo "  3. Start Emacs: emacs"
