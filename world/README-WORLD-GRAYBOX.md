# NETFISHING holdover world

`world/test_world.tscn` remains the active world. It composes the complete
temporary map, lighting, paths, bounds, and six region scenes. The practical
footprint is approximately 180 × 220 world units, including the coastal water
and outer collision bounds.

## Composition

```text
TestWorld
├── Environment
├── SeabedBoundary
├── Regions
│   ├── VillageRegion            (0, 0, 15)
│   ├── StarterPondRegion       (-42, 0, 15)
│   ├── RiverRegion               (0, 0, -40)
│   ├── LakeRegion               (53, 0, -25)
│   ├── MarshRegion              (56, 0, 38)
│   └── CoastalDockRegion         (0, 0, -103)
├── Connectors
├── Safety
└── WorldBounds
```

Every region uses the same ownership groups:

- `Visuals`: replaceable graybox meshes and labels.
- `StaticCollision`: simple gameplay collision paired with the visuals.
- `FishingWater`: explicit `FishableWaterRegion` children.
- `WaterRecovery`: explicit `PlayerWaterTrigger` children.
- `SafeRespawns`: known-safe `SafeRespawnPoint` markers.
- `Interactables`: region-owned services, currently used by the village.

`GrayboxRegion` only exposes those explicit child groups plus a stable region
ID. `TestWorld` is the aggregation boundary; regions do not select fish,
control recovery, own progression, register globally, or stream themselves.

## Safe editing

Move a whole region by moving its region root under `TestWorld/Regions`. This
keeps visuals, collision, water, recovery triggers, safe points, and
interactables synchronized. Moving only a visual mesh does not move collision
or gameplay volumes, so update its paired collision intentionally when editing
inside a region.

Safe designer targets:

- Entire region roots under `TestWorld/Regions`
- Children of `Visuals`, together with paired `StaticCollision`
- Safe-respawn marker transforms
- Landmark and label transforms
- Connector transforms and their complete StaticBody children

Structural land and route blocks extend from the common walkable elevation at
`y=0` down to approximately `y=-6`. Adjacent blocks meet at deliberate shared
edges instead of stacking collision surfaces. Decorative plaza/path color is
non-colliding and sits just above the authoritative ground.

Gameplay-critical children that must stay aligned:

- A water plane, its `FishingWater` Area3D, and its `WaterRecovery` Area3D
- A dock or bank mesh and its paired shape in `StaticCollision`
- Safe points and the land/dock they target
- The Fishing Shop visual root and `FishingShopInteraction`

Rename-sensitive paths:

- `TestWorld/Regions`
- `VillageRegion/Interactables/FishingShopWorld/FishingShopInteraction`
- `VillageRegion/Interactables/PelicanCoolerPerch`
- Each region's `FishingWater`, `WaterRecovery`, and `SafeRespawns` roots,
  unless its exported NodePaths are updated at the same time

## Adding water and recovery

1. Add a `FishableWaterRegion` Area3D under the region's `FishingWater`.
2. Give it collision layer 4, a clear location tag, and an explicit fish pool.
3. Add a matching `PlayerWaterTrigger` under `WaterRecovery`.
4. Give the trigger collision layer 8, mask 2, matching horizontal coverage,
   and the correct `surface_height`.
5. Place two or more safe respawns on nearby broad walkable land.
6. Validate casting, shoreline collision, recovery entry, and nearest-point
   selection from every side.

`TestWorld/Safety/BelowWorldFailsafe` is a temporary whole-map recovery net.
It catches seam and below-world falls that escape normal regional water
coverage. It supplements rather than replaces the five region-local triggers;
the recovery controller still permits only one recovery sequence at a time.

## Services

The Fishing Shop is an instanced scene at the east side of the village plaza.
Move the complete `FishingShopWorld` instance, not only its booth meshes.

The Pelican perch is decorative signage, not an interaction NPC. Its sign says
“Sell to Pelicans from the Cooler”; the existing 0.25× Pelican sale remains
available from the Cooler anywhere in the world. Moving or removing the
decorative perch does not change that service.

## Temporary by design

All terrain, buildings, docks, reeds, landmarks, signage, palette, and lighting
are primitive holdover presentation. A future artist or level designer can
replace `Visuals` and paired static collision without changing fishing,
recovery, shop, save, economy, or player progression code. Region IDs and
gameplay volume ownership should remain stable while visuals are replaced.

Water surfaces sit near `y=0.2`; the shared graybox seabed is near `y=-6`.
There is no structural walkable layer directly below the fishable surfaces.
