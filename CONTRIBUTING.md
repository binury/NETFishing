# Contribution policy

NETfishing is an owner-directed Woofmeow project and is not accepting
unsolicited contributions. Please do not submit pull requests, patches, code,
artwork, models, audio, writing, documentation, translations, designs, or
other implementation work. Pull requests are disabled for the official
repositories.

Issues remain available for reproducible bug reports and player feedback. An
Issue is not a request for contributed implementation, and attaching or
linking unsolicited work does not make it an accepted Project contribution.

The owners may occasionally invite specific work in writing before it is
created or submitted. [`CONTRIBUTOR-TERMS.md`](CONTRIBUTOR-TERMS.md) is retained
to document previously accepted contributions and govern expressly invited
work; it is not a standing invitation to contribute.

## Contribution forks

The [NETfishing Asset License](ASSET-LICENSE.md) contains limited permissions
for qualifying Contribution Forks. Those permissions do not promise review or
acceptance and do not override the policy above. Keep the hosting platform's
fork relationship visible, preserve all license and attribution notices, and
do not publish general-audience builds or use the fork as an independent game
or distribution.

Private test builds and temporary access-controlled test servers may be shared
only as allowed by that license. Permission to maintain a Contribution Fork
does not authorize unsolicited submission or obligate the owners to review it.

## Change discipline

- Keep a change focused; avoid unrelated cleanup.
- Inspect the working tree before editing and preserve existing work.
- Do not change protocol, save, settings, identity, or portable-data versions
  as release-label housekeeping.
- Treat the host as authoritative for catches, purchases, sales, jobs, mail,
  and other shared state.
- Keep presentation-only systems out of save files and network messages.
- Store runtime assets under repository-owned paths; never reference a
  workstation sync or temporary directory.
- Retain source, permission, and license evidence for newly imported assets.
  Update [`docs/ATTRIBUTION.md`](docs/ATTRIBUTION.md) when the accepted work
  adds or changes a distributed credit or third-party notice; do not add a
  file-by-file inventory of ordinary project-owned assets.
- Do not assume the GPL code license applies to project assets; observe
  [`ASSET-LICENSE.md`](ASSET-LICENSE.md) and third-party terms.
- Do not commit `.godot/`, test data, logs, captures, or build outputs.

## Before committing a maintainer change

```sh
git diff --check
scripts/run_validations.sh quick
git status --short
```

Choose additional focused tests from the validation section of
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md#validation).
Changes involving networking should run the network suite and a real
two-process check. Visual changes still require graphical review; headless
tests are supporting evidence, not a replacement.

## Commits

- Stage audited paths explicitly.
- Use a concise imperative subject that describes the outcome.
- Do not mix generated build artifacts with source changes.
- Do not rewrite published release tags.
- Describe behavior, compatibility impact, validation, and asset provenance in
  the internal review or release record.

## Style

Follow the conventions already present in the surrounding GDScript, scene, and
resource files. Prefer typed values, named constants, shared resources, and
small domain-specific services. Avoid duplicating protocol definitions or
using display strings as persistent identifiers.

New standalone source files should use `SPDX-License-Identifier:
GPL-3.0-or-later` where the file format permits comments. Do not add that
identifier to asset files governed by the NETfishing Asset License.
