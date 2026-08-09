# Asset provenance

This document records where runtime assets came from and what must be verified
before redistribution. A Git commit proves when bytes entered this repository;
it does not by itself prove authorship or licensing.

## Intake policy

For every new external or supplied asset, record:

- creator or supplying party;
- original source location or delivery channel;
- source filename and repository destination;
- source and destination SHA-256 when copied without modification;
- license or explicit permission;
- any permitted transformations;
- the importing commit or release.

Runtime resources must use `res://` paths. Workstation Sync folders are intake
locations only and must never appear in scenes or resources.

## Current inventory

| Asset family | Repository location | Recorded provenance |
| --- | --- | --- |
| Fish art and portraits | `fish/species/`, `art/exported/fish/` | 2D artwork by contributor Rheannon Eisworth. |
| Item icons | `items/icons/` | 2D artwork by contributor Rheannon Eisworth. |
| Inventory notepad | `art/ui/ui_notepad.png` | 2D artwork by contributor Rheannon Eisworth; integrated without a runtime external path. |
| Environment textures | `art/exported/environment/textures/` | 2D artwork by contributor Rheannon Eisworth. |
| UI patterns | `art/patterns/` | 2D artwork by contributor Rheannon Eisworth. |
| Character and world models | `art/exported/` | Original 3D models by the project owner. Any embedded 2D artwork is by Rheannon Eisworth. |
| Tuffy font | `ui/fonts/Tuffy_Bold.otf` | Public-domain dedication in `ui/fonts/Tuffy-LICENSE.txt`. |
| Seattle Avenue font | `ui/fonts/seattle_avenue.otf` | License and attribution not present; resolve before public distribution. |
| Title music | `audio/music/title/as_in_four_wolves.ogg` | Original music composed and owned by the project owner. |
| Fishing fight loop | `audio/sfx/fishing/fighting.wav` | Edited from “Spinning reel.wav” by Freesound user tosha73, sound 509902, CC0. |
| Manual-reeling loop | `audio/sfx/fishing/reeling.wav` | Edited from the same CC0 “Spinning reel.wav” source. |
| Saltwater wave ambience | `audio/ambience/waves.wav` | “Gentle Ocean Waves Loop” by Freesound user kkenny101, sound 852826, CC0. |
| Bobber water impact | `audio/sfx/fishing/bobber.wav` | “Quick Water Droplet” by Freesound user qubodup, sound 792931, CC0. |
| Character bark call | `sound/dialogue/calls/bark.wav` | Edited from `Dog_Bark.wav` by Freesound user ivolipa, sound 328729, CC0. |
| Character meow call | `sound/dialogue/calls/meow.wav` | Edited from `Cat meow.m4a` by Freesound user Christyboy100, sound 495694, Attribution 3.0. |

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

## Generated resources

Godot `.import` sidecars and deterministic shoreline `.tres` meshes are derived
repository resources, not original artwork. `.godot/imported/`, editor caches,
captures, exports, and temporary test data are not tracked.

## Release gate

Before a public binary or source release:

1. Resolve the Seattle Avenue font license and attribution gap above.
2. Record the public owner/studio credit and the contributor's redistribution
   permission in the chosen project license or release records.
3. Confirm the project-wide source/content license selected by the owner.
4. Search exported resources for external filesystem paths.
5. Preserve required third-party notices with the package.
