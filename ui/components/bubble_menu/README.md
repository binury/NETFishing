# Bubble menu authoring

Instance `bubble_button.tscn` for each action, or attach `bubble_button.gd`
to an existing Button. Set its neutral size, desktop and compact anchors,
font-size limits, and deterministic motion values in the Inspector. A label
child can be assigned through `label_control_path` when wrapped text is needed.
Text size is calculated once per layout from the neutral smaller dimension and
the profile ratio.

Place the buttons under a Control using `bubble_cluster.gd`. Give the cluster
the ordered BubbleButton references with `configure()`, then call
`apply_layout()` when its available size or responsive layout changes. The
button order defines explicit keyboard and controller focus neighbors. Compact
anchors and minimum sizes remain authored per button.

The shared profile owns the palette, rounded styles, proportional-font ratio,
hover response, and contact tuning. Labels, actions, sizes, anchors, per-button
motion, responsive wrapping, availability, and confirmation behavior remain
owned by the menu. Connect each Button's `pressed` signal in that parent menu.

`motion_scale` defaults to `1.0`. Setting it to `0.0` removes idle drift and
deformation while retaining hover and focus feedback.

Contact is a deterministic, bounded visual correction around authored anchors.
Real physics is intentionally avoided so layouts, focus order, and hit targets
remain stable.
