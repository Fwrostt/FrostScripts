# FrostScripts

A shared Luau API and UI toolkit, with independent game suites. Each launcher runs only its named game. There is no cross-game auto-detection or combined game payload.

The UI includes an ice-blue Frost theme, a responsive sidebar, module search (`Ctrl K`), an Active filter, searchable option menus, larger touch targets, dismissible notifications, and a floating reopen button. Appearance settings include four themes, custom colors, text size, and reduced motion.

## Launch

Run the matching entry point in a client environment that provides `loadstring` and `game:HttpGet`:

HTTP loading requires publicly readable source files. Private GitHub repositories return 404 to unauthenticated clients. While this repository is private, use the local development instructions below; the same API and game scripts are still executed through `loadstring`.

```lua
-- Grass Cutter
loadstring(game:HttpGet("https://raw.githubusercontent.com/Fwrostt/FrostScripts/main/dist/launchers/GrassCutter.lua"))()
```

```lua
-- NeedleInHay
loadstring(game:HttpGet("https://raw.githubusercontent.com/Fwrostt/FrostScripts/main/dist/launchers/NeedleInHay.lua"))()
```

The launcher downloads `dist/api/FrostScriptsAPI.lua` through `loadstring`. The API loads the UI and only the selected game's entry point. Use the correct launcher while inside its game. These entry points are not ordinary Studio LocalScripts; standard Roblox clients do not expose the required execution capabilities.

## Project layout

```text
src/api/                Shared loader, utilities, feature lifecycle, universal modules
src/ui/                 UI controls and responsive window shell
src/loader/Bootstrap.lua Shared launcher source
games/GrassCutter/       Grass Cutter logic and UI bindings
games/NeedleInHay/       NeedleInHay logic and UI bindings
tools/                  Build and verification commands
tests/                  API regression tests
examples/UIGallery.lua   Game-independent control gallery
docs/                   API contract and manual UI verification
dist/api/               Generated FrostScriptsAPI.lua
dist/ui/                Generated UI.lua
dist/launchers/         Generated GrassCutter.lua, NeedleInHay.lua, and Loader.lua
```

Edit `src/` and `games/`, then run `python tools/build.py`. Commit the generated `dist/` files with their sources so raw URLs work without a build server.

The project root contains documentation and configuration only. All scripts live in subdirectories; project checks enforce this. `BaseUrl` and `LocalRoot` still point to the project root.

## Shared API

```lua
local base = "https://raw.githubusercontent.com/Fwrostt/FrostScripts/main"
local API = loadstring(game:HttpGet(base .. "/dist/api/FrostScriptsAPI.lua"))()
API.Configure({ BaseUrl = base })
local UI = API.LoadUI()
local window = UI.new({ Name = "FrostScripts", Game = "My game" })
local tab = window:AddTab("Home", "H", "Your workspace")
tab:AddModule({ Name = "Welcome", Collapsible = false })
    :AddParagraph("Ready", "Built with FrostScriptsAPI")
```

See [the API reference](docs/API.md) for feature lifecycle, controls, and loading options.

## Local development

Copy the project into your execution environment's readable `FrostScripts` directory. `LocalRoot` is relative to that environment's file API, not necessarily the Windows project folder.

```lua
getgenv().FrostScriptsConfig = { Mode = "local", LocalRoot = "FrostScripts" }
loadstring(readfile("FrostScripts/dist/launchers/GrassCutter.lua"))()
```

To load from another branch or an immutable commit, set `FrostScriptsConfig.BaseUrl` to its raw GitHub base URL before launching. Use the same revision for all files. The default is this repository's `main` branch.

## Verify

Requires Python 3.10+ and [Luau 0.738](https://github.com/luau-lang/luau/releases/tag/0.738). Put the Luau binaries in `.tools/luau`, on PATH, or pass `--luau-dir`.

```powershell
python tools/build.py
python tools/check.py
```

Checks cover deterministic builds, Luau compilation, API loading errors and retries, feature rollback, cleanup, responsive geometry, search/filter behavior, option selection, and UI lifecycle. GitHub Actions runs these checks on pushes and pull requests. Roblox rendering and live game integration require the [manual checks](docs/TESTING.md). Use [UIGallery.lua](examples/UIGallery.lua) to inspect every control without a game suite.
"# FrostScripts" 
