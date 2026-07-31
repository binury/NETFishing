# World authoring

The active test world uses the human-authored starter island through
`world/regions/starter_island_region.tscn`.

## Active composition

`world/test_world.tscn` owns the gameplay-wide environment, sun, world bounds,
and below-world failsafe. `StarterIslandRegion` owns the placed island content:

```text
StarterIslandRegion
├── Terrain
│   ├── Visual
│   └── Collision
├── WaterBodies
│   ├── Pond
│   │   ├── VisualWater
│   │   ├── FishingRegion
│   │   └── RecoveryRegion
│   └── Ocean
│       ├── VisualWater
│       ├── FishingRegions
│       └── RecoveryRegions
├── PlayerSpawn
├── SafeRespawns
└── Interactables
    ├── FishingShopWorld
    └── PelicanCoolerPerch
```

Move the meaningful feature root rather than one of its implementation
children. Child transforms are local offsets owned by that feature.

## Water bodies

Every fishable region must author its `water_type` explicitly. The starter pond
is `FRESH_WATER`; the starter coast is `SALT_WATER`. Fish species use the same
central type definition through an allowed-water-type bitmask, so pool contents
and authoritative selection are both validated against the region. Do not infer
habitat from node names, pool filenames, coordinates, or water height.

Select `WaterBodies/Pond` to move or resize the pond. Its transform is the
authoritative surface position. The `surface_size`, fishing padding, recovery
padding, and recovery depth properties update the visible water and gameplay
coverage together. Fishing and recovery derive the surface height from the
owned surface transform.

Select `WaterBodies/Ocean` to move the surrounding water as one feature. Its
visual, fishing lobes, and recovery lobes use local transforms beneath the
ocean root. The existing multi-lobe footprint remains intentionally explicit;
changing that footprint still requires editing its owned lobe children.

## Placed features

- `PlayerSpawn` is the authoritative initial player transform. Its rotation
  controls initial facing.
- Each marker under `SafeRespawns` is an authoritative recovery destination.
  Recovery preserves the player's current facing; marker rotation is
  intentionally not applied.
- `Interactables/FishingShopWorld` owns the shop visual, collision,
  interaction area, prompt, and entrance marker.
- `Interactables/PelicanCoolerPerch` owns the complete Pelican landmark visual.
  Pelican selling remains a Cooler action and has no world interaction area.
- `Terrain` owns both the imported visual and generated terrain collision.
- `BelowWorldFailsafe/Coverage` exposes the below-world recovery coverage as a
  saved collision shape in `world/test_world.tscn`.

The active `Environment`, `Sun`, and external starter-island grass material
remain directly editable through the Inspector. Their tuning is not recreated
by runtime scripts.

## Reusable world props

Use a single placed `WorldProp` root for trees, rocks, buildings, benches,
signs, vegetation, and similar landmarks:

```text
WorldProp
├── Visual
└── Collision
    └── CollisionShape3D
```

Add optional interaction areas, labels, and markers beneath the same root.
Instance imported GLB visuals beneath `Visual`; keep gameplay collision
Godot-owned beneath `Collision`. Place and duplicate the complete prop scene,
not its visual child.

Author reusable assets at scale `(1, 1, 1)`. Uniform root scaling is acceptable
for provisional props when visual and collision scale together. Avoid
non-uniform root scaling because it can deform collision and imported geometry
unpredictably. Make mutable per-instance shapes, meshes, and materials local to
the scene so editing one prop does not change unrelated instances.

## Shoreline tide ribbons

Each map that uses generated tide ribbons owns a `ShorelineRibbonBaker` node and
one `ShorelineRibbonConfig` resource per water body. Each fishable water body
declares the shared `WaterType` value used by fishing, Logbook classification,
and shoreline presentation. A configuration designates
only the static terrain `CollisionShape3D` or `MeshInstance3D` to intersect, the
water height, explicit generation bounds, water-facing reference, optional
smoothing overrides, and the generated `.tres` output path. Props, docks,
players, bobbers, and gameplay areas are not scanned unless a map author
explicitly selects one as the terrain source. The baker reports every configured
body but intentionally generates ribbons only for `SALT_WATER`; freshwater uses
the shared depth-tinted shader without tide marks or an advancing wash.

To rebuild in the editor, select the map's `ShorelineRibbonBaker` node and press
**Rebuild Shoreline Ribbons** in the Inspector. The equivalent validation/CI
command for the starter map is:

```sh
godot --headless --path . --script scripts/bake_shoreline_ribbons.gd
```

Set the baker's `debug_path_stage` to Raw, Simplified, or Smoothed before an
editor rebuild to compare the extraction stages. Keep it Off in the finished
scene; the temporary editor-only line preview is never saved as gameplay data.

Rebuild a saltwater ribbon only when its terrain at the waterline, configured
water height, or generation bounds change. Freshwater terrain changes do not
require a ribbon rebuild because freshwater bodies have no ribbon. Adding or
moving unrelated props, fishing areas, recovery volumes, or other gameplay
nodes does not require a rebuild. Normal gameplay loads the committed generated
saltwater meshes and never runs the extraction step.
