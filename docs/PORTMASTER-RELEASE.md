# PortMaster release builds

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

- `port.json` uses schema version 4 and names `netfishing.zip`.
- `NETfishing.sh` starts with `# PORTMASTER: netfishing.zip, NETfishing.sh`.
- The executable is `netfishing/NETfishing.aarch64`.
- The package declares AArch64, two analog sticks, GLIBC 2.28, and
  `weston_pkg_0.2.squashfs`.
- The launcher must not start GPTOKEYB. Godot and NETfishing's controller
  mapping manager handle controller input directly.
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
2. Confirm the installed launcher contains the canonical PortMaster header and
   does not contain `GPTOKEYB`.
3. Confirm `conf/` was not replaced or removed.
4. Launch the installed port through the normal muOS menu.
5. Verify the displayed game version and controller face-button mapping.

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
ff08aacc52bbdc95616320800da3eaee0c0ba5fafdd962bf04f9655859409764  licenses/CREDITS.md
b84fdd2c3da5db56385cdbb639795e90aa3e035c53bc3591135f18df3331451f  licenses/Tuffy-LICENSE.txt
```

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
