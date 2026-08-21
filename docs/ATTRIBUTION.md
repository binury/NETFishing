# Attribution, licensing, and asset provenance

This is the authoritative project record for ownership, credits, license
boundaries, third-party notices, asset provenance, and redistribution checks.
A Git commit proves when bytes entered the repository; it does not by itself
prove authorship or licensing.

## Ownership and credits

NETfishing is jointly owned, developed, and published by its creators,
publicly credited as Voyager and Endeavour and operating collectively as the
independent team Woofmeow.

- Voyager: co-owner, developer, project director, creator of the game's
  current provisional fish artwork and original 3D work except where another
  creator is credited, and composer of the original title track
  `audio/music/title/as_in_four_wolves.ogg`, dusk/world track
  `audio/music/world/craft.mp3`, and the synthesized robot animalese tones.
- Endeavour: co-owner, developer, and 2D artist. Her incorporated work includes
  character pattern/channel-map art, environment and UI art, and item art.
  Planned work is not described as incorporated until its files enter the
  project.
- chillnfill: contributor of original 3D models for the character bodies and
  arms, ears and tails, and multiple world props and decorative assets,
  including trees and bridges. The contributor requested to be credited as
  `chillnfill`.
- adamantris: contributor of the original hand-net model and texture artwork;
  the contributor is credited as `adamantris`.

Voyager is also the original catalog porter credit in PortMaster metadata.
Third-party creators are credited with their individual records below. Those
credits do not imply endorsement of NETfishing, Woofmeow, or its owners.

## License map

Do not describe the complete repository as covered only by the GPL.

| Material | Governing terms |
| --- | --- |
| Project-owned software code, shaders, code-oriented scene/resource configuration, tests, build tooling, and server software | GPL-3.0-or-later; source-root `LICENSE` and packaged `GPL-3.0-or-later.txt` |
| Project-owned artwork, textures, models, animation, music, audio, narrative content, characters, and other creative assets | Source-root or packaged `ASSET-LICENSE.md` |
| NETfishing and Woofmeow names, logos, icons, and official identity | Source-root or packaged `TRADEMARKS.md` |
| Third-party engines, fonts, sounds, and other external material | Their original terms, recorded below and in adjacent license texts where applicable |
| Previously accepted or expressly invited outside contributions | Source-root `CONTRIBUTOR-TERMS.md` plus any separately signed agreement |

Generated Godot import metadata and deterministic generated resources follow
the terms of their source material or generating code. Repository location
alone does not relicense third-party material.

The GPL permits study, modification, redistribution, and forks of covered
code. It does not grant rights to NETfishing creative assets or branding. The
NETfishing Asset License separately permits qualifying noncommercial add-on
Mods for official NETfishing software and narrowly scoped Contribution Forks
used to prepare changes for possible upstream inclusion. It does not permit
those assets to accompany independent code forks, clones, standalone games,
unrelated products, or general-purpose asset packs. A GPL fork that is not a
qualifying Contribution Fork must replace NETfishing assets and reserved
branding with independently licensed material and a distinct identity.

Project-wide code, asset, branding, or contributor-license changes require
written approval from both NETfishing owners under their private joint
ownership agreement.

## Godot Engine notice

NETfishing uses Godot Engine under the MIT License:

> Copyright (c) 2014-present Godot Engine contributors.
> Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the “Software”), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

