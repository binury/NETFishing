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
  `audio/music/world/craft.mp3`, and the synthesized robot animalese tones.
- Endeavour: co-owner, developer, and creator of the game's 2D art, including
  the original fish, environment, UI, and other artwork.
- chillnfill: contributor of original 3D models for the character bodies and
  arms, ears and tails, and multiple world props and decorative assets,
  including trees and bridges. The contributor requested to be credited as
  `chillnfill`.
- adamantris: contributor of the original hand-net model and texture artwork;
  the contributor is credited as `adamantris`.
- Tekgator: creator of the cooler-capacity, reel-speed, and barrier-power shop
  icons.
- kat: supplied the original recorded voice sample used for the animalese
  alphabet and number sounds.
- kim: supplied the recorded voice performance used for the kim animalese
  alphabet and number sounds.

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
| Hand-net model | `art/source/items/equipment/net.blend`, `art/exported/items/equipment/net.glb`, and adjacent exported textures | Original model and texture artwork by adamantris; repository adaptation and rigging by Voyager. |
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
| Animalese alphabet and number sounds | `sound/dialogue/animalese/alphanumeric/` | Processed derivatives of the original recorded voice sample supplied by NETfishing community member kat. |
| Kim animalese alphabet and number sounds | `sound/dialogue/animalese/kim/` | Processed per-character voice samples supplied by NETfishing community member kim. |
| Robot animalese tones | `sound/dialogue/animalese/robot/` | Original synthesized tones composed and owned by co-owner Voyager without third-party samples. |

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

### adamantris hand-net contribution record

- Requested credit: `adamantris`.
- Original contribution: hand-net model and texture artwork.
- Repository source: `art/source/items/equipment/net.blend`, SHA-256
  `4608993b2397681029c60eb6a7657e3db311ded99ebb5a461cdf4738c8858b39`.
- Repository export: `art/exported/items/equipment/net.glb`, SHA-256
  `d4c2d4903da3817ff9bb82e0404f5e51b74d299abc5bef28c7f6daf6371474fb`.
- Repository adaptation: reshaping and the generic `net_root`, `net_rim`,
  `net_mid`, and `net_tip` deformation rig were prepared by Voyager for
  reuse across gathering activities.
- Permission record: retain the original submission correspondence or a
  written confirmation accepting `CONTRIBUTOR-TERMS.md` with the project
  records.

### Fur customization channel-map record

Original channel-map artwork by Endeavour. Repository paths preserve the
authored `mesh_style.png` filenames.

| Style and mesh | Source filename | Repository file | SHA-256 |
| --- | --- | --- | --- |
| Bengal spots, body and arms | `body_arms_bengal.png` | `art/exported/characters/patterns/bengal/body_arms_bengal.png` | `fa90bd4e74b0b770ce97bf69d069676f5d4bd1f5d649f89e09638a66b61a8470` |
| Bengal spots, main body | `body_main_bengal.png` | `art/exported/characters/patterns/bengal/body_main_bengal.png` | `8662fa198220cfdbe0aa83bdeeef7b855e20124d74f8481467f750d32b67ee8b` |
| Bengal spots, round head | `head_round_bengal.png` | `art/exported/characters/patterns/bengal/head_round_bengal.png` | `f397ed8d152e3fda8181757a2bbd01925b7b8c2c4362f515d91c7f0fbf3ddfb6` |
| Calico, main body | `body_main_calico.png` | `art/exported/characters/patterns/calico/body_main_calico.png` | `25b2389ee729a6bafafbe6b5440541b18f3c5db2808ca8d49c2d5c4d012d390c` |
| Fox, body and arms | `body_arms_fox.png` | `art/exported/characters/patterns/fox/body_arms_fox.png` | `9930808718f31d84b415902f1ba55ac2a508bb2ac127300e793d73a8a013022d` |
| Fox, main body | `body_main_fox.png` | `art/exported/characters/patterns/fox/body_main_fox.png` | `c65e4390173b8c31c9396edd053f940f0f809e47e01d18042cd7babc712dde9d` |
| Fox, short pointy ears | `ears_pointy_short_fox.png` | `art/exported/characters/patterns/fox/ears_pointy_short_fox.png` | `13cb35192d25c0136df287434fa056ce990698fc47dc50445c941f92a4ff42fb` |
| Fox, pointy head | `head_pointy_fox.png` | `art/exported/characters/patterns/fox/head_pointy_fox.png` | `71a9d2383e62884dbd3981460fcd985b18805fa907f61ffb16dce08ff9418ddf` |
| Fox, round head | `head_round_fox.png` | `art/exported/characters/patterns/fox/head_round_fox.png` | `1ac3d503bc1e47a5ae3c1a8af719c9d1be06aab2d6d4d30c179c2a021fe7d34d` |
| Fox tail | `tails_fox_fox.png` | `art/exported/characters/patterns/fox/tails_fox_fox.png` | `72da9673f038e2c3bb8aca19ed99932085fa3b162cab95366901c4e97153dd3e` |
| Paws, body and arms | `body_arms_paws.png` | `art/exported/characters/patterns/paws/body_arms_paws.png` | `38f31ecf7045510501bdd08cbc243065c2fadec481462671dd22b13e8a196e66` |
| Paws, main body | `body_main_paws.png` | `art/exported/characters/patterns/paws/body_main_paws.png` | `d52012d4a1ea3ed544582be714469ed8fec148ccd59417dda21e89c18509321b` |
| Stripes, main body | `body_main_stripes.png` | `art/exported/characters/patterns/stripes/body_main_stripes.png` | `4b1e5b412a7af3e6acd0a5bfb1b6ffd6e0814850a311fc8cc3061419a8f23555` |
| Tiger, main body | `body_main_tiger.png` | `art/exported/characters/patterns/tiger/body_main_tiger.png` | `64b6f47871802e72ba6fe15577f14949a760c6d44bb962bfbbdcddc991b2105b` |
| Tiger, round head | `head_round_tiger.png` | `art/exported/characters/patterns/tiger/head_round_tiger.png` | `6af27056b9827391a73b4ea6f3736b308fa93a03127570f90cc4d3701afd3d80` |
| Tummy, main body | `body_main_tummy.png` | `art/exported/characters/patterns/tummy/body_main_tummy.png` | `dad404614c3feae4082537c02556781ea46c664327e0dc4528804f76619af86a` |

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

