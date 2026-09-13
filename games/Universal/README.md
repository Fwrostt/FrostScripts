# Universal

`main.lua` is the game-independent FrostScripts suite. The main library downloads it only after the player chooses the **Universal** card.

The base currently includes flight, walk speed, jump power, infinite jump, noclip, auto clicker, fullbright, anti-AFK, local effect reduction, and server rejoin controls. Each toggleable feature keeps its settings and shortcut inside its own module and restores the client state it changed when disabled.

`icon.png` is the library banner. Keep future replacements lowercase and under 4 MB; the catalog uses `ScaleType = "Fit"` so the whole panoramic design remains visible.
