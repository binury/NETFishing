# Drop-in facial features

Facial feature textures are discovered when the game starts. Put new PNGs in
the matching directory, restart the game, and the option will appear in the
Profile customization page.

```text
eyes/<id>.png
noses/<id>.png
mouth/<id>.png
```

The category directory is authoritative. A category prefix is optional, so
both `sleepy.png` and `eyes_sleepy.png` become the option ID `sleepy`.
Filenames are normalized to lowercase snake_case. Use stable names because
the resulting IDs are stored in appearance snapshots and sent to peers.

Keep each PNG on the established facial-feature canvas with an RGBA
transparent background. Godot imports the PNG automatically in the editor;
the runtime registry ignores `.import` files and other non-PNG files.

The current game bundles its facial assets under `res://`. Adding a file to a
development checkout is picked up on the next startup. An exported build must
be rebuilt to include newly added `res://` files in its package.
