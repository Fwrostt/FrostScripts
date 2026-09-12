# FrostScripts

A shared Luau API and UI toolkit, with independent game suites. Each launcher runs only its named game. There is no cross-game auto-detection or combined game payload.

## Launch

Run the matching entry point in a client environment that provides `loadstring` and `game:HttpGet`:

```lua
-- Grass Cutter
loadstring(game:HttpGet("https://raw.githubusercontent.com/Fwrostt/FrostScripts/main/GrassCutter.lua"))()
```

```lua
-- NeedleInHay
loadstring(game:HttpGet("https://raw.githubusercontent.com/Fwrostt/FrostScripts/main/NeedleInHay.lua"))()
```

The launcher downloads `FrostScriptsAPI.lua` through `loadstring`. The API loads the UI and only the selected game's entry point. Use the correct launcher while inside its game. These entry points are not ordinary Studio LocalScripts; standard Roblox clients do not expose the required execution capabilities.

## Project layout

```text
src/api/                 Shared loader, utilities, feature lifecycle, universal modules
src/ui/Library.lua       UI source and controls
src/loader/Bootstrap.lua Shared launcher source
games/GrassCutter/       Grass Cutter logic and UI bindings
games/NeedleInHay/       NeedleInHay logic and UI bindings
tools/                  Build and verification commands
tests/                  API regression tests
docs/                   API contract and manual UI verification
FrostScriptsAPI.lua     Generated, independently loadable API
UI.lua                  Generated, independently loadable UI
GrassCutter.lua          Generated game launcher
NeedleInHay.lua          Generated game launcher
Loader.lua              Generated launcher using FrostScriptsConfig.Game
```

Edit `src/` and `games/`, then run `python tools/build.py`. Commit the generated root files with their sources so raw URLs work without a build server.

## Shared API

```lua
local base = "https://raw.githubusercontent.com/Fwrostt/FrostScripts/main"
local API = loadstring(game:HttpGet(base .. "/FrostScriptsAPI.lua"))()
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
loadstring(readfile("FrostScripts/GrassCutter.lua"))()
```

To load from another branch or an immutable commit, set `FrostScriptsConfig.BaseUrl` to its raw GitHub base URL before launching. Use the same revision for all files. The default is this repository's `main` branch.

## Verify

Requires Python 3.10+ and [Luau 0.738](https://github.com/luau-lang/luau/releases/tag/0.738). Put the Luau binaries in `.tools/luau`, on PATH, or pass `--luau-dir`.

```powershell
python tools/build.py
python tools/check.py
```

Checks cover deterministic builds, Luau compilation, API loading errors and retries, feature rollback, cleanup, and UI binding behavior. Roblox rendering and live game integration require the [manual checks](docs/TESTING.md).
"# FrostScripts" 
