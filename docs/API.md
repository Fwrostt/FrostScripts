# FrostScriptsAPI 2.0

The API returns a table from `loadstring(source)()`. Game methods and remotes stay in their respective `games/<name>/main.lua` files. The shared API does not import either game until explicitly requested.

## Loading

| Method | Result |
| --- | --- |
| `Configure({ BaseUrl })` | Validates this repository's raw GitHub branch/commit URL and clears the module cache. HTTPS only. |
| `GetConfig()` | Copy of current configuration. |
| `LoadModule(path, expectedMethod?, fresh?, ...)` | Downloads, compiles and executes a repository-relative `.lua` file through `loadstring`; validates its returned table. Additional arguments are passed to the chunk. |
| `LoadUI()` | Fresh UI library from `dist/ui/UI.lua`, isolating theme state between game suites. |
| `RunGame(name)` | Unloads the previous suite, loads the chosen catalog entry, and returns its suite with `Unload()`. |
| `GetGames()` | Copy of supported game IDs. |
| `GetCatalog()` | Deep copy of card metadata from `config/Scripts.lua`. |
| `OpenLauncher()` | Opens the script library without running a game. |
| `UnloadGame()` | Unloads the active suite. |

Failed loads do not poison the cache. A fresh load bypasses the cache. Execution errors include the module path. The one launcher at `dist/launchers/Loader.lua` requires API version `2.0.0`.

## Features and cleanup

`API.CreateFeature(name, settings)` returns a feature with `Enabled`, `Settings`, `Status`, `NextRun` and a cancellation generation `_token`.

| Method | Purpose |
| --- | --- |
| `AddSetting(key, default)` | Adds a missing setting, preserving existing false values. |
| `SetSetting(key, value)` | Changes an existing setting and calls `OnSettingChanged(self, key, value)`. |
| `Enable()` / `Disable()` / `SetEnabled(value)` | Idempotent lifecycle. Failed startup rolls back, disconnects tracked listeners, and records a status. |
| `SetStatus(text)` | Updates status and the bound UI control. |
| `Track(connection)` / `ClearConnections()` | Owns and disconnects feature listeners. |
| `BindControl(module)` | Syncs the UI without replacing lifecycle callbacks. |
| `Destroy()` | Disables, clears connections, and releases the control. |

Define lifecycle hooks with colon syntax: `function feature:OnEnable(token)`, `function feature:OnDisable()`, and `function feature:OnSettingChanged(key, value)`. Observers use plain functions: `feature.OnStateChanged = function(enabled)` and `feature.OnStatusChanged = function(status)`.

Long-running work must check `self.Enabled` and `self._token == token` after yielding. Shared features do not automatically run a `Tick`; the game owns its scheduler.

`API.CreateScope()` owns connections, destroyable objects, or cleanup functions. `scope:Track(item)` returns the item; `scope:Destroy()` cleans in reverse order exactly once, including resources tracked after closure.

## Universal modules and helpers

- `UniversalModules.CreateFlight({ Name, Speed, VerticalSpeed, ToggleKey, UpKey, DownKey, IsInputCaptured })`
- `UniversalModules.CreateAutoClicker({ Name, ClicksPerSecond, ToggleKey, IsInputCaptured })`
- `GetCharacter(player?)` returns character, humanoid, root.
- `GetPosition(object)` accepts a part, attachment, model, descendant container, or Vector3.
- `DistanceToPlayer(object, player?)` returns distance or infinity if unavailable.
- `FormatNumber(value, compact?)` and `FormatDistance(value)` format display text.

The clicker also exposes `feature:Click()` for one click through the same input checks. It returns success and an optional error message. A paused click (typing, manual click held, or input captured) returns success without sending input.

## UI library

`UI.new(options)` creates a window. Window options include `Name`, `Game`, `GuiName`, `OverlayName`, `Animations`, `SizePreset`, `TextScale`, `DimAmount`, `MonitorWidth`, and `MonitorSide`.

Use `window:AddTab(name, icon, subtitle)` (emoji icons are supported; legacy H/L/S/M/C icons map to emoji). Library, Modules, and Controls show search by default; other pages hide it. Set `tab.SearchEnabled` to override and select the tab again to refresh its toolbar. Then `tab:AddModule(options)`. Modules support `AddToggle`, `AddSlider`, `AddDropdown`, `AddMultiDropdown`, `AddNumberInput`, `AddButton`, `AddParagraph`, `AddColorPicker`, and `AddKeybind`. Shortcuts belong inside their owning modules. Pass a feature as `options.Feature` to bind its UI state.

Window methods include `SelectTab`, `Toggle`, `SetVisible`, `SetAnimations`, `SetSizePreset`, `SetTextScale`, `SetTheme`, `SetThemeColor`, `GetThemeNames`, `AddClientSettings`, `Notify`, `SetMonitor`, `HideMonitor`, `AddWorldMarker`, and `Destroy`.

`SetSearch(text)` matches words against the current tab's module names, descriptions, and control labels. `SetActiveOnly(boolean)` filters that tab to enabled modules. `Ctrl K` focuses search; Escape clears focused search or closes an option menu. Hidden windows can be reopened through the floating F button. `Theme` is an optional creation setting. A new `API.LoadUI()` call gives each suite its own UI factory; windows created from the same factory share its theme palette.

## Migration from the original files

`UI.CreateFeature`, `UI.Feature`, and `UI.UniversalModules` moved to `API.CreateFeature`, `API.Feature`, and `API.UniversalModules`. The only player launcher is `dist/launchers/Loader.lua`; edit `games/<name>/main.lua`. UI control methods remain on the UI library. All prior external paste-host loading has been removed.

## Script library and UI preferences

`tab:AddScriptCard(entry, callback)` creates a searchable catalog card from the documented [catalog format](CATALOG.md). It returns `SetLaunchState(state, detail)` and `SetLaunchEnabled(enabled)` controls. Optional image IDs are normalized by `UI.ImageContent(image)`.

`API.UIState` contains UI preferences only. API-created windows share this table; the library stores it in the client session so it survives reopening and switching games. `window:ApplyPreferences()` reapplies values and updates preference controls. No player filesystem is used.

Additional UI methods: `SetBackgroundEffects(enabled)`, `SetBackgroundAnimations(enabled)`, `SetSounds(enabled)`, `SetSoundVolume(0..1)`, `SetNotifications(enabled)`, and `PlaySound(kind)`. `SetAnimations(false)` also stops ambient motion. Ambient effects disconnect while hidden or destroyed. `window:AddClientSettings(tab)` creates only interface controls, including the window visibility shortcut.

The launcher passes a return-to-library callback to game windows. Module keybinds are configured with `module:AddKeybind({ Name, Get, Set, OnPressed, AllowClear })`. Escape cancels rebinding; Backspace clears an optional binding. Game-specific marker settings and shortcuts remain in game modules.
