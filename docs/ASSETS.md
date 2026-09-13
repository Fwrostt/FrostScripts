# UI image assets

Navigation is defined in [src/ui/Icons.lua](../src/ui/Icons.lua). Home uses a recognizable public Roblox image, while Library, Modules, UI Settings, and the Frost crystal mark use crisp native UI shapes. There are no SVG files or icon fonts in the navigation.

The custom system-style pointer lives at [assets/cursors/middle-finger.png](../assets/cursors/middle-finger.png). It is downloaded from raw GitHub through `FrostScriptsAPI.ResolveAsset`, then registered with the same validated `writefile` and `getcustomasset` image bridge used by game covers. The **Middle finger cursor** toggle under **Window & overlays** controls it. The normal Roblox cursor is restored whenever the option is disabled, the UI is hidden, or FrostScripts unloads.

Script cover art remains optional. Upload a `png`, `jpg`, or `jpeg` cover beside the game's `main.lua` as described in [CATALOG.md](CATALOG.md).
