# Development reference

This is the authoritative reference for NETfishing architecture, engineering
decisions, content policy, authoring, and validation.

## Architecture

### Composition

`main/main.tscn` is the application composition root. It owns long-lived
services, the active world, player container, save/settings managers, and the
pixelated UI viewport. Services are scene-owned rather than global autoloads,
which makes their dependencies visible in the main scene and allows focused
tests to instantiate the same composition.

The main script coordinates title, session, world, and UI lifecycle. Domain
logic remains in typed resources and services rather than being stored solely
in controls.

### Domain boundaries

- `fish/` defines species, availability, catches, pools, quality, and selection.
- `fishing/` owns cast/chase state and resolves authoritative fishing surfaces.
- `inventory/`, `items/`, `economy/`, `progression/`, and `jobs/` own persistent
  player-facing game state.
- `world/` owns authored map composition and presentation. Water type is a
  shared typed definition used by water bodies, fish habitat, fishing
  validation, Logbook classification, and saltwater shoreline presentation.
- `ui/` observes and invokes domain services. It does not define stable item or
  fish identity.

Resource files (`.tres`) are authored data. Stable IDs, not display names or
node names, connect persistent and networked state to that data.

### Networking and authority

`NetworkSession` owns ENet session lifecycle and peer registration. Dedicated
network services validate and replicate bounded domains such as fishing,
sales, shops, item use, profiles, jobs, mail, chat, drawings, time, and weather.

`DiscoveryClient` is an optional directory layer beside `NetworkSession`. An
open host may publish a short-lived room lease, and the shared Join Game page
may browse compatible leases before handing the selected address back to the
existing direct ENet connection flow. The directory does not carry gameplay
traffic or become a gameplay authority. Its base URL comes from
`network/discovery/base_url`, with `NETFISHING_DISCOVERY_URL` available as a
development/deployment override.

The host is authoritative. Clients submit requests or evidence; the host
derives trusted context from registered peers, authoritative regions, and
server-owned state before mutating inventory, wallet, progression, or shared
world state. Private single-player uses the same host path. Client evidence is
bounded and reconstructed where possible; UI activation is never proof that a
server-side mutation succeeded.

Moderation follows the same boundary. Player hosts may grant session-scoped
operator status to an authenticated identity. Dedicated servers derive
operators from their configured fingerprint allowlist. Operator status is
replicated for presentation, but kick, ban, unban, and artwork-reset requests
are always reauthorized against the authenticated sender by the host. Only a
player host can grant or revoke operators; operators cannot moderate the host
or another operator.

Protocol compatibility is defined in `network/network_protocol.gd`. A visible
release version is not a reason to change the protocol number.

### Persistence and stable identifiers

`PlayerDataRoot` selects and validates a portable data root. Stores receive
paths from that owner rather than inventing unrelated locations. Progression is
written by `PlayerSaveManager`; device settings and social/identity stores have
separate formats and lifecycles.

Save migrations are sequential and explicit. Existing catches and ownership
are keyed by stable IDs so authored metadata can evolve without rewriting
historical records. Current source constants—not documentation—are
authoritative for format versions.

Repository-owned resources are authoritative authored data. Persistent and
networked records refer to stable IDs; display names, filenames, node names,
coordinates, and pool names are not compatibility identifiers. Cross-domain
concepts such as water type use one typed definition. Removing or changing a
stable ID requires an explicit compatibility plan.

### Presentation

Gameplay is rendered in 3D with the GL Compatibility renderer. The main UI is
presented through a uniformly scaled SubViewport. Shared UI components and
palette resources prevent page-specific geometry and style drift.

World presentation systems (time/weather visuals, procedural sky and water,
shoreline treatment, player blob shadows) do not own gameplay collision or
network authority.

### Engineering consequences

- Shared mutations must behave consistently for private hosts, open hosts,
  dedicated servers, and joined clients.
- Networking changes require local-host and paired host/client validation.
- Protocol payloads and rejection cleanup are explicit and bounded.
- Renaming visible UI does not require a save migration.
- Content validation covers stable-ID uniqueness, catalog completeness, pool
  membership, and typed habitat compatibility.
- New authored assets require provenance records as well as resource
  references.

## Content and balance

Balance is authored data and should change deliberately. Exact current values
remain authoritative in `.tres` resources and typed scripts.

### Fish

- Stable fish IDs and catalog numbers must not be changed for display cleanup.
- Species availability may constrain water type, time, weather, bait, and
  other authored context.
