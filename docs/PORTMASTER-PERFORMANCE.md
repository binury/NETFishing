# PortMaster performance profile

The PortMaster launcher keeps the normal game profile on unknown and stronger
hardware. It enables the low-end profile only when the Linux device tree
reports one of the identifiers used by the Allwinner H616/H700 XX handhelds:

- `allwinner,h616`
- `sun50iw9p1`
- `allwinner,sun50i-h700`

The low-end launch profile passes these options to Godot:

- `--single-window`
- `--disable-vsync`
- `--max-fps 30`
- `--audio-output-latency 40`

It also passes `NETFISHING_LOW_END=1`. The game responds by rendering the 3D
world at 75 percent linear resolution with nearest-neighbor scaling. This
reduces 3D pixel work by about 44 percent while the separately rendered UI
retains its canonical resolution.

Do not use Godot's low processor mode for this profile. It reduces idle CPU
usage by sleeping between updates and is not a game-performance optimization.

When adding another device family, record its exact NUL-separated device-tree
`compatible` value from the hardware before extending the launcher match. Do
not infer detection from a retail product name alone.
