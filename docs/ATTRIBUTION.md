# Attribution, licensing, and asset provenance

This is the authoritative project record for ownership, credits, license
boundaries, third-party notices, asset provenance, and redistribution checks.
A Git commit proves when bytes entered the repository; it does not by itself
prove authorship or licensing.

## Ownership and credits

NETfishing is jointly owned, developed, and published by its creators,
publicly credited as Voyager and Endeavour and operating collectively as the
independent team Woofmeow.

- Voyager: co-owner, developer, project director, creator of the game's 3D
  art, and composer of the original title/ambient track
  `audio/music/title/as_in_four_wolves.ogg`, world track
  `audio/music/world/craft.mp3`, and animalese placeholder tones.
- Endeavour: co-owner, developer, and creator of the game's 2D art, including
  the original fish, environment, UI, and other artwork.
- chillnfill: contributor of original 3D models for the character bodies and
  arms, ears and tails, and multiple world props and decorative assets,
  including trees and bridges. The contributor requested to be credited as
  `chillnfill`.
- Tekgator: creator of the cooler-capacity, reel-speed, and barrier-power shop
  icons.

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
| New outside contributions | Source-root `CONTRIBUTOR-TERMS.md` plus any separately signed agreement |

Generated Godot import metadata and deterministic generated resources follow
the terms of their source material or generating code. Repository location
alone does not relicense third-party material.

The GPL permits study, modification, redistribution, and forks of covered
code. It does not grant rights to NETfishing creative assets or branding. The
NETfishing Asset License separately permits qualifying noncommercial add-on
Mods for official NETfishing software; it does not permit those assets to
accompany code forks, clones, standalone games, unrelated products, or
general-purpose asset packs. A GPL fork must replace NETfishing assets and
reserved branding with independently licensed material and a distinct
identity.

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

For every new external or supplied asset, record:

- creator or supplying party;
- original source location or delivery channel;
- source filename and repository destination;
- source and destination SHA-256 when copied without modification;
- license or explicit permission;
- any permitted transformations;
- the importing commit or release.

Maintainers must also obtain affirmative agreement to the source-root
`CONTRIBUTOR-TERMS.md` before accepting an outside contribution and retain
that agreement in a durable pull request, issue, email, or signed document.

Runtime resources must use `res://` paths. Workstation Sync folders are intake
locations only and must never appear in scenes or resources.

## Asset inventory and provenance

| Asset family | Repository location | Recorded provenance |
| --- | --- | --- |
| Fish art and portraits | `fish/species/`, `art/exported/fish/` | Original 2D artwork by co-owner Endeavour. |
| Item icons | `items/icons/` | Original 2D artwork by co-owner Endeavour except where separately credited below. |
| Cooler-capacity shop icon | `items/icons/equipment/64_cooler_plus.png` | Original artwork by Tekgator. Repository SHA-256: `b63705be5b78915753c068170323781a90e22b555b57a5b2ca9466e2726539f7`. |
| Reel-speed shop icon | `items/icons/shop/64_speed_plus.png` | Original artwork by Tekgator. Repository SHA-256: `938452798f2be505e06ce3fbef178f52459331fd3bced8763fbc2a80157125ca`. |
| Barrier-power shop icon | `items/icons/shop/64_power_plus.png` | Original artwork by Tekgator. Repository SHA-256: `164d34ce152aa6d75de79b69f0be2d9074f7891057de9636678889028ff98ae7`. |
| Inventory notepad | `art/ui/ui_notepad.png` | Original 2D artwork by co-owner Endeavour; integrated without a runtime external path. |
| Environment textures | `art/exported/environment/textures/` | Original 2D artwork by co-owner Endeavour. |
| UI patterns | `art/patterns/` | Original 2D artwork by co-owner Endeavour. |
| Fur customization channel maps | `art/exported/characters/patterns/` | Original 2D channel-map artwork by co-owner Endeavour. Exact file hashes are recorded below. |
| Character base meshes and appendages | `art/source/characters/base/`, `art/exported/characters/base/`, and derived character resources | Original body and arm models and original ear and tail models by chillnfill. Any embedded original 2D artwork is by Endeavour. |
| World and decorative prop models | `art/source/environment/`, `art/exported/environment/`, and derived world resources | Original prop and decorative models by chillnfill, including trees and bridges. Any embedded original 2D artwork is by Endeavour. |
| Tuffy font | `ui/fonts/Tuffy_Bold.otf` | Public-domain dedication in `ui/fonts/Tuffy-LICENSE.txt`. |
| Seattle Avenue font | `ui/fonts/seattle_avenue.otf` | Public-domain font by JLH Fonts; source record and hash in `ui/fonts/Seattle-Avenue-LICENSE.txt`. |
| Title music | `audio/music/title/as_in_four_wolves.ogg` | Original music composed and owned by co-owner Voyager. |
| Dusk music | `audio/music/world/craft.mp3` | Original music composed and owned by co-owner Voyager. |
| Fishing fight loop | `audio/sfx/fishing/fighting.wav` | Edited from “Spinning reel.wav” by Freesound user tosha73, sound 509902, CC0. |
| Manual-reeling loop | `audio/sfx/fishing/reeling.wav` | Edited from the same CC0 “Spinning reel.wav” source. |
| Saltwater wave ambience | `audio/ambience/waves.wav` | “Gentle Ocean Waves Loop” by Freesound user kkenny101, sound 852826, CC0. |
| Bobber water impact | `audio/sfx/fishing/bobber.wav` | “Quick Water Droplet” by Freesound user qubodup, sound 792931, CC0. |
| Rain ambience | `audio/ambience/rain_loop_ontario.ogg` | Converted from “Rain Loop Ontario” by Freesound user Ayton, sound 212799, CC BY 3.0. |
| Character bark call | `sound/dialogue/calls/bark.wav` | Edited from `Dog_Bark.wav` by Freesound user ivolipa, sound 328729, CC0. |
| Character meow call | `sound/dialogue/calls/meow.wav` | Edited from `Cat meow.m4a` by Freesound user Christyboy100, sound 495694, Attribution 3.0. |
| Animalese placeholder tones | `sound/dialogue/animalese/placeholder/` | Original tones composed and owned by co-owner Voyager without third-party samples. |

