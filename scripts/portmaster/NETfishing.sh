#!/bin/bash
# PORTMASTER: netfishing.zip, NETfishing.sh

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
	controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
	controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
	controlfolder="$XDG_DATA_HOME/PortMaster"
else
	controlfolder="/roms/ports/PortMaster"
fi

if [ ! -f "$controlfolder/control.txt" ]; then
	echo "PortMaster control.txt was not found at $controlfolder" >&2
	exit 1
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/${directory}/ports/netfishing"
if [ ! -d "$GAMEDIR" ] && [ -d "/mnt/mmc/ports/netfishing" ]; then
	GAMEDIR="/mnt/mmc/ports/netfishing"
fi

CONFDIR="$GAMEDIR/conf"
GAME_EXECUTABLE="$GAMEDIR/NETfishing.aarch64"
WESTON_DIR="/tmp/netfishing-weston"
WESTON_RUNTIME="weston_pkg_0.2"
HARBOURMASTER="$controlfolder/harbourmaster"
if [ ! -x "$HARBOURMASTER" ] && [ -x "/mnt/mmc/MUOS/PortMaster/harbourmaster" ]; then
	HARBOURMASTER="/mnt/mmc/MUOS/PortMaster/harbourmaster"
fi

mkdir -p "$CONFDIR/data" "$CONFDIR/config" "$CONFDIR/cache" "$WESTON_DIR"
chmod +x "$GAME_EXECUTABLE"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

if [ ! -f "$controlfolder/libs/${WESTON_RUNTIME}.squashfs" ]; then
	if [ ! -x "$HARBOURMASTER" ]; then
		pm_message "NETfishing requires the latest PortMaster and WestonPack runtime."
		sleep 5
		exit 1
	fi
	$ESUDO "$HARBOURMASTER" --quiet --no-check runtime_check "${WESTON_RUNTIME}.squashfs"
fi

if [ ! -f "$controlfolder/libs/${WESTON_RUNTIME}.squashfs" ]; then
	pm_message "WestonPack could not be installed. Check the network connection and PortMaster runtime manager."
	sleep 5
	exit 1
fi

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
	$ESUDO umount "$WESTON_DIR" 2>/dev/null
fi
$ESUDO mount "$controlfolder/libs/${WESTON_RUNTIME}.squashfs" "$WESTON_DIR"

cd "$GAMEDIR" || exit 1

# Godot 4.7 identifies the muOS H700 virtual controller with a CRC-bearing
# GUID and numbers its buttons without the volume keys exposed by SDL2. The
# PortMaster SDL2 database entry therefore cannot drive Godot's gamepad layer.
GODOT_MUOS_MAPPING="19004ca6010000000100000000010000,muOS-Keys,a:b0,b:b1,x:b3,y:b2,leftshoulder:b4,rightshoulder:b5,lefttrigger:b10,righttrigger:b11,guide:b8,start:b7,back:b6,dpup:h0.1,dpleft:h0.8,dpright:h0.2,dpdown:h0.4,leftx:a0,lefty:a1,leftstick:b9,rightx:a2,righty:a3,rightstick:b12,platform:Linux,"
MUOS_SDL2_GUID="19000000010000000100000000010000"
if [[ "$sdl_controllerconfig" == "${MUOS_SDL2_GUID},"* ]]; then
	netfishing_controllerconfig="$GODOT_MUOS_MAPPING"
elif [ -n "$sdl_controllerconfig" ]; then
	netfishing_controllerconfig="$sdl_controllerconfig"
else
	netfishing_controllerconfig="$GODOT_MUOS_MAPPING"
fi

NETFISHING_GODOT_OPTIONS=()
NETFISHING_GAME_ENVIRONMENT=()
PERFORMANCE_PROFILE="${NETFISHING_PERFORMANCE_PROFILE:-}"
PROFILE_PATH="$CONFDIR/performance_profile"
if [[ -z "$PERFORMANCE_PROFILE" && -r "$PROFILE_PATH" ]]; then
	IFS= read -r PERFORMANCE_PROFILE < "$PROFILE_PATH" || true
	PERFORMANCE_PROFILE="${PERFORMANCE_PROFILE%$'\r'}"
fi
case "$PERFORMANCE_PROFILE" in
	normal)
		NETFISHING_GAME_ENVIRONMENT+=(
			"NETFISHING_PERFORMANCE_PROFILE=normal"
		)
		;;
	light|"")
		NETFISHING_GAME_ENVIRONMENT+=(
			"NETFISHING_PERFORMANCE_PROFILE=light"
			"NETFISHING_LOW_END=1"
		)
		NETFISHING_GODOT_OPTIONS+=(
			--single-window
			--disable-vsync
			--max-fps 30
			--audio-output-latency 40
		)
		;;
	*)
		echo "Unknown performance profile '$PERFORMANCE_PROFILE'; using light." >&2
		NETFISHING_GAME_ENVIRONMENT+=(
			"NETFISHING_PERFORMANCE_PROFILE=light"
			"NETFISHING_LOW_END=1"
		)
		NETFISHING_GODOT_OPTIONS+=(
			--single-window
			--disable-vsync
			--max-fps 30
			--audio-output-latency 40
		)
		;;
esac

# Keep NETfishing's native controller input separate from PortMaster's exit
# handling. Without a -c mapping file, GPTOKEYB only watches for the
# device-specific force-quit chord and does not inject gameplay inputs.
$GPTOKEYB "NETfishing.aarch64" &
pm_platform_helper "$GAME_EXECUTABLE"

$ESUDO env CRUSTY_RESOLUTION="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" \
	"$WESTON_DIR/westonwrap.sh" headless noop kiosk crusty_x11egl \
	XDG_DATA_HOME="$CONFDIR/data" \
	XDG_CONFIG_HOME="$CONFDIR/config" \
	XDG_CACHE_HOME="$CONFDIR/cache" \
	SDL_GAMECONTROLLERCONFIG="$netfishing_controllerconfig" \
	GODOT_SILENCE_ROOT_WARNING=1 \
	"${NETFISHING_GAME_ENVIRONMENT[@]}" \
	"$GAME_EXECUTABLE" \
	"${NETFISHING_GODOT_OPTIONS[@]}" \
	--resolution "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" \
	--fullscreen \
	--rendering-driver opengl3_es \
	--audio-driver ALSA

$ESUDO "$WESTON_DIR/westonwrap.sh" cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
	$ESUDO umount "$WESTON_DIR" 2>/dev/null
fi
pm_finish
