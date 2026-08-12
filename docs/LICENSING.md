# NETfishing licensing and release notices

NETfishing uses separate licenses for code, creative assets, third-party
material, and branding. Do not describe the complete repository as being
covered only by the GPL.

## Ownership

Copyright © 2026 Alexander Sellite and Rheannon Eisworth, operating
collectively as the independent development and publishing team Woofmeow.

## License map

| Material | Terms |
| --- | --- |
| Project-owned software code, shaders, scripts, code-oriented scene/resource configuration, tests, build tooling, and server software | GPL-3.0-or-later; full text in `LICENSE` |
| Project-owned artwork, textures, models, animation, music, audio, narrative content, characters, and other creative assets | `ASSET-LICENSE.md` |
| NETfishing and Woofmeow names, logos, icons, and official identity | `TRADEMARKS.md` |
| Third-party engines, fonts, sounds, and other external material | Their original terms, recorded in `THIRD-PARTY-NOTICES.md` and `docs/ASSET-PROVENANCE.md` |
| New outside contributions | `CONTRIBUTOR-TERMS.md` plus any separately signed agreement |

Generated Godot import metadata and deterministic generated resources follow
the terms of the source material or code from which they are derived. Merely
being stored in this repository does not relicense third-party material.

## Modding boundary

The GPL permits community members to study, modify, redistribute, and fork the
covered code under the GPL. It does not grant rights to NETfishing creative
assets or branding.

The NETfishing Asset License separately permits noncommercial add-on Mods that
require and operate with official NETfishing software. It does not permit the
assets to accompany code forks, clones, standalone games, unrelated products,
or general-purpose asset packs.

A fork may exercise its GPL code rights by replacing all NETfishing assets and
reserved branding with independently licensed material and a distinct
identity.

## Contributor intake

Maintainers must obtain affirmative agreement to `CONTRIBUTOR-TERMS.md` before
accepting a new outside contribution. Record the agreement in a durable pull
request, issue, email, or signed document.

For each external asset, preserve the creator, source, original filename,
license, transformations, and available hashes in `docs/ASSET-PROVENANCE.md`.

## Binary-release checklist

Every public binary package must:

1. include or make readily accessible the complete GPL text;
2. identify the exact corresponding source tag or commit and provide
   equivalent access to that source;
3. include `ASSET-LICENSE.md`, `TRADEMARKS.md`, `CREDITS.md`, and
   `THIRD-PARTY-NOTICES.md`;
4. include the public-domain font records and every required third-party
   attribution;
5. retain the Godot Engine MIT notice;
6. avoid referring to a dirty or unavailable source revision; and
7. preserve third-party license terms without adding incompatible
   restrictions.

Desktop and PortMaster build scripts stage these notices as sidecar files.
Godot export presets also include the authoritative notice files in exported
resource packs for platforms such as Android and macOS. Store and release
pages should link to the exact source revision and the public notices. A future
in-game legal-notices screen should expose the packed notices directly on
platforms where sidecar documents are not normally visible.

## Changing terms

Project-wide code, asset, branding, or contributor-license changes require
written approval from both Alexander Sellite and Rheannon Eisworth under their
joint ownership agreement.
