# NETfishing

NETfishing is a multiplayer-first fishing game built with Godot 4.7. The
current pre-alpha includes host-authoritative fishing and economy flows,
freshwater and saltwater habitats, persistent player data, social features,
customization, jobs, and a controller-aware interface.

The project is under active development. Interfaces, balance, content, and
save migrations may continue to change before a stable release.

NETfishing is developed and published by **Woofmeow**, the independent team of
co-owners publicly credited as Voyager and Endeavour.

## Installing release builds

Download and extract the archive for your platform from the official release
page, then run NETfishing from the extracted platform folder.

### macOS

Current macOS builds are not signed or notarized. macOS may block the first
launch because it cannot verify the developer. Control-click the NETfishing
application, choose **Open**, then confirm **Open**. If that option is not
available, attempt to open the application once, then use **System Settings →
Privacy & Security → Open Anyway**.

Only bypass this warning for a NETfishing build downloaded from an official
project release.

## Requirements

- Godot 4.7.x with the GL Compatibility renderer
- Linux, Windows, or an Android development environment supported by Godot
- Bash for the repository helper scripts

Open `project.godot` in Godot, or start the editor from the repository root:

```sh
godot --editor --path .
```

Run the game directly with:

```sh
godot --path .
```

## Validation

The validation scripts isolate Godot's settings and application-data roots.
Run the fast, deterministic suite before submitting a change:

```sh
scripts/run_validations.sh quick
```

Additional suites and individual commands are documented in the
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md#validation) validation section.

## Building

Export presets are maintained for Linux, Windows, and Android. Repository
scripts expect the matching Godot export templates and platform toolchains to
already be installed:

```sh
scripts/build_playtest.sh
scripts/build_android_debug.sh
```

Build outputs belong under the ignored `builds/` directory. Release builds
must follow the project's separate tagged-release checklist; these convenience
scripts do not create or publish tags.

## Project map

- `main/`: composition root and application orchestration
- `world/`: map, environment, water, and world presentation
- `player/`, `fishing/`, `fish/`: player and fishing domain
- `network/`: transport, identity, and host-authoritative services
- `inventory/`, `items/`, `economy/`, `progression/`, `jobs/`: game state
- `save/`, `settings/`: versioned persistence
- `ui/`: gameplay and menu presentation
- `tests/`: focused Godot validation scripts
- `scripts/`: build, bake, and validation entry points

All maintained project guidance starts at the
[`docs/` documentation index](docs/README.md). Architecture, content policy,
world and UI authoring, and testing are consolidated in
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## Licensing

- Project-owned software code is licensed under
  [GPL-3.0-or-later](LICENSE).
- Project-owned artwork, models, music, and other creative assets are covered
  by the [NETfishing Asset License](ASSET-LICENSE.md). It permits community
  Mods for official NETfishing software, but not use in forks, clones, or
  unrelated products.
- The NETfishing and Woofmeow names and branding are reserved as described in
  [TRADEMARKS.md](TRADEMARKS.md).
- Third-party materials retain their own terms; see the consolidated
  [credits, notices, and provenance record](docs/ATTRIBUTION.md).
- Contributions are accepted under [CONTRIBUTOR-TERMS.md](CONTRIBUTOR-TERMS.md).

Material boundaries and binary-release requirements are recorded in that same
[`docs/ATTRIBUTION.md`](docs/ATTRIBUTION.md) reference.

Copyright © 2026 Woofmeow.
