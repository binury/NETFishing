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
