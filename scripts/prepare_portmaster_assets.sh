#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: scripts/prepare_portmaster_assets.sh <temporary-project-root>" >&2
	exit 2
fi

readonly PROJECT_ROOT="$1"
readonly GENERAL_TEXTURE_LIMIT=128
readonly GAMEPLAY_TEXTURE_LIMIT=64
readonly AUDIO_SAMPLE_RATE=22050

if [[ ! -f "${PROJECT_ROOT}/project.godot" ]]; then
	echo "PortMaster asset project is missing project.godot: ${PROJECT_ROOT}" >&2
	exit 1
fi

limit_texture_imports() {
	local asset_root="$1"
	local size_limit="$2"
	local import_file
	local updated=0

	if [[ ! -d "${asset_root}" ]]; then
		return
	fi
	while IFS= read -r -d '' import_file; do
		if ! grep -q '^importer="texture"$' "${import_file}"; then
			continue
	fi
		if ! grep -q '^process/size_limit=' "${import_file}"; then
			continue
	fi
		sed -i \
			-e 's|^compress/mode=.*$|compress/mode=2|' \
			-e "s|^process/size_limit=.*$|process/size_limit=${size_limit}|" \
			"${import_file}"
		updated=$((updated + 1))
	done < <(find "${asset_root}" -type f -name '*.import' -print0)
	printf 'PortMaster texture limit %d px: %d imports under %s\n' \
		"${size_limit}" "${updated}" "${asset_root#${PROJECT_ROOT}/}"
}


configure_audio_imports() {
	local asset_root="$1"
	local import_file
	local updated=0

	if [[ ! -d "${asset_root}" ]]; then
		return
	fi
	while IFS= read -r -d '' import_file; do
		if ! grep -q '^importer="wav"$' "${import_file}"; then
			continue
		fi
		sed -i \
			-e 's|^force/mono=.*$|force/mono=true|' \
			-e 's|^force/max_rate=.*$|force/max_rate=true|' \
			-e "s|^force/max_rate_hz=.*$|force/max_rate_hz=${AUDIO_SAMPLE_RATE}|" \
			-e 's|^compress/mode=.*$|compress/mode=2|' \
			"${import_file}"
		updated=$((updated + 1))
	done < <(find "${asset_root}" -type f -name '*.wav.import' -print0)
	printf 'PortMaster audio profile %d Hz mono: %d imports under %s\n' \
		"${AUDIO_SAMPLE_RATE}" "${updated}" \
		"${asset_root#${PROJECT_ROOT}/}"
}

# The entire PortMaster project uses a deliberately small, VRAM-compressed
# texture ceiling. Fonts are unaffected, preserving readable interface text
# while raster artwork is reduced for one-gigabyte shared-memory devices.
limit_texture_imports "${PROJECT_ROOT}" "${GENERAL_TEXTURE_LIMIT}"

# These catalogs contain most of the authored high-resolution textures and
# account for the largest runtime residency. At a 640x480 output, 64 pixels
# remains sufficient for the deliberately low-fidelity light profile.
for gameplay_root in \
	"art/exported/characters" \
	"art/exported/environment" \
	"art/exported/items" \
	"fish/species" \
	"gathering" \
	"items/icons" \
	"world"; do
	limit_texture_imports \
		"${PROJECT_ROOT}/${gameplay_root}" \
		"${GAMEPLAY_TEXTURE_LIMIT}"
done

# Short speech, call, and gameplay effects remain available, but use a small
# mono QOA representation to reduce both package and resident sample memory.
configure_audio_imports "${PROJECT_ROOT}/audio/sfx"
configure_audio_imports "${PROJECT_ROOT}/sound/dialogue"
