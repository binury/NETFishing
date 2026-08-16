#!/bin/bash

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <controller-mapping-file> <game-command> [arguments...]" >&2
	exit 2
fi

CONTROLLER_MAPPING_FILE="$1"
shift

if [[ ! -r "$CONTROLLER_MAPPING_FILE" ]]; then
	echo "Controller mapping file is not readable: $CONTROLLER_MAPPING_FILE" >&2
	exit 1
fi

SDL_GAMECONTROLLERCONFIG="$(<"$CONTROLLER_MAPPING_FILE")"
if [[ "$SDL_GAMECONTROLLERCONFIG" != *,*,* ]]; then
	echo "Controller mapping file is malformed: $CONTROLLER_MAPPING_FILE" >&2
	exit 1
fi

export SDL_GAMECONTROLLERCONFIG
exec "$@"
