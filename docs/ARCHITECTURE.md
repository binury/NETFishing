# Architecture

## Composition

`main/main.tscn` is the application composition root. It owns long-lived
services, the active world, player container, save/settings managers, and the
pixelated UI viewport. Services are scene-owned rather than global autoloads,
which makes their dependencies visible in the main scene and allows focused
tests to instantiate the same composition.

The main script coordinates title, session, world, and UI lifecycle. Domain
logic remains in typed resources and services rather than being stored solely
in controls.

## Domain boundaries

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

## Networking

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
world state. See [`decisions/0001-host-authority.md`](decisions/0001-host-authority.md).

Moderation follows the same boundary. Player hosts may grant session-scoped
operator status to an authenticated identity. Dedicated servers derive
operators from their configured fingerprint allowlist. Operator status is
replicated for presentation, but kick, ban, unban, and artwork-reset requests
are always reauthorized against the authenticated sender by the host. Only a
player host can grant or revoke operators; operators cannot moderate the host
or another operator.

Protocol compatibility is defined in `network/network_protocol.gd`. A visible
release version is not a reason to change the protocol number.

## Persistence

`PlayerDataRoot` selects and validates a portable data root. Stores receive
paths from that owner rather than inventing unrelated locations. Progression is
written by `PlayerSaveManager`; device settings and social/identity stores have
separate formats and lifecycles.

Save migrations are sequential and explicit. Existing catches and ownership
are keyed by stable IDs so authored metadata can evolve without rewriting
historical records. Current source constants—not documentation—are
authoritative for format versions.

## Presentation

Gameplay is rendered in 3D with the GL Compatibility renderer. The main UI is
presented through a uniformly scaled SubViewport. Shared UI components and
palette resources prevent page-specific geometry and style drift.

World presentation systems (time/weather visuals, procedural sky and water,
shoreline ribbons, player blob shadows) do not own gameplay collision or
network authority. Generated shoreline meshes are deterministic presentation
resources baked from explicitly configured static terrain.

## Validation

Tests are executable Godot `SceneTree` scripts. Some are pure content/domain
checks, some instantiate the main scene, and multiplayer checks run paired host
and client processes on loopback. The repository runner provides isolation and
consistent entry points; see [`TESTING.md`](TESTING.md).
