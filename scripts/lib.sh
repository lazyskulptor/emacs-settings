#!/bin/bash
# Shared shell library for install.sh and doctor.sh

set -e

# ── Colors ──────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # No Color

# ── Helper functions ────────────────────────────────────────────

log() {
  printf "%b%s%b\n" "$BLUE" "$*" "$NC" >&2
}

success() {
  printf "%b✓ %s%b\n" "$GREEN" "$*" "$NC" >&2
}

warn() {
  printf "%b⚠ %s%b\n" "$YELLOW" "$*" "$NC" >&2
}

error() {
  printf "%b✗ %s%b\n" "$RED" "$*" "$NC" >&2
}

# ── Prerequisite checks ─────────────────────────────────────────

check::git() {
  if ! command -v git &>/dev/null; then
    error "git not found. Install from https://git-scm.com/"
    return 1
  fi
  success "git $(git --version | awk '{print $3}')"
  return 0
}

check::emacs29() {
  if ! command -v emacs &>/dev/null; then
    warn "Emacs not found (needed for actual use, not for install script)"
    return 0
  fi
  local version
  version=$(emacs --version | head -1 | awk '{print $3}' | cut -d. -f1)
  if [ "$version" -lt 29 ]; then
    error "Emacs 29+ required, found version $version"
    return 1
  fi
  success "Emacs $version"
  return 0
}

check::native_comp() {
  if ! command -v emacs &>/dev/null; then
    return 0
  fi
  if emacs --batch --eval '(if (native-comp-available-p) (message "yes") (message "no"))' 2>&1 | grep -q "yes"; then
    success "native-comp available"
    return 0
  fi
  warn "native-comp not available (optional, but improves startup)"
  return 0
}

check::uv() {
  if ! command -v uv &>/dev/null; then
    error "uv not found. Install from https://docs.astral.sh/uv/getting-started/installation/"
    return 1
  fi
  success "uv $(uv --version | awk '{print $2}')"
  return 0
}

check::node() {
  if ! command -v node &>/dev/null; then
    error "Node.js not found. Install from https://nodejs.org/"
    return 1
  fi
  success "Node.js $(node --version)"
  return 0
}

check::npm() {
  if ! command -v npm &>/dev/null; then
    error "npm not found (should come with Node.js)"
    return 1
  fi
  success "npm $(npm --version)"
  return 0
}

check::direnv() {
  if ! command -v direnv &>/dev/null; then
    warn "direnv not found (optional, for automatic GitHub Packages env vars)"
    return 0
  fi
  success "direnv installed"
  return 0
}

check::properties_local() {
  local target="${1:-$HOME/.emacs.d/properties.local.el}"
  if [ -f "$target" ]; then
    success "properties.local.el exists"
    return 0
  fi
  warn "properties.local.el not found (will be created from template if missing)"
  return 0
}

# ── Installation helpers ────────────────────────────────────────

install_deps() {
  local emacs_dir="${1:-.}"

  log "Installing Python dependencies..."
  if ! uv sync --directory "$emacs_dir"; then
    error "Failed to run uv sync"
    return 1
  fi

  log "Installing npm dependencies..."
  npm install --prefix "$emacs_dir" || return 1

  success "All dependencies installed"
  return 0
}

ensure_properties_local() {
  local emacs_dir="${1:-.}"
  local target="$emacs_dir/properties.local.el"
  local template="$emacs_dir/properties.local.el.example"

  if [ -f "$target" ]; then
    success "properties.local.el already exists"
    return 0
  fi

  if [ ! -f "$template" ]; then
    error "Template $template not found"
    return 1
  fi

  log "Creating properties.local.el from template..."
  cp "$template" "$target"
  success "Created $target (edit to customize)"
  return 0
}

ensure_init_el() {
  local emacs_dir="${1:-.}"
  local target="$emacs_dir/init.el"

  if [ -f "$target" ]; then
    # init.el exists, check if it loads required-packages
    if grep -q "required-packages" "$target"; then
      success "init.el already loads required-packages"
      return 0
    else
      # Add required-packages load
      log "Adding required-packages load to init.el..."
      # Insert before (provide 'init) if it exists
      if grep -q "(provide 'init)" "$target"; then
        sed -i '' "/^(provide 'init)/i\\
(load \"~/.emacs.d/required-packages\")\\
" "$target"
      else
        # Otherwise just append
        echo "(load \"~/.emacs.d/required-packages\")" >> "$target"
      fi
      success "Updated init.el"
      return 0
    fi
  fi

  # init.el doesn't exist, create it
  log "Creating init.el..."
  cat > "$target" << 'EOF'
;;; init.el --- Main Emacs initialization file -*- lexical-binding: t; -*-

(load "~/.emacs.d/required-packages")

(provide 'init)
;;; init.el ends here
EOF
  success "Created $target"
  return 0
}

install_direnv() {
  if command -v direnv &>/dev/null; then
    success "direnv already installed"
    return 0
  fi

  log "Installing direnv..."

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if ! command -v brew &>/dev/null; then
      warn "Homebrew not found (required for direnv on macOS)"
      return 1
    fi
    log "  Installing via Homebrew..."
    brew install direnv || return 1
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    log "  Installing via package manager..."
    if command -v apt &>/dev/null; then
      sudo apt-get update && sudo apt-get install -y direnv || return 1
    elif command -v yum &>/dev/null; then
      sudo yum install -y direnv || return 1
    elif command -v pacman &>/dev/null; then
      sudo pacman -S direnv || return 1
    else
      warn "No supported package manager found. Install direnv manually."
      return 1
    fi
  else
    warn "direnv installation not automated for $OSTYPE. Install manually from https://direnv.net/"
    return 1
  fi

  success "direnv installed successfully"
  warn "Run: direnv hook bash >> ~/.bashrc  (or ~/.zshrc for zsh)"
  return 0
}
