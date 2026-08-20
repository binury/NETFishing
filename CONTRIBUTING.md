# Contributing

NETfishing is currently developed through focused changes on the repository's
active development branch. Coordinate scope with the project owner before
starting substantial work.

By intentionally submitting material for inclusion, contributors agree to the
applicable grants and representations in
[`CONTRIBUTOR-TERMS.md`](CONTRIBUTOR-TERMS.md). Maintainers must preserve an
affirmative record of that agreement. Contact the owners before submitting if
separate written terms are needed.

## Contribution forks

The [NETfishing Asset License](ASSET-LICENSE.md) permits a public source-control
fork to retain NETfishing assets when the fork is maintained in good faith to
prepare, test, review, or submit changes for possible inclusion in the official
project. Keep the hosting platform's fork relationship visible, preserve all
license and attribution notices, and do not publish general-audience builds or
use the fork as an independent game or distribution.

Private test builds and temporary access-controlled test servers may be shared
with people directly participating in development or review of the proposed
contribution. Submission remains subject to `CONTRIBUTOR-TERMS.md`; permission
to maintain a Contribution Fork does not guarantee that its changes will be
accepted.

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
- Record the source and license of newly imported assets in
  [`docs/ATTRIBUTION.md`](docs/ATTRIBUTION.md).
- Do not assume the GPL code license applies to project assets; observe
  [`ASSET-LICENSE.md`](ASSET-LICENSE.md) and third-party terms.
- Do not commit `.godot/`, test data, logs, captures, or build outputs.

## Before requesting review

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
  the review or release record.

## Style

Follow the conventions already present in the surrounding GDScript, scene, and
resource files. Prefer typed values, named constants, shared resources, and
small domain-specific services. Avoid duplicating protocol definitions or
using display strings as persistent identifiers.

New standalone source files should use `SPDX-License-Identifier:
GPL-3.0-or-later` where the file format permits comments. Do not add that
identifier to asset files governed by the NETfishing Asset License.