- Location pools control selection weight; the global catalog remains
  comprehensive.
- Freshwater and saltwater habitat is validated by the host in addition to
  pool membership.
- Value, rarity, quality, weight ranges, and authored barrier-health bands
  should be reviewed together because they affect economy and catch
  difficulty.

### Economy and progression

- Sales and purchases are host-authoritative and must mutate inventory and
  wallet exactly once.
- Reserved assets are rejected atomically; mixed valid and reserved batches
  must not partially succeed.
- Item effects, shop prices, inventory and storage capacity, fishing upgrades,
  jobs, and experience are separate balance axes. Avoid changing several in
  an unrelated presentation pass.

Record affected stable IDs and resource paths, old and new values, intended
player-facing outcome, interactions with quality/availability/economy,
deterministic validation, and save-compatibility impact with each balance
change. Do not bump a save schema or network protocol merely because an
authored number changed.

## Authoring

### World composition

`world/test_world.tscn` is the shared gameplay stage. It owns the environment,
sun, world bounds, and below-world failsafe, then hosts exactly one active
`WorldRegion`. Two canonical region implementations are supported:

- the generated world, which is the default for new games and is rebuilt from
  the saved seed; and
- the starter island, which remains an authored selectable layout and a useful
  compatibility/reference scene.

The stable layout IDs live in `world/world_layout.gd`. Do not infer a layout
from a scene filename, display label, or region node name. Both implementations
must satisfy the shared `WorldRegion` contract for player spawn, safe respawns,
water regions, recovery, gathering, digging, the shop, and player storage.

A region owns the content that changes with the selected world:

```text
WorldRegion
├── Terrain
├── WaterBodies
├── PlayerSpawn
├── SafeRespawns
├── DiggableAreas
├── GatherableAnchors
└── Interactables
    ├── FishingShopWorld
    └── PlayerStorageBox
```

The generated region owns its chunk, biome, and prop catalogs and derives
terrain collision, water coverage, biome placement, and presentation reference
geometry from the generated result. The starter-island region owns its imported
terrain hierarchy and explicitly placed content. Code shared by both layouts
must depend on `WorldRegion`, not a starter-island child path.

Every fishable water body authors its water type explicitly. Fish species use
the same central type through an allowed-water-type bitmask. Do not infer
habitat from node names, pool filenames, coordinates, or water height.

In the generated layout, seed and layout ID are persistent data. Chunk IDs,
edge rules, biome definitions, and prop definitions are authored resources;
changing them can change the world produced by an existing seed and therefore
requires deliberate compatibility review.

For the authored starter island, move a meaningful feature root rather than one
of its implementation children. Child transforms are local offsets owned by
that feature. Its imported GLB hierarchy is the starter region's terrain and
collision authority; this rule does not describe generated-world collision.

The active `Environment` and `Sun` remain Inspector-authored on the shared
stage and are not recreated by either region.

### Reusable world props

Use one placed `WorldProp` root for a complete landmark:

```text
WorldProp
├── Visual
└── Collision
    └── CollisionShape3D
```

Put optional interaction areas, labels, and markers beneath the same root.
Instance imported GLB content under `Visual` and keep gameplay collision under
`Collision`. Author reusable assets at scale `(1, 1, 1)`. Uniform provisional
root scaling is acceptable when visual and collision scale together; avoid
non-uniform root scaling. Make mutable per-instance shapes, meshes, and
materials local to the scene.

### Shoreline presentation

The visible shoreline treatment is currently produced by the water materials.
The older smooth-ribbon baker and generated starter-island ribbon resource are
retained as development history/tooling, but the ribbon mesh is disabled and
is not part of the current rendered shoreline. Do not treat a ribbon rebuild
as a normal terrain-authoring requirement or re-enable the mesh as incidental
cleanup.

### Facial-feature textures

Put new PNGs under the matching directory in
`art/exported/characters/faces/`:

```text
eyes/<id>.png
noses/<id>.png
mouth/<id>.png
```

The category directory is authoritative. A category prefix is optional, so
both `sleepy.png` and `eyes_sleepy.png` produce the stable option ID `sleepy`.
Filenames normalize to lowercase snake_case and are stored in appearance
snapshots, so do not casually rename them. Preserve the established RGBA
transparent canvas. Restart a development build after adding an image; rebuild
exports to package new `res://` files.

