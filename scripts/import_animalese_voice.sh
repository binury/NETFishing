#!/usr/bin/env bash
set -euo pipefail

readonly TARGET_RMS_DBFS="-18.0"
readonly PEAK_CEILING_DBFS="-3.0"
readonly OUTPUT_SAMPLE_RATE="48000"

usage() {
	printf 'usage: %s SOURCE_DIRECTORY SAMPLE_SET_DIRECTORY\n' "$0" >&2
	printf 'example: %s /path/to/voice_clips custom_voice\n' "$0" >&2
}

if (( $# != 2 )); then
	usage
	exit 2
fi

if ! command -v sox >/dev/null 2>&1; then
	printf 'error: sox is required to import animalese samples\n' >&2
	exit 1
fi

readonly SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "$SCRIPT_DIRECTORY/.." && pwd)"
readonly SOURCE_DIRECTORY="$(realpath -e -- "$1")"
readonly SAMPLE_SET_DIRECTORY="$2"

if [[ ! -d "$SOURCE_DIRECTORY" ]]; then
	printf 'error: source is not a directory: %s\n' "$SOURCE_DIRECTORY" >&2
	exit 1
fi
if [[ ! "$SAMPLE_SET_DIRECTORY" =~ ^[a-z0-9_-]+$ ]]; then
	printf 'error: sample-set directory must use lowercase letters, numbers, underscores, or hyphens\n' >&2
	exit 1
fi

readonly DESTINATION_DIRECTORY="$PROJECT_ROOT/sound/dialogue/animalese/$SAMPLE_SET_DIRECTORY"
readonly WORK_DIRECTORY="$(mktemp -d -t netfishing-animalese-import.XXXXXX)"

cleanup() {
	if [[ "$WORK_DIRECTORY" == /tmp/netfishing-animalese-import.* ]]; then
		find "$WORK_DIRECTORY" -depth -delete
	fi
}
trap cleanup EXIT

mkdir -p -- "$WORK_DIRECTORY/converted" "$WORK_DIRECTORY/normalized"
mapfile -d '' SOURCE_FILES < <(
	find "$SOURCE_DIRECTORY" -maxdepth 1 -type f -name '*.wav' -print0 \
		| sort -z
)
if (( ${#SOURCE_FILES[@]} == 0 )); then
	printf 'error: no .wav samples found in %s\n' "$SOURCE_DIRECTORY" >&2
	exit 1
fi

for source_file in "${SOURCE_FILES[@]}"; do
	filename="$(basename -- "$source_file")"
	if [[ ! "$filename" =~ ^[a-z0-9_]+\.wav$ ]]; then
		printf 'error: unsupported sample filename: %s\n' "$filename" >&2
		exit 1
	fi
	converted_file="$WORK_DIRECTORY/converted/$filename"
	normalized_file="$WORK_DIRECTORY/normalized/$filename"

	# Measure the exact channel/rate conversion that will be shipped, then use
	# the smaller of the RMS correction and peak-safe gain. Very short voice
	# clips are not reliable inputs for program-loudness algorithms such as
	# EBU R128, so this deterministic RMS/peak policy is intentional.
	# Reserve headroom before high-quality resampling. Several supplied 8-bit
	# clips sit near full scale and their interpolated waveform can otherwise
	# clip before the normalization gain is calculated.
	sox -D "$source_file" \
		-r "$OUTPUT_SAMPLE_RATE" -c 1 -b 32 -e floating-point \
		"$converted_file" gain -6 rate -v "$OUTPUT_SAMPLE_RATE"
	statistics="$(sox "$converted_file" -n stat 2>&1)"
	peak_amplitude="$(awk '/Maximum amplitude/ {print $3}' <<< "$statistics")"
	rms_amplitude="$(awk '/RMS.*amplitude/ {print $3; exit}' <<< "$statistics")"
	if ! awk -v peak="$peak_amplitude" -v rms="$rms_amplitude" \
		'BEGIN {exit !(peak > 0.0 && rms > 0.0)}'; then
		printf 'error: sample is silent or unreadable: %s\n' "$source_file" >&2
		exit 1
	fi

	gain_db="$(
		awk \
			-v peak="$peak_amplitude" \
			-v rms="$rms_amplitude" \
			-v target_rms="$TARGET_RMS_DBFS" \
			-v peak_ceiling="$PEAK_CEILING_DBFS" \
			'BEGIN {
				peak_db = 20.0 * log(peak) / log(10.0)
				rms_db = 20.0 * log(rms) / log(10.0)
				rms_gain = target_rms - rms_db
				peak_gain = peak_ceiling - peak_db
				gain = rms_gain < peak_gain ? rms_gain : peak_gain
				printf "%.6f", gain
			}'
	)"
	sox -D "$converted_file" \
		-r "$OUTPUT_SAMPLE_RATE" -c 1 -b 16 -e signed-integer \
		"$normalized_file" gain "$gain_db"
	printf '%-16s %8s dB\n' "$filename" "$gain_db"
done

mkdir -p -- "$DESTINATION_DIRECTORY"
for normalized_file in "$WORK_DIRECTORY"/normalized/*.wav; do
	cp -- "$normalized_file" "$DESTINATION_DIRECTORY/$(basename -- "$normalized_file")"
done

printf 'imported %d normalized samples to %s\n' \
	"${#SOURCE_FILES[@]}" "$DESTINATION_DIRECTORY"
