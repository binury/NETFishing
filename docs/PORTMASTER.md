# PortMaster reference

NETfishing's PortMaster release is a canonical PortMaster package, not a
version-named generic ZIP. The installer-facing archive must be named
`netfishing.zip`, and its root must contain exactly:

```text
NETfishing.sh
netfishing/
port.json
```

Do not derive a release package from an older local `portmaster-stage`
directory. The templates in `scripts/portmaster/` are authoritative.

## Release contract

- `port.json` uses schema version 4, names `netfishing.zip`, and marks the
  self-contained package ready to run.
- `NETfishing.sh` starts with `# PORTMASTER: netfishing.zip, NETfishing.sh`.
- The executable is `netfishing/NETfishing.aarch64`.
- The package declares AArch64, two analog sticks, GLIBC 2.28, and
  `weston_pkg_0.2.squashfs`.
- The launcher starts GPTOKEYB in exit-only mode without a `-c` mapping file.
  PortMaster therefore owns only its device-specific force-quit chord while
  Godot and NETfishing's controller mapping manager handle gameplay input.
- The launcher calls `pm_platform_helper` for the game executable after
  starting GPTOKEYB and calls `pm_finish` after the game exits.
- Persistent device data remains under `netfishing/conf/data`,
  `netfishing/conf/config`, and `netfishing/conf/cache`.
- The archive must not contain `conf/`, saves, identities, logs, source files,
  `.git`, or `.godot` content.
- Release downloads must publish `netfishing.zip`. A renamed versioned ZIP is
  not a substitute because HarbourMaster identifies the canonical port by
  archive name.

## Build

Run this only after the release commit and annotated `v<project-version>` tag
are pinned to the same clean `main` commit:

```bash
bash scripts/build_portmaster.sh
```

The script deletes and regenerates the Linux ARM64 export, stages the package,
validates its structure, and writes:

```text
builds/v<project-version>/netfishing.zip
```

`--package-only` is reserved for repackaging an already validated ARM64 export.
It does not rebuild game content.

## Local muOS installation

The muOS auto-install directory is:

```text
/mnt/mmc/MUOS/PortMaster/autoinstall/
```

For an explicit offline installation test, copy `netfishing.zip` to a temporary
device directory and run:

```bash
/mnt/mmc/MUOS/PortMaster/harbourmaster \
  --offline --no-check install ./netfishing.zip
```

Before upgrading an existing installation, preserve
`/mnt/mmc/ports/netfishing/conf/` on the device. After installation:

1. Confirm the installed executable and PCK hashes match the staged release.
2. Confirm the installed launcher contains the canonical PortMaster header,
   starts GPTOKEYB without a `-c` mapping file, and calls
   `pm_platform_helper` for the game executable.
3. Confirm `conf/` was not replaced or removed.
4. Launch the installed port through the normal muOS menu.
5. Verify the displayed game version and controller face-button mapping.
6. Verify PortMaster's force-quit chord exits the game. This is Start+Select on
   most devices.

Installing the public PortMaster catalog entry can still install an older
catalog build until the upstream `netfishing.zip` is updated. A local release
test must install the generated local archive explicitly.

## Template provenance

The current catalog screenshot is a 640x480 PNG copied
byte-for-byte into the package template:

```text
f24daae48f543b3a270a5aa46b5e73a31904bf0c7216d4c8a9e15a8dc48a5eed  screenshot.png
```

The remaining catalog metadata assets were copied from the installed official
`netfishing.zip` package and are intentionally preserved byte-for-byte:

```text
e2a9d132744684c67865c01eca027a8c9946b4c5a19da57c82f1af0373dc83b7  gameinfo.xml
```

The package’s `licenses/` directory is assembled from the authoritative root
licenses and trademarks, the consolidated `docs/ATTRIBUTION.md`, and the font
notices at build time. It also records the exact release tag and corresponding
GPL source commit. Do not restore stale duplicated notice templates beneath
`scripts/portmaster/`.

The original catalog porter credit, `Voyager`, remains in `port.json`.

## muOS H700 controller mapping

Godot 4.7.1 and the SDL2 utilities shipped by muOS identify the same virtual
controller differently. The PortMaster SDL2 database uses GUID
`19000000010000000100000000010000`, while Godot reports GUID
`19004ca6010000000100000000010000`. Passing the SDL2 entry unchanged leaves
most controls unmapped in Godot.

The device-verified Godot mapping is:

- A `b0`, B `b1`, Y `b2`, X `b3`
- left bumper `b4`, right bumper `b5`
- select `b6`, start `b7`, guide `b8`
- left-stick click `b9`, left trigger `b10`, right trigger `b11`, right-stick click `b12`
- D-pad `h0`; left and right sticks `a0..a3`

`scripts/portmaster/NETfishing.sh` must replace the incompatible SDL2 entry
with the Godot entry when that SDL2 GUID is selected. Do not append the two
entries with a newline: WestonPack evaluates launcher arguments through a
shell and treats the second line as a command. Pass the single selected mapping
as `SDL_GAMECONTROLLERCONFIG` in the game command after Weston initializes;
Weston sources PortMaster's control file internally and otherwise restores the
SDL2 value.

Do not pass a `.gptk` controller mapping to GPTOKEYB. Its exit-only process
must retain PortMaster's controller configuration, while the verified Godot
mapping remains scoped to the game command. This prevents duplicate or
translated gameplay events while preserving the system force-quit chord.

Do not call `Input.add_joy_mapping(..., true)` for a recognized connected muOS
controller. Updating this virtual controller after connection can stop Godot
from delivering its standardized controller events until restart.

Before shipping a PortMaster build on H700 hardware, verify all of the
following in the installed game:

- A, B, X, and Y each register independently.
- The D-pad navigates every menu direction.
- Both sticks, both bumpers, both triggers, Select, Start, L3, and R3 register.
- A single button never cancels auto-map.
- Holding both bumpers together for 1.25 seconds cancels auto-map.

## PortMaster performance profile

Every PortMaster launch defaults to the light performance profile, regardless
of device family. This reflects the low-end hardware that makes up most of the
PortMaster ecosystem and keeps the canonical package conservative by default.

The light profile passes these Godot options:

- `--single-window`
- `--disable-vsync`
- `--max-fps 30`
- `--audio-output-latency 40`

It also passes `NETFISHING_PERFORMANCE_PROFILE=light` and
`NETFISHING_LOW_END=1`. The game renders the 3D world at 50% linear resolution
with nearest-neighbor scaling, reducing 3D pixel work by 75% while the
separately rendered UI retains its canonical resolution. The light profile
also:

- disables the additional full-screen world-pixelation pass;
- replaces animated depth-aware water shaders with opaque, per-vertex water;
- disables ocean surface motion;
- disables foliage wind;
- keeps the title water and full-window menu patterns static;
- reduces rain to 128 particles simulated at 12 FPS; and
- replaces procedural sky clouds and 81 moving local cloud patches with one
  flat cloud ceiling.

The normal profile retains the full visual presentation.

To opt a capable device into the normal profile, create the persistent file
`netfishing/conf/performance_profile` containing exactly:

```text
normal
```

On a typical muOS installation, the full path is:

```text
/mnt/mmc/ports/netfishing/conf/performance_profile
```

Set the file to `light`, or remove it, to restore the default. An externally
provided `NETFISHING_PERFORMANCE_PROFILE=normal` or `light` environment value
takes precedence over the persistent file. Invalid values safely fall back to
the light profile and are reported in `netfishing/log.txt`.

Do not use Godot's low processor mode for the light profile. It reduces idle
CPU usage by sleeping between updates and is not a game-performance
optimization.
