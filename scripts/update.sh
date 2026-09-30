#!/bin/bash
# Update Emacs config: git pull + uv sync + npm update

set -e

EMACS_DIR="${1:-.}"

echo "Updating Emacs configuration..."
echo ""

# ── Git pull ────────────────────────────────────────────────────

echo "1. Pulling git changes..."
if git -C "$EMACS_DIR" pull; then
  echo "   ✓ Git pull successful"
else
  echo "   ✗ Git pull failed"
  exit 1
fi
echo ""

# ── Python dependencies ─────────────────────────────────────────

echo "2. Updating Python dependencies..."
if uv sync --directory "$EMACS_DIR" --upgrade; then
  echo "   ✓ Python dependencies updated"
else
  echo "   ✗ Python update failed"
  exit 1
fi
echo ""

# ── npm dependencies ────────────────────────────────────────────

echo "3. Updating npm dependencies..."
if npm update --prefix "$EMACS_DIR"; then
  echo "   ✓ npm dependencies updated"
else
  echo "   ✗ npm update failed (continuing anyway...)"
fi
echo ""

echo "Dependencies updated. Rebuilding packages..."
