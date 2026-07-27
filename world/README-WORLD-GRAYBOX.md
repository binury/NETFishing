# NETFISHING test world

`world/test_world.tscn` remains the active world composition. It currently
instances `world/regions/starter_island_region.tscn`, a Godot-owned gameplay
wrapper around the human-authored starter-island GLB.

## Starter-island ownership

```text
TestWorld
├── Environment
├── Regions
│   └── StarterIslandRegion
│       ├── Visuals
│       │   ├── StarterIslandModel
│       │   ├── OceanWater
│       │   └── PondWater
│       ├── StaticCollision
│       ├── FishingWater
│       ├── WaterRecovery
│       ├── SafeRespawns
│       ├── PlayerSpawn
│       └── Interactables
├── Safety
└── WorldBounds
```

The imported GLB is visual source content and remains at identity scale. The
wrapper creates concave static collision from its explicit mesh reference and
owns all water, fishing, recovery, spawn, and service placement.

Move the complete `StarterIslandRegion` root to keep visuals and gameplay
volumes synchronized. When editing inside the wrapper, keep each water mesh
aligned with its matching `FishingWater` and `WaterRecovery` shapes. Safe
respawns and `PlayerSpawn` must remain on broad upper terrain.

Rename-sensitive paths:

- `TestWorld/Regions`
- `TestWorld/Regions/StarterIslandRegion`
- the NodePaths exported by `StarterIslandRegion`
- each region's `FishingWater`, `WaterRecovery`, and `SafeRespawns` roots

## Reverting to the modular graybox

The previous region scenes remain unchanged under `world/regions/`. To restore
the prior holdover world, restore `world/test_world.tscn` and
`world/test_world.gd` from commit `633bbd9`, then remove the player-spawn
composition line added to `main/main.gd`. That composition instances:

- `village_region.tscn`
- `starter_pond_region.tscn`
- `river_region.tscn`
- `lake_region.tscn`
- `marsh_region.tscn`
- `coastal_dock_region.tscn`

No region asset needs to be reconstructed or recovered from deleted content.

## Water and recovery

The pond and surrounding ocean remain separate fishable regions using the
existing test pool. Ocean fishing and recovery use four collision shapes so
the raised island interior is not classified as ocean. Regional recovery is
supplemented by `TestWorld/Safety/BelowWorldFailsafe`.

The pond surface is at `y=2.10`. The ocean is at `y=-0.45`, between the
authored upper beach and submerged shelf rings. Fishable regions explicitly
provide their surface heights to the shared fishing presentation.

The Fishing Shop remains a complete instanced interactable. The Pelican perch
remains convenience signage only; Pelican selling is available through the
Cooler from anywhere.
