#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly TEMPLATE_ROOT="${SCRIPT_DIR}/portmaster"
readonly GODOT_BIN="${GODOT_BIN:-godot}"

PACKAGE_ONLY=0
HOTFIX=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-only)
      PACKAGE_ONLY=1
      ;;
    --hotfix)
      HOTFIX=1
      ;;
    *)
      echo "Usage: $0 [--package-only] [--hotfix]" >&2
      exit 2
      ;;
  esac
  shift
done
if [[ ${HOTFIX} -eq 1 && ${PACKAGE_ONLY} -ne 1 ]]; then
  echo "PortMaster hotfixes must use an existing pinned ARM64 export." >&2
  echo "Run this script with both --package-only and --hotfix." >&2
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
readonly OBSOLETE_VERSIONED_ARCHIVE="${RELEASE_ROOT}/NETfishing-${RELEASE_TAG}-portmaster-arm64.zip"
readonly OBSOLETE_LOWERCASE_ARCHIVE="${RELEASE_ROOT}/netfishing-${RELEASE_TAG}-portmaster-arm64.zip"

readonly HEAD_COMMIT="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
readonly TAG_COMMIT="$(git -C "${PROJECT_ROOT}" rev-parse "${RELEASE_TAG}^{commit}")"
if [[ ${HOTFIX} -eq 1 ]]; then
  if ! git -C "${PROJECT_ROOT}" merge-base --is-ancestor \
    "${TAG_COMMIT}" "${HEAD_COMMIT}"; then
    echo "${RELEASE_TAG} is not an ancestor of HEAD. Refusing hotfix package." >&2
    exit 1
  fi

  while IFS= read -r changed_path; do
    case "${changed_path}" in
      docs/PORTMASTER.md|scripts/build_portmaster.sh|scripts/portmaster/*)
        ;;
      *)
        echo "Hotfix contains a non-PortMaster change: ${changed_path}" >&2
        exit 1
        ;;
    esac
  done < <(git -C "${PROJECT_ROOT}" diff --name-only \
    "${TAG_COMMIT}..${HEAD_COMMIT}")
elif [[ "${HEAD_COMMIT}" != "${TAG_COMMIT}" ]]; then
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
rm -f -- \
  "${ARCHIVE}" \
  "${OBSOLETE_VERSIONED_ARCHIVE}" \
  "${OBSOLETE_LOWERCASE_ARCHIVE}"
mkdir -p -- "${GAME_ROOT}/licenses"

install -m 0755 "${TEMPLATE_ROOT}/NETfishing.sh" "${STAGE_ROOT}/NETfishing.sh"
install -m 0644 "${TEMPLATE_ROOT}/port.json" "${GAME_ROOT}/port.json"
install -m 0644 "${TEMPLATE_ROOT}/netfishing.gptk" \
  "${GAME_ROOT}/netfishing.gptk"
install -m 0755 "${TEMPLATE_ROOT}/launch-netfishing.sh" \
  "${GAME_ROOT}/launch-netfishing.sh"
install -m 0755 "${ARM64_EXECUTABLE}" "${GAME_ROOT}/NETfishing.aarch64"
install -m 0644 "${ARM64_PCK}" "${GAME_ROOT}/NETfishing.pck"
install -m 0644 "${TEMPLATE_ROOT}/gameinfo.xml" "${GAME_ROOT}/gameinfo.xml"
install -m 0644 "${TEMPLATE_ROOT}/screenshot.png" "${GAME_ROOT}/screenshot.png"
install -m 0644 \
  "${PROJECT_ROOT}/docs/ATTRIBUTION.md" \
  "${GAME_ROOT}/licenses/ATTRIBUTION.md"
install -m 0644 \
  "${PROJECT_ROOT}/LICENSE" \
  "${GAME_ROOT}/licenses/GPL-3.0-or-later.txt"
install -m 0644 \
  "${PROJECT_ROOT}/ASSET-LICENSE.md" \
  "${GAME_ROOT}/licenses/NETFISHING-ASSET-LICENSE.md"
install -m 0644 \
  "${PROJECT_ROOT}/TRADEMARKS.md" \
  "${GAME_ROOT}/licenses/TRADEMARKS.md"
install -m 0644 \
  "${PROJECT_ROOT}/ui/fonts/Tuffy-LICENSE.txt" \
  "${GAME_ROOT}/licenses/Tuffy-LICENSE.txt"
install -m 0644 \
  "${PROJECT_ROOT}/ui/fonts/Seattle-Avenue-LICENSE.txt" \
  "${GAME_ROOT}/licenses/Seattle-Avenue-LICENSE.txt"

cat >"${GAME_ROOT}/BUILD-INFO.txt" <<EOF
NETfishing PortMaster ARM64 build

Project version: ${PROJECT_VERSION}
Game source commit: ${TAG_COMMIT}
Packaging source commit: ${HEAD_COMMIT}
Packaging mode: $([[ ${HOTFIX} -eq 1 ]] && printf 'PortMaster hotfix' || printf 'release')
Engine/export template: $("${GODOT_BIN}" --version)
Architecture: AArch64
Minimum linked GLIBC symbol version: GLIBC_2.28
Rendering method: gl_compatibility

The executable and PCK were exported from the release commit listed above.
Repository working-tree changes were not included in game content.
EOF

cat >"${GAME_ROOT}/licenses/SOURCE-CODE.md" <<EOF
# Corresponding source

NETfishing code is licensed under GPL-3.0-or-later.

Source repository: https://forge.makearmy.io/woofmeow/netfishing
Exact source revision: ${TAG_COMMIT}
Release tag: ${RELEASE_TAG}
PortMaster packaging revision: ${HEAD_COMMIT}
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
PortMaster launches use the light performance profile by default. Put the word
\`normal\` in \`netfishing/conf/performance_profile\` to opt a capable device
into the normal rendering profile. See \`netfishing/licenses/\` for bundled
credits and license information.

## Controls

NETfishing reads the handheld controller directly. PortMaster's system
force-quit chord remains available; this is Start+Select on most devices.
EOF

(
  cd "${STAGE_ROOT}"
  zip -qry "${ARCHIVE}" NETfishing.sh netfishing
)

unzip -tq "${ARCHIVE}" >/dev/null
readonly TOP_LEVELS="$(
  unzip -Z1 "${ARCHIVE}" | cut -d/ -f1 | sort -u
)"
readonly EXPECTED_TOP_LEVELS="$(printf '%s\n' NETfishing.sh netfishing)"
if [[ "${TOP_LEVELS}" != "${EXPECTED_TOP_LEVELS}" ]]; then
  echo "Unexpected PortMaster archive roots:" >&2
  printf '%s\n' "${TOP_LEVELS}" >&2
  exit 1
fi
grep -q '"version": 4' "${GAME_ROOT}/port.json"
grep -q '"name": "netfishing.zip"' "${GAME_ROOT}/port.json"
grep -q '"rtr": true' "${GAME_ROOT}/port.json"
if unzip -Z1 "${ARCHIVE}" | grep -qx 'port.json'; then
  echo "port.json must be inside netfishing/, not at the archive root." >&2
  exit 1
fi
grep -q '^# PORTMASTER: netfishing.zip, NETfishing.sh$' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq 'PROFILE_PATH="$CONFDIR/performance_profile"' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq 'NETFISHING_PERFORMANCE_PROFILE=light' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq 'CONTROLLER_MAPPING_FILE="$CONFDIR/cache/controller_mapping.txt"' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq 'printf '\''%s\n'\'' "$netfishing_controllerconfig" > "$CONTROLLER_MAPPING_FILE"' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq '"$GAME_LAUNCHER"' "${STAGE_ROOT}/NETfishing.sh"
grep -Fq '"$CONTROLLER_MAPPING_FILE"' "${STAGE_ROOT}/NETfishing.sh"
if grep -Fq 'SDL_GAMECONTROLLERCONFIG="$netfishing_controllerconfig"' \
  "${STAGE_ROOT}/NETfishing.sh"; then
  echo "Raw controller mappings must not be passed through westonwrap.sh." >&2
  exit 1
fi
grep -Fq 'SDL_GAMECONTROLLERCONFIG="$(<"$CONTROLLER_MAPPING_FILE")"' \
  "${GAME_ROOT}/launch-netfishing.sh"
grep -Fq 'export SDL_GAMECONTROLLERCONFIG' \
  "${GAME_ROOT}/launch-netfishing.sh"
grep -Fq 'exec "$@"' "${GAME_ROOT}/launch-netfishing.sh"
grep -Fq 'GPTOKEYB_CONFIG="$GAMEDIR/netfishing.gptk"' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq '$GPTOKEYB "NETfishing.aarch64" -c "$GPTOKEYB_CONFIG" &' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq 'pm_platform_helper "$GAME_EXECUTABLE"' \
  "${STAGE_ROOT}/NETfishing.sh"
grep -Fq 'pm_finish' "${STAGE_ROOT}/NETfishing.sh"
if [[ "$(grep -Ec '^[[:space:]]*\$GPTOKEYB[[:space:]]' \
  "${STAGE_ROOT}/NETfishing.sh")" -ne 1 ]]; then
  echo "NETfishing must start exactly one GPTOKEYB exit handler." >&2
  exit 1
fi
readonly GPTOKEYB_NOOP_KEYS=(
  back guide start
  a a_hk b b_hk x x_hk y y_hk
  l1 l1_hk l2 l2_hk l3 r1 r1_hk r2 r2_hk r3
  up down left right
  left_analog_up left_analog_down left_analog_left left_analog_right
  right_analog_up right_analog_down right_analog_left right_analog_right
)
for noop_key in "${GPTOKEYB_NOOP_KEYS[@]}"; do
  if ! grep -Eq \
    "^[[:space:]]*${noop_key}[[:space:]]*=[[:space:]]*\\\\\"[[:space:]]*$" \
    "${GAME_ROOT}/netfishing.gptk"; then
    echo "GPTOKEYB no-op mapping is missing: ${noop_key}" >&2
    exit 1
  fi
done
if [[ "$(grep -Ec '^[[:space:]]*[a-z0-9_]+[[:space:]]*=' \
  "${GAME_ROOT}/netfishing.gptk")" -ne "${#GPTOKEYB_NOOP_KEYS[@]}" ]]; then
  echo "GPTOKEYB no-op mapping contains an unexpected assignment." >&2
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
