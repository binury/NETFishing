#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly TEMPLATE_ROOT="${SCRIPT_DIR}/portmaster"
readonly GODOT_BIN="${GODOT_BIN:-godot}"

PACKAGE_ONLY=0
if [[ "${1:-}" == "--package-only" ]]; then
  PACKAGE_ONLY=1
  shift
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--package-only]" >&2
  exit 2
fi

readonly PROJECT_VERSION="$(
  sed -n 's/^config\/version="\([^"]*\)"/\1/p' "${PROJECT_ROOT}/project.godot"
)"
if [[ -z "${PROJECT_VERSION}" ]]; then
  echo "Could not read application/config/version from project.godot." >&2
  exit 1
fi

readonly RELEASE_TAG="v${PROJECT_VERSION}"
readonly RELEASE_ROOT="${PROJECT_ROOT}/builds/${RELEASE_TAG}"
readonly ARM64_ROOT="${RELEASE_ROOT}/linux-arm64"
readonly ARM64_EXECUTABLE="${ARM64_ROOT}/NETfishing.arm64"
readonly ARM64_PCK="${ARM64_ROOT}/NETfishing.pck"
readonly STAGE_ROOT="${RELEASE_ROOT}/portmaster-stage"
readonly GAME_ROOT="${STAGE_ROOT}/netfishing"
readonly ARCHIVE="${RELEASE_ROOT}/netfishing.zip"
readonly LEGACY_ARCHIVE="${RELEASE_ROOT}/netfishing-${RELEASE_TAG}-portmaster-arm64.zip"

readonly HEAD_COMMIT="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
readonly TAG_COMMIT="$(git -C "${PROJECT_ROOT}" rev-parse "${RELEASE_TAG}^{commit}")"
if [[ "${HEAD_COMMIT}" != "${TAG_COMMIT}" ]]; then
  echo "HEAD does not match ${RELEASE_TAG}. Refusing to package mutable source." >&2
  exit 1
fi
if [[ "${NETFISHING_ALLOW_DIRTY_RELEASE:-0}" != "1" ]]; then
  dirty_tree=0
  git -C "${PROJECT_ROOT}" diff --quiet || dirty_tree=1
  git -C "${PROJECT_ROOT}" diff --cached --quiet || dirty_tree=1
  if [[ -n "$(git -C "${PROJECT_ROOT}" status --porcelain --untracked-files=normal)" ]]; then
    dirty_tree=1
  fi
  if [[ ${dirty_tree} -ne 0 ]]; then
    echo "The repository is not clean. Refusing to build a release package." >&2
    exit 1
  fi
fi

for command_name in git file zip unzip sha256sum; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "Required command not found: ${command_name}" >&2
    exit 1
  }
done

mkdir -p -- "${ARM64_ROOT}" "${RELEASE_ROOT}"
if [[ ${PACKAGE_ONLY} -eq 0 ]]; then
  rm -f -- "${ARM64_EXECUTABLE}" "${ARM64_PCK}"
  "${GODOT_BIN}" \
    --headless \
    --path "${PROJECT_ROOT}" \
    --export-release "Linux ARM64"
fi

test -s "${ARM64_EXECUTABLE}"
test -s "${ARM64_PCK}"
file "${ARM64_EXECUTABLE}" | grep -q "ARM aarch64"

rm -rf -- "${STAGE_ROOT}"
rm -f -- "${ARCHIVE}" "${LEGACY_ARCHIVE}"
mkdir -p -- "${GAME_ROOT}/licenses"

install -m 0755 "${TEMPLATE_ROOT}/NETfishing.sh" "${STAGE_ROOT}/NETfishing.sh"
install -m 0644 "${TEMPLATE_ROOT}/port.json" "${STAGE_ROOT}/port.json"
install -m 0755 "${ARM64_EXECUTABLE}" "${GAME_ROOT}/NETfishing.aarch64"
install -m 0644 "${ARM64_PCK}" "${GAME_ROOT}/NETfishing.pck"
install -m 0644 "${TEMPLATE_ROOT}/gameinfo.xml" "${GAME_ROOT}/gameinfo.xml"
install -m 0644 "${TEMPLATE_ROOT}/screenshot.png" "${GAME_ROOT}/screenshot.png"
install -m 0644 \
  "${TEMPLATE_ROOT}/licenses/CREDITS.md" \
  "${GAME_ROOT}/licenses/CREDITS.md"
install -m 0644 \
  "${TEMPLATE_ROOT}/licenses/Tuffy-LICENSE.txt" \
  "${GAME_ROOT}/licenses/Tuffy-LICENSE.txt"

cat >"${GAME_ROOT}/BUILD-INFO.txt" <<EOF
NETfishing PortMaster ARM64 build

Project version: ${PROJECT_VERSION}
Source commit: ${TAG_COMMIT}
Engine/export template: $("${GODOT_BIN}" --version)
Architecture: AArch64
Minimum linked GLIBC symbol version: GLIBC_2.28
Rendering method: gl_compatibility

The executable and PCK were exported from the release commit listed above.
Repository working-tree changes were not included in game content.
EOF

cat >"${GAME_ROOT}/README.md" <<EOF
# NETfishing for PortMaster

This package contains NETfishing \`${RELEASE_TAG}\`, exported from Godot 4.7.1
for 64-bit ARM Linux and wrapped for PortMaster.

## Installation

Install the complete \`netfishing.zip\` archive with PortMaster or HarbourMaster.
The package requires an ARM64 device, two analog sticks, GLIBC 2.28 or newer,
and the \`weston_pkg_0.2\` runtime.

Save data and device-local configuration remain under \`netfishing/conf/\`.
See \`netfishing/licenses/\` for bundled credits and license information.
EOF

(
  cd "${STAGE_ROOT}"
  zip -qry "${ARCHIVE}" NETfishing.sh netfishing port.json
)

unzip -tq "${ARCHIVE}" >/dev/null
readonly TOP_LEVELS="$(
  unzip -Z1 "${ARCHIVE}" | cut -d/ -f1 | sort -u
)"
readonly EXPECTED_TOP_LEVELS="$(printf '%s\n' NETfishing.sh netfishing port.json)"
if [[ "${TOP_LEVELS}" != "${EXPECTED_TOP_LEVELS}" ]]; then
  echo "Unexpected PortMaster archive roots:" >&2
  printf '%s\n' "${TOP_LEVELS}" >&2
  exit 1
fi
grep -q '"version": 4' "${STAGE_ROOT}/port.json"
grep -q '"name": "netfishing.zip"' "${STAGE_ROOT}/port.json"
grep -q '^# PORTMASTER: netfishing.zip, NETfishing.sh$' \
  "${STAGE_ROOT}/NETfishing.sh"
if grep -q 'GPTOKEYB' "${STAGE_ROOT}/NETfishing.sh"; then
  echo "GPTOKEYB must not be enabled for NETfishing." >&2
  exit 1
fi
if unzip -Z1 "${ARCHIVE}" | grep -E \
  '(^|/)(conf|\.git|\.godot|logs?|saves?|identities?)(/|$)|\.(gd|tscn|blend)$' \
  >/dev/null; then
  echo "The PortMaster archive contains prohibited release content." >&2
  exit 1
fi

sha256sum "${ARCHIVE}"
echo "PortMaster package created at ${ARCHIVE}"
