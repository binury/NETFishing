# Contributing

NETfishing is currently developed through focused changes on the repository's
active development branch. Coordinate scope with the project owner before
starting substantial work.

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
- Record the source and license of newly imported assets.
- Do not commit `.godot/`, test data, logs, captures, or build outputs.

## Before requesting review

```sh
git diff --check
scripts/run_validations.sh quick
git status --short
```

Choose additional focused tests from [`docs/TESTING.md`](docs/TESTING.md).
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
