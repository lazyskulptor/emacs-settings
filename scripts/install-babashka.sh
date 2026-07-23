#!/usr/bin/env bash
# Install Babashka (bb) to ~/.emacs.d/.cache/tools/bb/bb
# This is a build-time dependency for clojure-lsp, not a runtime LSP binary.
# Pinned version + official SHA256 from upstream GitHub release.

set -euo pipefail

VERSION="v1.12.218"
ARCHIVE="babashka-1.12.218-macos-aarch64.tar.gz"
SHA256_ARCHIVE="5bc992f39692b707403fc322e860fc82017da7de4a84a32267abb4d50a0c5f9d"

CACHE_DIR="${HOME}/.emacs.d/.cache/tools/bb"
BINARY="${CACHE_DIR}/bb"
WORKDIR=$(mktemp -d)
trap 'rm -rf "${WORKDIR}"' EXIT

cd "${WORKDIR}"

echo "babashka: downloading ${VERSION} ..."
curl --fail --location --proto '=https' --tlsv1.2 \
  -o "${ARCHIVE}" \
  "https://github.com/babashka/babashka/releases/download/${VERSION}/${ARCHIVE}"

echo "babashka: verifying checksum ..."
echo "${SHA256_ARCHIVE}  ${ARCHIVE}" | shasum -a 256 -c -

echo "babashka: extracting ..."
tar xzf "${ARCHIVE}"

mkdir -p "${CACHE_DIR}"
mv bb "${BINARY}"
echo "babashka: installed to ${BINARY}"
echo "babashka: version $("${BINARY}" --version 2>&1 | head -1)"