Creative Commons Zero information:
https://creativecommons.org/publicdomain/zero/1.0/. Creative Commons
Attribution 3.0 legal text:
https://creativecommons.org/licenses/by/3.0/legalcode.

### chillnfill 3D model contribution record

- Requested credit: `chillnfill`.
- Original contribution families: character bodies and arms; character ears
  and tails; and multiple world props and decorative assets, including trees
  and bridges.
- Repository mapping: character contributions are incorporated into the
  character source/export families identified above. Prop contributions may
  be incorporated into combined environment source and export files rather
  than retained as one file per originally supplied model.
- Permission record: because these historical contributions predate the
  current `CONTRIBUTOR-TERMS.md`, retain the original permission record or a
  later written confirmation covering Project use, modification,
  distribution, commercial release, and applicable sublicensing.

### Fur customization channel-map record

Original channel-map artwork by Endeavour. Repository paths preserve the
authored `mesh_style.png` filenames.

| Style and mesh | Source filename | Repository file | SHA-256 |
| --- | --- | --- | --- |
| Bengal spots, body and arms | `body_arms_bengal.png` | `art/exported/characters/patterns/bengal/body_arms_bengal.png` | `fa90bd4e74b0b770ce97bf69d069676f5d4bd1f5d649f89e09638a66b61a8470` |
| Bengal spots, main body | `body_main_bengal.png` | `art/exported/characters/patterns/bengal/body_main_bengal.png` | `8662fa198220cfdbe0aa83bdeeef7b855e20124d74f8481467f750d32b67ee8b` |
| Bengal spots, round head | `head_round_bengal.png` | `art/exported/characters/patterns/bengal/head_round_bengal.png` | `c464b042397f5ffe371c48a711ec3d7257adf794d363f3116cb2bddc23e444f8` |
| Fox, body and arms | `body_arms_fox.png` | `art/exported/characters/patterns/fox/body_arms_fox.png` | `fd2ab31ede371129ca4806480783d57153318a909d6b87c593b6ff82d03d65eb` |
| Fox, main body | `body_main_fox.png` | `art/exported/characters/patterns/fox/body_main_fox.png` | `d2a975cf042728299de4819a023a95e9c1467671a6886f6c6eaf8b44a5a9ca3a` |
| Fox, pointy head | `head_pointy_fox.png` | `art/exported/characters/patterns/fox/head_pointy_fox.png` | `8e74685ef7a9f61b5ae75c16e86898ea80f3996471e2999862479798ce28aa52` |
| Fox tail | `tails_fox_fox.png` | `art/exported/characters/patterns/fox/tails_fox_fox.png` | `72da9673f038e2c3bb8aca19ed99932085fa3b162cab95366901c4e97153dd3e` |

### Tekgator shop icon contribution record

- Requested credit: `Tekgator`.
- Original contributions: cooler-capacity, reel-speed, and barrier-power shop
  icons.
- Repository files and SHA-256:
  - `items/icons/equipment/64_cooler_plus.png`:
    `b63705be5b78915753c068170323781a90e22b555b57a5b2ca9466e2726539f7`
  - `items/icons/shop/64_speed_plus.png`:
    `938452798f2be505e06ce3fbef178f52459331fd3bced8763fbc2a80157125ca`
  - `items/icons/shop/64_power_plus.png`:
    `164d34ce152aa6d75de79b69f0be2d9074f7891057de9636678889028ff98ae7`
- Permission record: retain the original permission record or a later written
  confirmation covering Project use, modification, distribution, commercial
  release, and applicable sublicensing.

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
