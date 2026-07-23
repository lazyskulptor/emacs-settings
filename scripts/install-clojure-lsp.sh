#!/usr/bin/env bash
# Build clojure-lsp from upstream master source.
# The upstream default branch is `master`, not `main`.
# Source cache uses detached FETCH_HEAD to reproduce the latest commit.
# Requires: git | Clojure CLI (clojure) + JDK 11+ (runtime prerequisites)
#           ~/.emacs.d/.cache/tools/bb/bb  (build tool — bootstrap with scripts/install-babashka.sh)
# Output: ~/.emacs.d/.cache/lsp/clojure-lsp/clojure-lsp (self-contained executable)

set -euo pipefail

SOURCE_DIR="${HOME}/.emacs.d/.cache/src/clojure-lsp"
CACHE_DIR="${HOME}/.emacs.d/.cache/lsp/clojure-lsp"
BINARY="${CACHE_DIR}/clojure-lsp"
REPO_URL="https://github.com/clojure-lsp/clojure-lsp.git"
BB_BIN="${HOME}/.emacs.d/.cache/tools/bb/bb"
BUILD_LOG="${SOURCE_DIR}/build.log"

# ---- prerequisite check ----
missing=""
for cmd in git clojure java; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
if [ ! -x "${BB_BIN}" ]; then
  missing="$missing babashka (bb)"
  echo "ERROR: ${BB_BIN} not found."
  echo "  Bootstrap with: bash ~/.emacs.d/scripts/install-babashka.sh"
fi
if [ -n "$missing" ]; then
  echo "ERROR: missing prerequisites:$missing"
  echo "  git     — https://git-scm.com"
  echo "  bb      — ~/.emacs.d/scripts/install-babashka.sh"
  echo "  clojure — https://clojure.org (brew install clojure/tools/clojure)"
  echo "  java    — https://adoptium.net (JDK 11+)"
  exit 1
fi

# ---- clone or update source (detached FETCH_HEAD) ----
if [ -d "${SOURCE_DIR}/.git" ]; then
  echo "clojure-lsp: updating source at ${SOURCE_DIR} (master)..."
  git -C "${SOURCE_DIR}" fetch --depth 1 origin master
  git -C "${SOURCE_DIR}" checkout --detach FETCH_HEAD
else
  echo "clojure-lsp: cloning master to ${SOURCE_DIR}..."
  git clone --depth 1 --branch master "${REPO_URL}" "${SOURCE_DIR}"
fi

# ---- build ----
echo "clojure-lsp: building (bb prod-cli)..."
cd "${SOURCE_DIR}"

# Remove stale artifacts before build
rm -f clojure-lsp cli/target/clojure-lsp-standalone.jar

if ! "${BB_BIN}" prod-cli >"${BUILD_LOG}" 2>&1; then
  echo "ERROR: build failed. Last 50 lines of build log:"
  tail -50 "${BUILD_LOG}"
  exit 1
fi

if [ ! -x "${SOURCE_DIR}/clojure-lsp" ]; then
  echo "ERROR: build succeeded but clojure-lsp executable not found"
  exit 1
fi

# Verify version
echo "clojure-lsp: build OK, version: $("${SOURCE_DIR}/clojure-lsp" --version 2>&1 | head -1)"

# ---- install to cache ----
mkdir -p "${CACHE_DIR}"
cp "${SOURCE_DIR}/clojure-lsp" "${BINARY}"
chmod +x "${BINARY}"
echo "clojure-lsp: installed to ${BINARY}"
echo "clojure-lsp: version $("${BINARY}" --version 2>&1 | head -1)"