### kat animalese voice contribution record

- Requested credit: `kat`.
- Original contribution: the recorded voice sample used to produce the
  animalese alphabet and number sounds.
- Repository mapping: the heavily processed per-character derivatives are in
  `sound/dialogue/animalese/alphanumeric/`.
- Intake filenames: `0.wav` through `9.wav` and `a.wav` through `z.wav`.
- Source and initial repository files were compared byte-for-byte at intake.
  The hashes below identify those untouched intake files; runtime files are
  normalized derivatives produced by `scripts/import_animalese_voice.sh`.
- Permission record: retain the original submission and permission record
  covering Project use, processing, distribution, commercial release, and
  applicable sublicensing.

| Clip | SHA-256 | Clip | SHA-256 |
| --- | --- | --- | --- |
| `0.wav` | `0616a2fb035d410f24403e66c4fe46e9ff86e976126db16c56125af28bbe5ad6` | `a.wav` | `aa701de9370000e620dae16c4e3082bc79fc9692ed5260dfd5f4f2480b556e75` |
| `1.wav` | `e29191c0b4011d4237710b0ef4fe1f0ebe875bb3cf8abb62b057b7799c683dda` | `b.wav` | `149286a210d4fec9197f4c6109a066706cb890181b6663369a9941435ee859bb` |
| `2.wav` | `e4ce823498ec8440b2f870ea767b1b6185add948a3ba573ec476794fc6ab5abb` | `c.wav` | `4776bb64044e82f21755e771f31e30e18e8737533b08f04a9bd5103aa9adf923` |
| `3.wav` | `498a06196dd672f273c90802d0349f3ecc5f582a1aeb9b952ff54030bef523e0` | `d.wav` | `6bb00d354b5a621895412ae40a40f02f219976fc164b08389a6bb708a6c99e84` |
| `4.wav` | `dbb90d8e7e5cb9524cfd429d63e297548871ed6dda7c2594c5ea4e932c623754` | `e.wav` | `232edabddc6c046ba5bbb5f640cabe9c9a905c2a12cec07fc60ef657e83547c4` |
| `5.wav` | `dc6dc2946e0ebb5b346bbf4c646c72e27303f4bf8838c14038df5ce7087071f9` | `f.wav` | `f104a52c97605872de4cafab1f1c24a132051e14a9400c2098a24385525f1e15` |
| `6.wav` | `8dae2ce33aaa0d788964d0a7026d3c51738ef2b06672697675a7f2da0f9f7a59` | `g.wav` | `12915a19a9c3b0f1559a4c53734c16fedc1d82f7c24adce08608aad7da141968` |
| `7.wav` | `f5c5c855b06794a22954f3eb2b32f2caec877ce7dee27fd3153c7aa65ab1ff92` | `h.wav` | `951a2c1b074eb43c8016d592ed7d1bc63ec64ab95312d122fa8f2e717b61c1e1` |
| `8.wav` | `b31561b5e3748024daf109510d5ee955274d2ef45f7fed96882f8a4862b70e30` | `i.wav` | `1d51b902b1b667eadc7bcc569909ce927075e7b91b8a02ea811f361e3e95164c` |
| `9.wav` | `e46bb34cb045fb15bb0cbbfbd9364895521ee3c441290154a1f4ff67ffd38f2d` | `j.wav` | `9ef84e992d58349b42f642901688f49203af27dda85c5baee30b4c2cf93944c9` |
|  |  | `k.wav` | `65ae2072c6f55b5013dea21dd4644c2dd502963b89f5711eb22f741cee3dec09` |
|  |  | `l.wav` | `d87f8fcb4c217c0dbd5526705c982655e514a5645ef2391557b6c033344aa713` |
|  |  | `m.wav` | `1f1bc0ba3abe077febfa035e873d0e47838e880fbbd6e10164b1e58e13a5e47b` |
|  |  | `n.wav` | `2f422e00c4c42689e0d50adf2226c28a851960f3c460b2c8cdbbefb687175ad1` |
|  |  | `o.wav` | `70143fd697e1b1d1f1d27c8fc3bd59ea72e076e1679494f8022a44911752da46` |
|  |  | `p.wav` | `9419172ec8a595f89ac2993f4a942c554dc5a8fa64bd8a75f468718cdb2b176e` |
|  |  | `q.wav` | `e0117043020c0eda1d15f1315b7796774a219c1439bafc587c01e3661215abbb` |
|  |  | `r.wav` | `31f9a4a06975c55331b830247b39f47572622698457c191d03c92d02599b1131` |
|  |  | `s.wav` | `232edabddc6c046ba5bbb5f640cabe9c9a905c2a12cec07fc60ef657e83547c4` |
|  |  | `t.wav` | `a8b7379fa5c26462bde6e51cd74edb514aa731afa02efb5f82b42341c5a50964` |
|  |  | `u.wav` | `e25dec74b9f141203c92c4a8ebf296c80e031cc677d924656bef64e90a02c7a3` |
|  |  | `v.wav` | `643725a16a9e821a5e8a502aa43979a9f9ed73860839d28cf15b4b3fb4ff3539` |
|  |  | `w.wav` | `5a915415157775f00875b4985844a1cd28f36733744dbe718fdf8b714f1ccc89` |
|  |  | `x.wav` | `04fc26436d1524c5fb6e7f84c2a1a930aa519a57f594b73e7310c7187ac581c3` |
|  |  | `y.wav` | `7fbe3ee4f2a6c6432b8cbeeffe2cc422b3b960e0f148533ffcc0d42d73804f9c` |
|  |  | `z.wav` | `0616a2fb035d410f24403e66c4fe46e9ff86e976126db16c56125af28bbe5ad6` |

