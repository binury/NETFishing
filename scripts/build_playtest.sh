#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly BUILD_ROOT="${PROJECT_ROOT}/builds/v0.6.5-alpha"
readonly WINDOWS_DIR="${BUILD_ROOT}/windows-x86_64"
readonly LINUX_DIR="${BUILD_ROOT}/linux-x86_64"
readonly README_SOURCE="${PROJECT_ROOT}/playtest/README-PLAYTEST.txt"
readonly SOURCE_COMMIT="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
readonly SOURCE_URL="https://forge.makearmy.io/woofmeow/netfishing"
readonly WINDOWS_ZIP="${BUILD_ROOT}/NETfishing-v0.6.5-alpha-windows-x86_64.zip"
readonly LINUX_ZIP="${BUILD_ROOT}/NETfishing-v0.6.5-alpha-linux-x86_64.zip"
readonly GODOT_BIN="${GODOT_BIN:-godot}"

if [[ ! -f "${PROJECT_ROOT}/project.godot" ]]; then
	echo "error: project.godot was not found" >&2
	exit 1
fi

if [[ ! -f "${README_SOURCE}" ]]; then
	echo "error: playtest README was not found" >&2
	exit 1
fi

rm -rf -- "${BUILD_ROOT}"
mkdir -p -- "${WINDOWS_DIR}" "${LINUX_DIR}"

"${GODOT_BIN}" \
	--headless \
	--path "${PROJECT_ROOT}" \
	--export-release "Windows Desktop" \
	"${WINDOWS_DIR}/NETfishing.exe"

"${GODOT_BIN}" \
	--headless \
	--path "${PROJECT_ROOT}" \
	--export-release "Linux Desktop" \
	"${LINUX_DIR}/NETfishing.x86_64"

for required_file in \
	"${WINDOWS_DIR}/NETfishing.exe" \
	"${WINDOWS_DIR}/NETfishing.pck" \
	"${LINUX_DIR}/NETfishing.x86_64" \
	"${LINUX_DIR}/NETfishing.pck"; do
	if [[ ! -s "${required_file}" ]]; then
		echo "error: expected export output is missing: ${required_file}" >&2
		exit 1
	fi
done

chmod +x -- "${LINUX_DIR}/NETfishing.x86_64"
cp -- "${README_SOURCE}" "${WINDOWS_DIR}/README-PLAYTEST.txt"
cp -- "${README_SOURCE}" "${LINUX_DIR}/README-PLAYTEST.txt"

stage_licenses() {
	local destination="$1/licenses"
	mkdir -p -- "${destination}"
	install -m 0644 "${PROJECT_ROOT}/LICENSE" \
		"${destination}/GPL-3.0-or-later.txt"
	install -m 0644 "${PROJECT_ROOT}/ASSET-LICENSE.md" \
		"${destination}/NETFISHING-ASSET-LICENSE.md"
	install -m 0644 "${PROJECT_ROOT}/THIRD-PARTY-NOTICES.md" \
		"${destination}/THIRD-PARTY-NOTICES.md"
	install -m 0644 "${PROJECT_ROOT}/TRADEMARKS.md" \
		"${destination}/TRADEMARKS.md"
	install -m 0644 "${PROJECT_ROOT}/CREDITS.md" \
		"${destination}/CREDITS.md"
	install -m 0644 "${PROJECT_ROOT}/ui/fonts/Tuffy-LICENSE.txt" \
		"${destination}/Tuffy-LICENSE.txt"
	install -m 0644 "${PROJECT_ROOT}/ui/fonts/Seattle-Avenue-LICENSE.txt" \
		"${destination}/Seattle-Avenue-LICENSE.txt"
	cat >"${destination}/SOURCE-CODE.md" <<EOF
# Corresponding source

NETfishing code is licensed under GPL-3.0-or-later.

Source repository: ${SOURCE_URL}
Source revision at build time: ${SOURCE_COMMIT}

If this package includes uncommitted development changes, it must not be
publicly redistributed until the exact corresponding source is also made
available.
EOF
}

stage_licenses "${WINDOWS_DIR}"
stage_licenses "${LINUX_DIR}"

(
	cd -- "${BUILD_ROOT}"
	zip -X -q -r "$(basename -- "${WINDOWS_ZIP}")" windows-x86_64
	zip -X -q -r "$(basename -- "${LINUX_ZIP}")" linux-x86_64
	sha256sum \
		"$(basename -- "${WINDOWS_ZIP}")" \
		"$(basename -- "${LINUX_ZIP}")" \
		> SHA256SUMS
)

echo "Playtest packages created in ${BUILD_ROOT}"
