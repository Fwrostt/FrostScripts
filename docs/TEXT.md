# Edit UI text

Edit **[config/Text.lua](../config/Text.lua)** on GitHub. The small `Editable` table at the top contains named variables for branding, library headings, subtitles, search, card actions, and both script cards. Change a quoted value, commit to `main`, then rerun the loader. **Text-only changes do not need a build.** Fresh loader runs add a cache-busting query so Roblox does not reuse an older GitHub copy.

```lua
local Editable = {
    BrandName = "FrostScripts",
    BrandTagline = "Cheating is Fun",
    LibraryHeading = "YOUR SCRIPT LIBRARY",
    LibraryTitle = "Library",
    LibrarySubtitle = "Pick your script according to your game.",
    SettingsTitle = "UI Settings",
    SettingsSubtitle = "The look, motion, and sound of FrostScripts",
}
```

Edit the existing variables rather than replacing the whole file with this example. The `ADVANCED TEXT` section still contains every module, control, notification, status, and overlay label. Game-specific values override Shared entries with the same key.

Keep dynamic placeholders (`%s`, `%d`, `%.2f`) in the same order. For example, `["Toggle %s"] = "Shortcut for %s"` changes every module's keybind caption. `\n` starts a new line. In the advanced section, change right-hand values only.

Translations apply only to displayed text. Tab routing, theme selection, dropdown values, shortcuts, and feature settings keep their original internal IDs. Search uses the edited module/control names. An invalid or unavailable Text.lua falls back to the built-in English strings so a bad edit does not stop the loader.

Adding scripts, changing their entry paths, and UI behavior still use `config/Scripts.lua`, `config/UI.lua`, and the normal build workflow. Images use `games/<GameFolder>/icon.png` (or `.jpg`/`.jpeg`); see [CATALOG.md](CATALOG.md). Navigation badges are native UI shapes; see [ASSETS.md](ASSETS.md).
