# Universal

`main.lua` is the game-independent FrostScripts suite. The main library downloads it only after the player chooses the **Universal** card.

The suite intentionally stays between 100 and 200 modules. It covers movement, character, camera, world, players, server, navigation, performance, fun, utility, and HUD tools without manufacturing hundreds of placeholder entries. Every toggleable feature owns cleanup, status, settings, a module-local keybind, and a Favorites shortcut.

Home exposes Flight, Noclip, Speed, Infinite Jump, Freecam, Fullbright, Anti-AFK, and FPS Boost as synchronized quick actions. A live footer and status card show FPS, ping, and active-module count; Recently Used and the command bar reduce navigation. Mobile Mode provides touch movement, rise/drop, drag-to-look, and the same eight toggles.

Runtime work is consolidated through one update manager (render, heartbeat, 0.1-second, and telemetry buckets) and one character manager. Respawn-sensitive modules reacquire the current humanoid/root, while disable and unload paths restore changed properties and destroy local instances.

`icon.png` is the library banner. Keep future replacements lowercase and under 4 MB; the catalog uses `ScaleType = "Fit"` so the whole panoramic design remains visible.
