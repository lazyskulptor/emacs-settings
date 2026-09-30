#!/bin/bash
# Verify Emacs setup after installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMACS_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib.sh"

log "Checking Emacs setup..."
echo ""

# ── Prerequisites ────────────────────────────────────────────────

log "Prerequisites:"
check::git || true
check::emacs29 || true
check::native_comp || true
check::uv || true
check::node || true
check::npm || true
check::direnv || true
echo ""

# ── Installation state ───────────────────────────────────────────

log "Installation state:"

# Python venv
if [ -d "$EMACS_DIR/.venv" ]; then
  success ".venv directory exists"
  if [ -f "$EMACS_DIR/.venv/bin/python" ]; then
    success "Python executable found"
    python_version=$("$EMACS_DIR/.venv/bin/python" --version 2>&1 | awk '{print $2}')
    success "  Python $python_version"

    # Check for epc module
    if "$EMACS_DIR/.venv/bin/python" -c "import epc" 2>/dev/null; then
      success "  epc module installed"
    else
      error "  epc module missing (required for lsp-bridge)"
    fi
  else
    error "Python executable not found in .venv"
  fi
else
  error ".venv directory not found (run: bash scripts/install.sh)"
fi

# Node modules
if [ -d "$EMACS_DIR/node_modules" ]; then
  success "node_modules directory exists"

  # Check for common binaries
  for bin in prettier eslint; do
    if [ -f "$EMACS_DIR/node_modules/.bin/$bin" ]; then
      success "  $bin installed"
    else
      warn "  $bin not found (optional)"
    fi
  done
else
  warn "node_modules directory not found (optional, for web dev tools)"
fi

# properties.local.el
if [ -f "$EMACS_DIR/properties.local.el" ]; then
  success "properties.local.el exists"
else
  warn "properties.local.el not found (will be created from template on install)"
fi

# straight.el build directory
if [ -d "$EMACS_DIR/straight/build" ] && [ "$(ls -A "$EMACS_DIR/straight/build" 2>/dev/null)" ]; then
  success "straight/build/ has packages (first boot will be slow)"
else
  warn "straight/build/ empty (packages will be downloaded on first boot)"
fi

echo ""
log "Configuration files:"

# Sample checks
for file in config/remote.el config/ide/lsp-bridge.el config/org-setting.el; do
  if [ -f "$EMACS_DIR/$file" ]; then
    success "$file exists"
  else
    error "$file missing"
  fi
done

echo ""

# ── Final checks ─────────────────────────────────────────────────

log "Verification:"

# Try to load the configuration
if command -v emacs &>/dev/null; then
  if emacs --batch -l required-packages.el 2>&1 | grep -q "End of file"; then
    error "Configuration has syntax errors"
    emacs --batch -l required-packages.el 2>&1 | grep -A 5 "End of file" || true
  else
    success "Configuration loads without parse errors"
  fi
else
  warn "Emacs not found, skipping configuration check"
fi

echo ""
success "Setup check complete!"
