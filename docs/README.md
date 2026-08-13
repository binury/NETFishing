# NETfishing documentation

This directory is the single home for maintained project documentation.
Start here instead of searching feature, asset, world, or script directories
for local README files.

## Authoritative references

- [`DEVELOPMENT.md`](DEVELOPMENT.md): architecture, engineering decisions,
  content and balance policy, authoring guidance, and validation.
- [`ATTRIBUTION.md`](ATTRIBUTION.md): ownership, credits, licensing map,
  third-party notices, asset provenance, and redistribution requirements.
- [`PORTMASTER.md`](PORTMASTER.md): PortMaster packaging, installation,
  controller mapping, performance behavior, and hardware release checks.
- [`README-PLAYTEST.txt`](README-PLAYTEST.txt): the player-facing README staged
  into desktop playtest packages.

## Related repositories

- [Discovery service API](https://forge.makearmy.io/woofmeow/netfishing-discovery-server/src/branch/main/docs/API.md)
  stays with the service implementation and defines its versioned HTTP
  contract.
- [Dedicated-server packaging](https://forge.makearmy.io/woofmeow/netfishing-dedicated-server/src/branch/main/README.md)
  stays with its installer and update scripts. It consumes this repository's
  attribution and legal notices from the exact pinned game commit instead of
  maintaining copies.

Those code-coupled references remain in their own repositories. Game-wide
architecture, authoring, licensing, credits, and provenance are not duplicated
there.

Exact runtime values and behavior remain authoritative in source code, scenes,
and resources. These documents describe boundaries, policy, and maintenance
procedures; they should not duplicate changing constants or inventories that
can be derived reliably from the project.

## Files intentionally kept at the repository root

The following are entry points or governing legal documents rather than
general project documentation, so they remain at conventional root paths:

- `README.md`
- `CONTRIBUTING.md`
- `LICENSE`
- `ASSET-LICENSE.md`
- `TRADEMARKS.md`
- `CONTRIBUTOR-TERMS.md`

Third-party font license texts stay beside their font files under `ui/fonts/`
so the licensed files and their original notices cannot drift apart. Build
scripts collect those legal files and the authoritative attribution record
when assembling releases.

## Maintenance rule

Do not add feature-specific README files elsewhere in the repository. Add or
update the appropriate reference above and link to its heading when source
comments need more context. Player-facing package instructions belong only in
`README-PLAYTEST.txt`; source and scripts remain authoritative for command-line
usage.
