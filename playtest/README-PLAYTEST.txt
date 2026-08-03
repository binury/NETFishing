NETfishing
v0.3.6-prealpha
Pre-Alpha 0.3.6

Thank you for trying this early private playtest.

NETfishing is currently a local gameplay prototype for a future
multiplayer-first game. Networking and multiplayer are NOT implemented in
this build.

INSTALLATION

1. Extract the entire ZIP into a new folder.
2. Keep the executable and netfishing.pck together.
3. Launch netfishing.exe on Windows or netfishing on Linux.

Windows may show a warning for an unsigned application. This private build is
not code signed. Only run a copy received from the playtest organizer.

Linux users may need to allow execution:

    chmod +x netfishing

CONTROLS

Move                         W / A / S / D or left stick
Jump                         Space
Sprint                       Shift
Sneak                        Ctrl
Slow walk                    Alt
Rotate camera                Hold right mouse, or use right stick
Cycle active hotbar slot     Mouse wheel
Select hotbar slot           1 through 9
Zoom camera                  Shift + mouse wheel
Cast / withdraw / reel       Left mouse
Cooler, Bag, and Logbook     Tab
Game Menu / back             Escape
Open Fishing Shop            E while near the shop

FISHING

- Hold left mouse to select cast distance, then release to cast.
- The target preview shows whether the selected landing point is fishable.
- While waiting, hold left mouse to withdraw the bobber.
- A bite starts the chase automatically.
- Hold left mouse to advance the green catch meter.
- At barriers, use distinct left-click presses to damage the barrier.
- Do not let the red chase meter catch the green meter.
- Accessibility auto-click can be enabled in Settings.
- Approach the bright Fishing Shop booth and press E to open it.
- The Fishing Shop buys one Cooler fish at a time for full base value.
- Buy Coffee, Energy Drinks, Snacks, and Fish Finders as Bag supplies.
- Drag supplies from Bag to the hotbar and left-click in READY to use one.
- Coffee improves movement; other supplies temporarily improve fishing.
- The Cooler starts at 12 fish; buy permanent capacity expansions at the shop.
- Reel Speed upgrades increase authoritative green reeling progress.
- Barrier Power upgrades increase damage per valid barrier action.
- Shop upgrades persist in the local progression save.
- Escape closes shop confirmations before closing the shop itself.

FEATURES TO TRY

- Movement, jumping, camera rotation, and zoom
- Short, medium, and maximum-distance casts
- Valid water and invalid land casts
- Manual withdrawal before a bite
- Barrier-and-chase catching
- Accessibility auto-click settings
- Catch showcase and fish size variation
- Cooler, Bag, Logbook, favorites, and sorting
- Basic Fishing Rod equipment and the 1–9 hotbar
- Pelican selling and wallet updates
- Physical Fishing Shop sales and persistent fishing upgrades
- Save, Continue, New Game, and Delete Save
- Game Menu and persistent camera settings
- Water-entry recovery from several shores

SAVES AND SETTINGS

Progression and settings are stored in Godot's per-user application-data
directory, outside this extracted game folder. Delete Save removes progression
but preserves settings.

Windows:
    %APPDATA%\Godot\app_userdata\NETFISHING\

Linux:
    ~/.local/share/godot/app_userdata/NETFISHING/

This is an early save format. Keep expectations modest and report any failure
to Continue, save, sell, favorite, or retain an individual fish.

FEEDBACK

Please include:

- Your operating system and whether you used mouse/keyboard or controller
- What you were doing when a problem occurred
- Whether the issue repeated after restarting
- Screenshots or a short recording when useful
- How movement, casting, chase pressure, barrier clicking, menus, and camera
  controls felt

KNOWN PRE-ALPHA LIMITATIONS

- Multiplayer/networking is not implemented.
- Fish and character art are temporary.
- UI and balance values are placeholders.
- There is no audio.
- There is no installer or automatic updater.
- Windows builds are unsigned.
