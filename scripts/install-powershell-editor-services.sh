#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMACS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CACHE_DIR="${EMACS_DIR}/.cache/lsp"
INSTALL_DIR="${CACHE_DIR}/powershell-editor-services"
DOWNLOAD_URL="https://github.com/PowerShell/PowerShellEditorServices/releases/latest/download/PowerShellEditorServices.zip"

for command in pwsh curl unzip; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command}" >&2
    exit 1
  fi
done

mkdir -p "${CACHE_DIR}"
TEMP_DIR="$(mktemp -d "${CACHE_DIR}/powershell-editor-services.XXXXXX")"
BACKUP_DIR="${INSTALL_DIR}.previous"
INSTALL_SUCCEEDED=0

cleanup() {
  rm -rf "${TEMP_DIR}"
  if [[ -d "${BACKUP_DIR}" ]]; then
    if [[ "${INSTALL_SUCCEEDED}" -eq 1 ]]; then
      rm -rf "${BACKUP_DIR}"
    else
      rm -rf "${INSTALL_DIR}"
      mv "${BACKUP_DIR}" "${INSTALL_DIR}"
    fi
  fi
}
trap cleanup EXIT

curl --fail --location --silent --show-error \
  "${DOWNLOAD_URL}" \
  --output "${TEMP_DIR}/PowerShellEditorServices.zip"
mkdir "${TEMP_DIR}/release"
unzip -q "${TEMP_DIR}/PowerShellEditorServices.zip" -d "${TEMP_DIR}/release"

START_SCRIPT="${TEMP_DIR}/release/PowerShellEditorServices/Start-EditorServices.ps1"
if [[ ! -f "${START_SCRIPT}" ]]; then
  printf 'Invalid PowerShell Editor Services archive: Start-EditorServices.ps1 is missing\n' >&2
  exit 1
fi

rm -rf "${BACKUP_DIR}"
if [[ -d "${INSTALL_DIR}" ]]; then
  mv "${INSTALL_DIR}" "${BACKUP_DIR}"
fi
mv "${TEMP_DIR}/release" "${INSTALL_DIR}"
INSTALL_SUCCEEDED=1

printf 'PowerShell Editor Services installed in %s\n' "${INSTALL_DIR}"
