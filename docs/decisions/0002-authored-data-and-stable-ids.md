# ADR 0002: Authored resources and stable identifiers

Status: accepted

## Context

Fish, items, pools, availability, shop stock, and other game content evolve
independently from saved catches and network messages. Display labels and scene
node names are expected to change during development.

## Decision

Repository-owned resources are the authoritative authored data. Persistent and
networked records refer to stable IDs. Display names, filenames, node names,
coordinates, and pool names are not compatibility identifiers.

Cross-domain concepts such as water type use one typed definition rather than
duplicated strings. Comprehensive catalogs remain separate from location-
specific selection pools.

## Consequences

- Renaming visible UI does not require save migration.
- Removing or changing a stable ID requires an explicit compatibility plan.
- Content validation checks uniqueness, catalog completeness, pool membership,
  and typed habitat compatibility.
- New authored assets need provenance records as well as resource references.
