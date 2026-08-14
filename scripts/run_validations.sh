#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly GODOT_BIN="${GODOT_BIN:-godot}"
readonly TEST_TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-120}"
readonly RUN_ROOT="$(mktemp -d -t netfishing-validations.XXXXXX)"

readonly -a QUICK_TESTS=(
	"tests/android_readiness_validation.gd"
	"tests/dedicated_server_config_validation.gd"
	"tests/fish_catalog_content_validation.gd"
	"tests/fish_quality_validation.gd"
	"tests/fishing_audio_validation.gd"
	"tests/fishing_surface_validation.gd"
	"tests/fur_pattern_validation.gd"
	"tests/logbook_validation.gd"
	"tests/network_player_animation_protocol_validation.gd"
	"tests/player_experience_validation.gd"
	"tests/shoreline_ambience_validation.gd"
	"tests/surface_drawing_validation.gd"
	"tests/terrain_blender_material_validation.gd"
	"tests/texture_sampling_validation.gd"
	"tests/world_time_validation.gd"
	"tests/world_weather_validation.gd"
)

readonly -a RUNTIME_TESTS=(
	"tests/inventory_notepad_art_validation.gd"
	"tests/logbook_runtime_validation.gd"
	"tests/player_experience_ui_validation.gd"
	"tests/title_credits_validation.gd"
	"tests/ui_scaling_runtime_validation.gd"
)

readonly -a HOST_TESTS=(
	"tests/art_tools_validation.gd"
	"tests/dedicated_host_session_validation.gd"
	"tests/economy_regression_validation.gd"
	"tests/fish_hotbar_showcase_validation.gd"
	"tests/fishing_authority_validation.gd"
	"tests/job_system_validation.gd"
	"tests/surface_drawing_runtime_validation.gd"
)

readonly -a NETWORK_TESTS=(
	"tests/economy_regression_validation.gd"
	"tests/fish_showcase_multiplayer_validation.gd"
	"tests/fishing_multiplayer_validation.gd"
	"tests/job_multiplayer_validation.gd"
	"tests/movement_multiplayer_validation.gd"
	"tests/operator_multiplayer_validation.gd"
	"tests/surface_drawing_multiplayer_validation.gd"
	"tests/world_time_multiplayer_validation.gd"
)

cleanup() {
	rm -rf -- "${RUN_ROOT}"
}
trap cleanup EXIT INT TERM

usage() {
	printf 'Usage: %s {quick|full|host|network|all|--list}\n' "$0"
}

prepare_root() {
	local name="$1"
	local root="${RUN_ROOT}/${name}"
	mkdir -p -- "${root}/data" "${root}/config" "${root}/cache"
	printf '%s\n' "${root}"
}

run_test() {
	local script="$1"
	local name="${script#tests/}"
	name="${name%.gd}"
	local root
	root="$(prepare_root "${name}")"
	printf '\n==> %s\n' "${script}"
	XDG_DATA_HOME="${root}/data" \
	XDG_CONFIG_HOME="${root}/config" \
	XDG_CACHE_HOME="${root}/cache" \
	timeout "${TEST_TIMEOUT_SECONDS}s" "${GODOT_BIN}" \
		--headless --path "${PROJECT_ROOT}" --script "${script}"
}


wait_for_network_host() {
	local script="$1"
	local host_pid="$2"
	local test_port="7777"
	local declared_port
	declared_port="$(
		sed -n -E \
			's/^const TEST_PORT(: int)? = ([0-9]+)$/\2/p' \
			"${PROJECT_ROOT}/${script}"
	)"
	if [[ -n "${declared_port}" ]]; then
		test_port="${declared_port}"
	fi
	if ! command -v ss >/dev/null 2>&1; then
		sleep 2
		return 0
	fi
	for _attempt in {1..100}; do
		if ! kill -0 "${host_pid}" 2>/dev/null; then
			return 1
		fi
		if ss -H -lun "sport = :${test_port}" | grep -q .; then
			return 0
		fi
		sleep 0.1
	done
	return 1
}


run_network_test() {
	local script="$1"
	local name="${script#tests/}"
	name="${name%.gd}"
	local host_root client_root host_pid host_status client_status
	host_root="$(prepare_root "${name}-host")"
	client_root="$(prepare_root "${name}-client")"
	printf '\n==> %s (host + client)\n' "${script}"
	XDG_DATA_HOME="${host_root}/data" \
	XDG_CONFIG_HOME="${host_root}/config" \
	XDG_CACHE_HOME="${host_root}/cache" \
	timeout "${TEST_TIMEOUT_SECONDS}s" "${GODOT_BIN}" \
		--headless --path "${PROJECT_ROOT}" --script "${script}" -- host \
		>"${host_root}/output.log" 2>&1 &
	host_pid=$!
	if ! wait_for_network_host "${script}" "${host_pid}"; then
		set +e
		wait "${host_pid}"
		host_status=$?
		set -e
		printf '%s\n' '-- host output --'
		sed -n '1,240p' "${host_root}/output.log"
		printf 'error: host did not become ready (exit %d)\n' \
			"${host_status}" >&2
		return 1
	fi
	set +e
	XDG_DATA_HOME="${client_root}/data" \
	XDG_CONFIG_HOME="${client_root}/config" \
	XDG_CACHE_HOME="${client_root}/cache" \
	timeout "${TEST_TIMEOUT_SECONDS}s" "${GODOT_BIN}" \
		--headless --path "${PROJECT_ROOT}" --script "${script}" -- client \
		>"${client_root}/output.log" 2>&1
	client_status=$?
	wait "${host_pid}"
	host_status=$?
	set -e
	printf '%s\n' '-- host output --'
	sed -n '1,240p' "${host_root}/output.log"
	printf '%s\n' '-- client output --'
	sed -n '1,240p' "${client_root}/output.log"
	if ((host_status != 0 || client_status != 0)); then
		printf 'error: host exited %d; client exited %d\n' \
			"${host_status}" "${client_status}" >&2
		return 1
	fi
}

run_quick() {
	local test_script
	for test_script in "${QUICK_TESTS[@]}"; do
		run_test "${test_script}"
	done
}

run_full() {
	local test_script
	run_quick
	for test_script in "${RUNTIME_TESTS[@]}"; do
		run_test "${test_script}"
	done
}

run_host() {
	local test_script
	for test_script in "${HOST_TESTS[@]}"; do
		run_test "${test_script}"
	done
}

run_network() {
	local test_script
	for test_script in "${NETWORK_TESTS[@]}"; do
		run_network_test "${test_script}"
	done
}

list_tests() {
	printf '%s\n' 'Quick tests:'
	printf '  %s\n' "${QUICK_TESTS[@]}"
	printf '%s\n' 'Additional full-suite tests:'
	printf '  %s\n' "${RUNTIME_TESTS[@]}"
	printf '%s\n' 'Single-process tests requiring a local UDP bind:'
	printf '  %s\n' "${HOST_TESTS[@]}"
	printf '%s\n' 'Paired network tests:'
	printf '  %s\n' "${NETWORK_TESTS[@]}"
}

case "${1:-}" in
	quick)
		run_quick
		;;
	full)
		run_full
		;;
	host)
		run_host
		;;
	network)
		run_network
		;;
	all)
		run_full
		run_host
		run_network
		;;
	--list)
		list_tests
		;;
	*)
		usage >&2
		exit 2
		;;
esac

printf '\nAll requested validations passed.\n'