Godot licensing and bundled third-party-component notices are available at
https://godotengine.org/license/ and
https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt. Godot uses
FreeType for font rendering; portions are copyright The FreeType Project
(https://www.freetype.org) under its applicable license.

## Font notices

- **Tuffy Bold** — Thatcher Ulrich, Karoly Barta, and Michael Evans; dedicated
  to the public domain. Runtime file: `ui/fonts/Tuffy_Bold.otf`; original notice:
  `ui/fonts/Tuffy-LICENSE.txt`.
- **Seattle Avenue** — JLH Fonts; dedicated to the public domain by the creator.
  Runtime file: `ui/fonts/seattle_avenue.otf`; source, hash, and original notice:
  `ui/fonts/Seattle-Avenue-LICENSE.txt`.

Public-domain fonts are not governed by the NETfishing Asset License.

## Intake policy

For every new external or supplied asset, retain a durable intake record with:

- creator or supplying party;
- original source location or delivery channel;
- source filename and, when useful, its initial repository destination;
- source and destination SHA-256 when copied without modification;
- license or explicit permission;
- any permitted transformations;
- the importing commit or release.

The intake record may live in the accepted pull request, issue, email, or the
owners' private project records. This public document should contain the
credits and license notices needed by recipients; it should not duplicate a
changing file inventory that can be derived from the repository itself.

NETfishing does not accept unsolicited contributions. For work expressly
invited by both Owners, maintainers must obtain affirmative agreement to the
source-root `CONTRIBUTOR-TERMS.md` and retain the written invitation and
agreement in a durable Project record.

Runtime resources must use `res://` paths. Workstation Sync folders are intake
locations only and must never appear in scenes or resources.

## Project-created artwork and music

The current in-game fish images are provisional artwork by Voyager. Endeavour
is creating replacement fish artwork, but work that has not been incorporated
into this repository is not presented here as part of the game or attributed
as a shipped asset.

Endeavour's incorporated 2D contributions include the inventory notepad,
environment and UI artwork, item artwork, and character customization pattern
and channel-map artwork. Voyager's incorporated original work includes 3D
assets, the provisional fish artwork, the title and dusk music identified
above, and the robot animalese tones. Specific contributor exceptions are
recorded below and in the in-game credits.

These credits intentionally describe work by creator and contribution family
instead of maintaining a second file-by-file asset catalog. Runtime resources
and Git history identify the files present in a particular revision. A path,
directory name, commit author, or supplying party is not by itself evidence of
authorship.

## Third-party and contributor runtime material

The following paths identify distributed material whose external license or
individual contributor credit must remain easy to find. They were checked
against the repository when this record was revised.

| Material | Runtime location | Credit or terms |
| --- | --- | --- |
| Tuffy font | `ui/fonts/Tuffy_Bold.otf` | Public-domain dedication in `ui/fonts/Tuffy-LICENSE.txt`. |
| Seattle Avenue font | `ui/fonts/seattle_avenue.otf` | Public-domain font by JLH Fonts; notice in `ui/fonts/Seattle-Avenue-LICENSE.txt`. |
| Fishing fight loop | `audio/sfx/fishing/fighting.wav` | Edited from “Spinning reel.wav” by Freesound user tosha73, sound 509902, CC0. |
| Manual-reeling loop | `audio/sfx/fishing/reeling.wav` | Edited from the same CC0 “Spinning reel.wav” source. |
| Saltwater wave ambience | `audio/ambience/waves.wav` | “Gentle Ocean Waves Loop” by Freesound user kkenny101, sound 852826, CC0. |
| Bobber water impact | `audio/sfx/fishing/bobber.wav` | “Quick Water Droplet” by Freesound user qubodup, sound 792931, CC0. |
| Rain ambience | `audio/ambience/rain_loop_ontario.ogg` | Converted from “Rain Loop Ontario” by Freesound user Ayton, sound 212799, CC BY 3.0. |
| Character bark call | `sound/dialogue/calls/bark.wav` | Edited from `Dog_Bark.wav` by Freesound user ivolipa, sound 328729, CC0. |
| Character meow call | `sound/dialogue/calls/meow.wav` | Edited from `Cat meow.m4a` by Freesound user Christyboy100, sound 495694, Attribution 3.0. |

Creative Commons Zero information:
https://creativecommons.org/publicdomain/zero/1.0/. Creative Commons
Attribution 3.0 legal text:
https://creativecommons.org/licenses/by/3.0/legalcode.

### chillnfill 3D model contribution record

- Requested credit: `chillnfill`.
- Original contribution families: character bodies and arms; character ears
  and tails; and multiple world props and decorative assets, including trees
  and bridges.
- Repository mapping: these contributions may be incorporated into combined
  character or environment resources rather than retained as one file per
  originally supplied model. Git history is the revision-specific file map.
- Permission record: because these historical contributions predate the
  current `CONTRIBUTOR-TERMS.md`, retain the original permission record or a
  later written confirmation covering Project use, modification,
  distribution, commercial release, and applicable sublicensing.

### adamantris hand-net contribution record

- Requested credit: `adamantris`.
- Original contribution: hand-net model and texture artwork.
- The maintained repository source and runtime export contain later Project
  adaptations. Git history, rather than a duplicated current-file hash here,
  identifies their bytes at any given revision.
- Repository adaptation: reshaping and the generic `net_root`, `net_rim`,
  `net_mid`, and `net_tip` deformation rig were prepared by Voyager for
  reuse across gathering activities.
- Permission record: retain the original submission correspondence or a
  written confirmation accepting `CONTRIBUTOR-TERMS.md` with the project
  records.

### Endeavour 2D contribution record

Endeavour created the incorporated character customization patterns and
channel maps as well as additional UI, environment, and item artwork. The
current provisional fish artwork is not part of this credit. New or replacement
art is added to this record only after it is accepted into the repository.

The exact current filenames and bytes are intentionally not copied into this
document. The character appearance resources and Git history are the
revision-specific inventory.


### Fishing fight loop source record

- Source page: https://freesound.org/s/509902/
- Creator: tosha73
- Source title: `Spinning reel.wav`
- License: Creative Commons Zero (CC0)
- Downloaded source filename: `509902__tosha73__spinning-reel.wav`
- Downloaded source SHA-256:
  `9741afdb1ec9c73f5e039f0e5ac174998cb0a1f737b626531e63919d4d232fad`
- Audacity working project: `fighting.aup3`
- Audacity project SHA-256:
  `9928f077ecf48d01416f8d05700707e1b07d0f731846db80e27116f5b82dbbf5`
- Runtime edit source/destination SHA-256:
  `b6f3f2f94bfaf9254ac04dd96b1fd28c15e1011a1db44bb3e70eeaa95de3c212`
- Runtime format: 48 kHz, 16-bit, stereo PCM WAV; 2.593479 seconds;
  configured as a forward loop by the fishing presentation.
- Manual-reeling Audacity project: `reeling.aup3`
- Manual-reeling Audacity project SHA-256:
  `20ad52f6bdd16ae6561f06f8355fe309e95023e815053fd5dfbd5a5ce3c1f9f9`
- Manual-reeling runtime source/destination SHA-256:
  `e403d5b7c8af1da4b28599cc0f51de3eda70d9e9296db27852fe7dc95617a29d`
- Manual-reeling runtime format: 48 kHz, 16-bit, stereo PCM WAV;
  2.388083 seconds; configured as a forward loop.
- The downloaded source and Audacity projects remain in the project owner's
  source-work archive; only the finished runtime edits ship in the game.

### Saltwater wave ambience source record

- Source page: https://freesound.org/s/852826/
- Creator: kkenny101
- Source title: `Gentle Ocean Waves Loop`
- License: Creative Commons Zero (CC0)
- Downloaded source filename:
  `852826__kkenny101__gentle-ocean-waves-loop.wav`
- Downloaded source and runtime source/destination SHA-256:
  `f93e9890583f072ac52cf197b8b5942397d3d5e889fbdb9112a0776142f50229`
- Runtime format: 48 kHz, 24-bit, mono PCM WAV; 21.769917 seconds;
  configured as a forward loop.
- The downloaded source remains in the project owner's source-work archive;
  only the finished runtime loop ships in the game.

### Bobber water-impact source record

- Source page: https://freesound.org/s/792931/
- Creator: qubodup
- Source title: `Quick Water Droplet`
- License: Creative Commons Zero (CC0)
- Downloaded source filename: `792931__qubodup__quick-water-droplet.wav`
- Downloaded source and runtime source/destination SHA-256:
  `aef0d16384efed4a7b071c4d80c21597617f882f4e0c1d5295ac194d315eafb7`
- Runtime format: 48 kHz, 16-bit, mono PCM WAV; 0.197146 seconds; one-shot.
- The downloaded source remains in the project owner's source-work archive;
  only the finished runtime sound ships in the game.

### Character-call source records

#### Bark

- Source page: https://freesound.org/s/328729/
- Creator: ivolipa
- Source title: `Dog_Bark.wav`
- License: Creative Commons Zero (CC0)
- Downloaded source filename: `328729__ivolipa__dog_bark.wav`
- Downloaded source SHA-256:
  `c3d542dee7bfcc1901428e0c1408c0bd522d778d8e5e1dbca156cab008f3d712`
- Runtime edit source/destination SHA-256:
  `5ac2f32f33724a2fc232d725c5c37d4cfe3e93b3c1f19aa4177d2c8e3009ec78`
- Runtime format: 44.1 kHz, 16-bit, stereo PCM WAV; 0.446780 seconds;
  one-shot.

#### Meow

- Source page: https://freesound.org/s/495694/
- Creator: Christyboy100
- Source title: `Cat meow.m4a`
- License: Attribution 3.0
- Downloaded source filename: `495694__christyboy100__cat-meow.m4a`
- Downloaded source SHA-256:
  `afa3f6ef7afa2f7fee1e634d5505d2101cbba4421f8d8ff9adf562939c7a18f8`
- Converted working WAV SHA-256:
  `a505e6e230e7d9d76b65c46270d97a35a1acc510b43aa5e7343d7b04f424cade`
- Runtime edit source/destination SHA-256:
  `cce22ce1fbbc9325126a153aedc4526fde1aacf78780574fb432197dd44eb6b3`
- Runtime format: 44.1 kHz, 16-bit, stereo PCM WAV; 0.605420 seconds;
  one-shot.
- The downloaded sources and working edits remain in the project owner's
  source-work archive; only the finished runtime sounds ship in the game.

### Rain ambience source record

- Source page: https://freesound.org/s/212799/
- Creator: Ayton
- Source title: `Rain Loop Ontario`
- License: Creative Commons Attribution 3.0
- Downloaded source filename: `212799__ayton__rain-loop-ontario.aiff`
- Downloaded source SHA-256:
  `b491fc036b78a274d9ac7f6acbd014af1b5d24f5cba9bd7e3fdc05c5432ee66f`
- Runtime edit SHA-256:
  `b1979609b20fe34ed6f8902f3de65ae787a09abd71429e8aab850e87b74a4fa2`
- Changes: converted from AIFF to Ogg Vorbis and configured as looping
  weather ambience.

## Generated resources

Godot `.import` sidecars and deterministic shoreline `.tres` meshes are derived
repository resources, not original artwork. `.godot/imported/`, editor caches,
captures, exports, and temporary test data are not tracked.

## Release gate

Before a public binary or source release:

1. Search exported resources for external filesystem paths.
2. Include or make readily accessible the complete GPL text and identify the
   exact corresponding source tag or commit.
3. Include `ASSET-LICENSE.md`, `TRADEMARKS.md`, this attribution/provenance
   record, both font notices, and every applicable third-party license.
4. Retain the complete Godot Engine MIT notice above.
5. Preserve third-party terms without adding incompatible restrictions.
6. Avoid referring to a dirty or unavailable source revision.
7. Publish or offer equivalent access to exact corresponding GPL source for
   every distributed binary release.

Desktop and PortMaster build scripts stage these authoritative files as
sidecars. Godot export presets include them in exported resource packs for
platforms where sidecar documents are not normally visible. Store and release
pages should link to the exact source revision and public notices.
