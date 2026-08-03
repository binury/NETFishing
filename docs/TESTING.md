# Testing

NETfishing validations are Godot `SceneTree` scripts. They use assertions and
exit nonzero on failure. Run them with isolated user data so development checks
cannot touch real saves, identity, trust, relationships, or settings.

## Consolidated runner

```sh
scripts/run_validations.sh quick
scripts/run_validations.sh full
scripts/run_validations.sh host
scripts/run_validations.sh network
scripts/run_validations.sh all
scripts/run_validations.sh --list
```

- `quick` runs deterministic content and domain validations.
- `full` adds socket-free scene/runtime checks suitable for headless execution.
- `host` runs single-process authoritative-host checks that bind a local UDP
  port.
- `network` runs the loopback host/client validations in pairs.
- `all` runs `full`, `host`, and then `network`.

Set `GODOT_BIN` to select another executable. Set `TEST_TIMEOUT_SECONDS` to
change the per-process timeout. The runner creates one temporary XDG root per
process and removes it on exit.

## One focused test

```sh
test_root="$(mktemp -d)"
XDG_DATA_HOME="$test_root/data" \
XDG_CONFIG_HOME="$test_root/config" \
godot --headless --path . --script tests/fish_catalog_content_validation.gd
rm -rf -- "$test_root"
```

Do not set `NETFISHING_DATA_DIR` to an arbitrary empty folder: that variable is
an explicit portable-data override and must point at a valid NETfishing data
root. Isolating XDG paths is sufficient for the validation scripts.

## Graphical checks

Headless tests cannot prove visual alignment, actual mouse routing, shader
appearance, controller feel, or window-resize behavior. Presentation changes
need a real graphical startup with isolated XDG roots and inspection at the
canonical 1280×720 layout plus relevant low/high and ultrawide resolutions.

## Network checks

Host and paired tests bind loopback UDP ports defined in their scripts. Ensure
no old Godot validation process is holding those ports and that the execution
environment permits local sockets. The runner starts paired hosts before their
clients and requires both processes to exit successfully. Network tests do not
contact external servers.

## Release checks

A release audit additionally includes clean Git/tag verification, editor import,
export-template checks, platform exports, executable smoke tests, archive
inspection, and SHA-256 verification. Those checks are intentionally not hidden
inside the development runner.