### kim animalese voice contribution record

- Requested credit: `kim`.
- Original contribution: the recorded voice performance used to produce the
  kim animalese alphabet and number sounds.
- Repository mapping: the per-character samples are in
  `sound/dialogue/animalese/kim/`.
- Intake filenames: `0.wav` through `9.wav` and `a.wav` through `z.wav`.
- Source and initial repository files were compared byte-for-byte at intake.
  The hashes below identify those untouched intake files; runtime files are
  normalized derivatives produced by `scripts/import_animalese_voice.sh`.
- Permission record: retain the original submission and permission record
  covering Project use, processing, distribution, commercial release, and
  applicable sublicensing.

| Clip | SHA-256 | Clip | SHA-256 |
| --- | --- | --- | --- |
| `0.wav` | `cd107c5904569c87fb972dce3853e02d126d1d1fe61b16596a2e40b6c5ffa4c1` | `a.wav` | `037dde81eaae9d11b316a0336a2cf39090810afcb8e6a3349af674808a7b6a92` |
| `1.wav` | `4e2310d7af7912d7bf88dbe0b1b864bd491b412dfb46e28e8dbf7fc77d2b839e` | `b.wav` | `09e82faa88e7be9d3d9b984288f001cf722ba9c29f7a422053c90641e2406ff4` |
| `2.wav` | `ed54c8edc36b80e696a45e4eaefe724b714fa949a01af09d66ec4b8af4538dda` | `c.wav` | `8f8bf82630511d510042918389473a6bcb0c71173dc4bbfaaef0ec64c77a8b34` |
| `3.wav` | `41f6b3e0d30384c790ca625ab049826f2cf33aaca4b3bfbbbb833bfbd84d86c9` | `d.wav` | `ccf55a87158896e233afb3c3be517b92f97af92a8d972a8fc8f1ce88a418ec7c` |
| `4.wav` | `d9345022c32fc03f382d892d2ec105a3200c787dfac5357c8c192377b01b7816` | `e.wav` | `d62935c4d90cabc1fc789eab22da1aae205383ba5063b1d923ae3165bb231b92` |
| `5.wav` | `3ea7659d6d1bdc2cf6d5e9131d983ce27ec715d5a27923f141a9e8123f413551` | `f.wav` | `4a7957d71c3e287a94f94b40f77c631e41b9b885bbd968aee60b66e789f5fb65` |
| `6.wav` | `a91e64bccc07162cefaf1c59f838e4475e8ba40efcb749e965f87903f03c2a0d` | `g.wav` | `8fe9f4aa5a3c1f61860c9ef371674e9d3ce117fe222612465d2c7531367294e8` |
| `7.wav` | `e4e2e85f88625e152ff682c45ce816e7ec3fc15eb23ed01c686528f9abfa1015` | `h.wav` | `88a758b4f1e2a90758f93c72b15804b38152e3e8cf6b0b67558823d52e0a0648` |
| `8.wav` | `da94b98ef5bcf7460d3c9ca02b651f586b51ef2809f33da639898f81253e16a4` | `i.wav` | `f272e24648bbf62b09c83743b53c94168e81a90a8d3fff2aa0ba5a727927f494` |
| `9.wav` | `34aa49af5f8414bff289cb575468bef2745b3f6d0ac3420d9eb07ec148cdd645` | `j.wav` | `f25e1585e28313f63bcad0fe3c9a0032c96a32754687e592ea4f1989edfb3411` |
|  |  | `k.wav` | `3c39ede36a423577d75772ba5c1b7f1a4315aac0b5dea89fa6cd7ac647f4c342` |
|  |  | `l.wav` | `beda782f9b1de5e82e0f7c481f3e7a5694ead7c72ccabc684a7c330234b7ad7c` |
|  |  | `m.wav` | `b4002b6dc895896144711cf8a763cdc93d11d9bc74b0b57fbc55831ec3dbf28d` |
|  |  | `n.wav` | `d5e989ab8cc755cd8676fe05ec3e5b8e433d674694188df3717e3073bd27975b` |
|  |  | `o.wav` | `043e5f81a29400a4b8078168c187c0e0907ea43041c96be98b2bdf646afc0f61` |
|  |  | `p.wav` | `da228b88d1621a09b21b3a5e5ea57710fab0a726ef9655406b43da30cd67c6d4` |
|  |  | `q.wav` | `83cb2e061fa8473e9205d03b353c1d8a3c6cb26913b287571205033ce95e0c99` |
|  |  | `r.wav` | `4d58f4337a62d0b37b5cea427a22dc05f2b1cab505d6de6fa1d7d8363ee018d4` |
|  |  | `s.wav` | `93a19e046764af830fc5582f8de3b35b287eea2bc3abf0b269aa0e945405d95c` |
|  |  | `t.wav` | `c7b1f1d967736c3b640fab88fa4522ca6bec86fc96f2980c3948788c3d9ede9c` |
|  |  | `u.wav` | `320a3d89c0ad22cf4249d9647bedbb882e8ca561feb651eb7534f2ea51380c54` |
|  |  | `v.wav` | `8ed8d00aaf3f60531680241f65f45251639080258799698e81afce996ba506af` |
|  |  | `w.wav` | `edad2171e9b4238a20b8c3d6675b5ab457be0af0450f37950bc6d70215f9def7` |
|  |  | `x.wav` | `93896a36adeaf8628c18597957e86804c98115b40f41f7ea2d139ba9bf172da8` |
|  |  | `y.wav` | `9bde2a148b881ef04003286351cb7801fd65276d56b00433921bf7f42aa4d1ab` |
|  |  | `z.wav` | `cd107c5904569c87fb972dce3853e02d126d1d1fe61b16596a2e40b6c5ffa4c1` |

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