The tracked import policy keeps these facial-feature textures at a maximum
runtime size of 512×512, uses VRAM compression, and does not generate mipmaps.
The source PNGs remain unchanged. Run the texture import normalizer shown below
after adding facial artwork so low-memory builds do not retain full-resolution
copies of the entire customization catalog.

### Texture sampling

NETfishing artwork always uses nearest-neighbor sampling. Do not enable linear,
bilinear, trilinear, or anisotropic texture filtering, and do not generate
mipmaps. Shader samplers must declare `filter_nearest`. The
`TextureSamplingPolicy` autoload applies nearest sampling to 2D canvas items,
Sprite3D presentations, imported 3D materials, and dynamically constructed
mesh materials at runtime.

After importing new artwork, normalize its tracked import metadata where
needed and run the focused policy check:

```sh
godot --headless --path . --script scripts/normalize_texture_imports.gd \
  -- --apply --root res://path/to/new/artwork
godot --headless --path . --script tests/texture_sampling_validation.gd
```

### Importing animalese voice sets

Animalese clips use one deterministic runtime level and format: -18 dBFS RMS
with a -3 dBFS peak ceiling, mono, 48 kHz, 16-bit PCM. Import a supplied set
through the normalization script rather than copying its WAV files directly:

```bash
scripts/import_animalese_voice.sh /path/to/source_clips <sample-set-id>
```

The source directory may contain lowercase letter, number, and underscore WAV
filenames. The script converts every top-level WAV and writes the results under
`sound/dialogue/animalese/<sample-set-id>/`. Add a new runtime set to
`player/animalese_voice_profiles.gd` after import, then run the quick validation
suite. Keep the untouched submission and its original hashes in the private
intake record; repository files are normalized derivatives.

### Bubble menus

Instance `ui/components/bubble_menu/bubble_button.tscn` for each action, or
attach `bubble_button.gd` to an existing button. Author neutral size, desktop
and compact anchors, font-size limits, and deterministic motion in the
Inspector. A label child may be assigned with `label_control_path`.

Place buttons under a Control using `bubble_cluster.gd`, pass ordered button
references to `configure()`, and call `apply_layout()` when available size or
responsive layout changes. Order defines keyboard/controller focus neighbors.
The shared profile owns palette, styles, proportional-font ratio, hover
response, and contact tuning. Parent menus own labels, actions, anchors,
availability, and confirmation behavior.

`motion_scale = 0.0` disables idle drift/deformation while preserving hover and
focus feedback. Contact correction is deterministic and bounded; do not replace
it with physics that destabilizes layout, focus order, or hit targets.

## Validation

Tests are executable Godot `SceneTree` scripts. Some are pure content/domain
checks, some instantiate the main scene, and multiplayer checks run paired host
and client processes on loopback. The repository runner provides isolation and
consistent entry points.

### Consolidated runner

```sh
scripts/run_validations.sh quick
scripts/run_validations.sh full
scripts/run_validations.sh host
scripts/run_validations.sh network
scripts/run_validations.sh all
scripts/run_validations.sh --list
```

- `quick` runs deterministic content and domain checks.
- `full` adds socket-free scene/runtime checks.
- `host` runs single-process authority checks that bind local UDP.
- `network` runs loopback host/client pairs.
- `all` runs `full`, `host`, and `network`.

Set `GODOT_BIN` to select an executable and `TEST_TIMEOUT_SECONDS` to change
the per-process timeout. The runner isolates and removes XDG roots.

For one focused test:

```sh
test_root="$(mktemp -d)"
XDG_DATA_HOME="$test_root/data" \
XDG_CONFIG_HOME="$test_root/config" \
godot --headless --path . --script tests/fish_catalog_content_validation.gd
rm -rf -- "$test_root"
```

Do not point `NETFISHING_DATA_DIR` at an arbitrary empty directory; it is an
explicit portable-data override and must identify a valid data root. The
PortMaster launcher is the narrow exception: it also sets
`NETFISHING_CREATE_DATA_DIR=1`, allowing the game to initialize its known empty
external save directory on first launch.

Headless tests cannot prove visual alignment, mouse routing, shader appearance,
controller feel, or resize behavior. Presentation changes require graphical
review at the canonical 1280×720 layout and relevant low/high and ultrawide
resolutions.

Network tests require free loopback UDP ports and local-socket permission. A
release audit additionally requires clean Git/tag verification, editor import,
platform exports, executable smoke tests, archive inspection, and SHA-256
verification; those checks are intentionally outside the development runner.
