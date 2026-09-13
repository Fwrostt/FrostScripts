# Universal

`main.lua` is the game-independent FrostScripts suite. The main library downloads it only after the player chooses the **Universal** card.

The suite exposes a curated catalog of 100 modules. It covers movement, character, camera, world, players, server, navigation, performance, fun, utility, and HUD tools while omitting duplicate presets, overlapping effect reducers, and status-only cards already covered by Home. Every toggleable feature owns cleanup, status, settings, a module-local keybind, and a Favorites shortcut.

Home exposes Flight, Noclip, Speed, Infinite Jump, Freecam, Fullbright, Anti-AFK, and FPS Boost as synchronized quick actions. A live footer and status card show FPS, ping, and active-module count; Recently Used and the command bar reduce navigation. Mobile Mode provides touch movement, rise/drop, drag-to-look, and the same eight toggles.

Player ESP & Nametags combines always-on-top highlights, display names, optional usernames, health values and bars, distance, team information, teammate filtering, maximum range, colors, opacity, text size, and refresh rate. Auto Walk runs after Roblox controls and reinforces movement with a forward walk target. Anti-AFK uses immediate and periodic virtual-input keepalives in addition to the idle event.

Runtime work is consolidated through one update manager (render, heartbeat, 0.1-second, and telemetry buckets) and one character manager. Respawn-sensitive modules reacquire the current humanoid/root, while disable and unload paths restore changed properties and destroy local instances.

`icon.png` is the library banner. Keep future replacements lowercase and under 4 MB; the catalog uses `ScaleType = "Fit"` so the whole panoramic design remains visible.
