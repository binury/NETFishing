# NETfishing

NETfishing is a multiplayer-first fishing game built with Godot 4.7. The
current pre-alpha includes host-authoritative fishing and economy flows,
freshwater and saltwater habitats, persistent player data, social features,
customization, jobs, and a controller-aware interface.

The project is under active development. Interfaces, balance, content, and
save migrations may continue to change before a stable release.

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

Additional suites and individual commands are documented in
[`docs/TESTING.md`](docs/TESTING.md).

## Texture import normalization

Texture import settings are cached in `.import` sidecars. To keep new textures
consistent by default, normalize imported textures before committing:

```sh
./scripts/normalize_texture_profiles.sh
```

To normalize only a specific directory (for example environment textures):

```sh
./scripts/normalize_texture_profiles.sh res://art/exported/environment/textures
```

The script enforces a single baseline texture profile by default and sets
`import_profile = "managed_default"` in `[params]`. If any texture needs
custom settings, set:

```ini
[params]
import_profile="custom"
```

in its `.import` file to opt it out.

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

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
[`world/README-WORLD-AUTHORING.md`](world/README-WORLD-AUTHORING.md) for more
detail.

## Authorship and assets

NETfishing is human-directed and uses a mixture of human-authored assets and
software-development assistance. The project records this plainly rather than
claiming that repository history can prove how each line was produced. See
[`CREDITS.md`](CREDITS.md) and
[`docs/ASSET-PROVENANCE.md`](docs/ASSET-PROVENANCE.md).

No project-wide source license has been selected yet. Do not assume permission
to redistribute the source or bundled assets beyond rights stated in their
individual license records.
