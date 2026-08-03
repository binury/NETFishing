#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly OUTPUT_PATH="${PROJECT_ROOT}/builds/android/NETfishing-debug.apk"
readonly GODOT_BIN="${GODOT_BIN:-godot}"

mkdir -p -- "$(dirname -- "${OUTPUT_PATH}")"

"${GODOT_BIN}" \
  --headless \
  --path "${PROJECT_ROOT}" \
  --export-debug "Android" \
  "${OUTPUT_PATH}"

test -s "${OUTPUT_PATH}"
sha256sum "${OUTPUT_PATH}"
