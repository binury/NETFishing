#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly GODOT_BIN="${GODOT_BIN:-godot}"

if [[ $# -ne 1 ]]; then
	echo "usage: scripts/normalize_texture_profiles.sh res://path/to/textures" >&2
	exit 2
fi

readonly ROOT_PATH="$1"

readonly WORK_ROOT="$(mktemp -d -t netfishing-godot-data.XXXXXX)"
trap 'rm -rf -- "${WORK_ROOT}"' EXIT

cd "${PROJECT_ROOT}"

export XDG_DATA_HOME="${WORK_ROOT}/data"
export XDG_CONFIG_HOME="${WORK_ROOT}/config"
export XDG_CACHE_HOME="${WORK_ROOT}/cache"

"${GODOT_BIN}" --headless --path . \
		--script scripts/normalize_texture_imports.gd -- --apply --root "${ROOT_PATH}"

# Synchronize Godot-generated remap and destination metadata with the updated
# import parameters before the caller reviews or commits the sidecars.
"${GODOT_BIN}" --headless --path . --import
