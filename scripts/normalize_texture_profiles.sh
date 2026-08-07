#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly GODOT_BIN="${GODOT_BIN:-godot}"
readonly ROOT_PATH="${1:-res://}"

readonly WORK_ROOT="$(mktemp -d -t netfishing-godot-data.XXXXXX)"
trap 'rm -rf -- "${WORK_ROOT}"' EXIT

cd "${PROJECT_ROOT}"

XDG_DATA_HOME="${WORK_ROOT}/data" \
XDG_CONFIG_HOME="${WORK_ROOT}/config" \
XDG_CACHE_HOME="${WORK_ROOT}/cache" \
${GODOT_BIN} --headless --path . \
	--script scripts/normalize_texture_imports.gd -- --apply --root "${ROOT_PATH}"
