# Edit UI text

Edit **[config/Text.lua](../config/Text.lua)** on GitHub. Change the right-hand values, keep the bracketed original-text keys unchanged, commit to `main`, then rerun the loader. **Text-only changes do not need a build.** The main loader fetches this file through GitHub `loadstring` each session.

```lua
Shared = {
    ["Library"] = "My script hub",
    ["YOUR SCRIPT LIBRARY"] = "FROST COLLECTION",
    ["Pick your world. Make it yours."] = "Choose a game to get started.",
    ["Launch script"] = "Open workspace",
    ["Grass Cutter"] = "My Grass Cutter",
    ["%d scripts in your collection"] = "%d scripts available",
},
GrassCutter = {
    ["Welcome back"] = "Welcome to Grass Cutter",
    ["Flight speed"] = "Flying speed",
},
```

Edit the existing entries rather than replacing the whole file with this example. `Shared` covers branding, navigation, library titles/descriptions, search, theme names, settings, buttons, notifications, and keybind labels. `GrassCutter` and `NeedleInHay` contain game-specific control labels, descriptions, status messages, and overlays. Game-specific values override Shared entries with the same key.

Keep dynamic placeholders (`%s`, `%d`, `%.2f`) in the same order. For example, `["Toggle %s"] = "Shortcut for %s"` changes every module's keybind caption. `\n` starts a new line. Do not rename the left-hand keys or internal catalog IDs/settings in the game scripts to change their visible labels.

Translations apply only to displayed text. Tab routing, theme selection, dropdown values, shortcuts, and feature settings keep their original internal IDs. Search uses the edited module/control names. An invalid or unavailable Text.lua falls back to the built-in English strings so a bad edit does not stop the loader.

Adding scripts, changing their entry paths, and UI behavior still use `config/Scripts.lua`, `config/UI.lua`, and the normal build workflow. Images use `games/<GameFolder>/icon.png` (or `.jpg`/`.jpeg`); see [CATALOG.md](CATALOG.md). SVG icon sources live in `assets/icons/` and require a rebuild after editing.
