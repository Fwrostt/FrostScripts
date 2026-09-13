# FrostScripts

One script library. Your games, your settings, your style.

## Run this one script

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Fwrostt/FrostScripts/main/dist/launchers/Loader.lua?frost=" .. tostring(os.time())))()
```

Choose a script card in the library. The launcher automatically downloads and executes the shared API, UI, library screen, and selected game through `loadstring`. All executable downloads come from [Fwrostt/FrostScripts](https://github.com/Fwrostt/FrostScripts). Players do not need to host anything, install project files, or run a separate game launcher.

The execution environment must support `loadstring` and `game:HttpGet`. Raw GitHub files must be publicly readable. These are client execution scripts, not standard Studio LocalScripts.

## The experience

- Script cards with a name, description, optional image, and launch/retry status.
- A curated Universal catalog of 100 working local modules across movement, character, camera, world, players, server, navigation, performance, fun, utility, and HUD categories; overlapping effect toggles, duplicate actions, and status-only cards are omitted from the UI.
- Home quick actions for Flight, Noclip, Speed, Infinite Jump, Freecam, Fullbright, Anti-AFK, and FPS Boost, plus Favorites, Recently Used, commands, and a live FPS/ping/active-module status bar.
- One configurable Player ESP & Nametags module combines highlights, display names, usernames, health bars, distance, team colors/filtering, range, opacity, text size, and refresh rate.
- Optional Mobile Mode with touch movement, rise/drop, drag-to-look, and synchronized quick-toggle controls; controller shortcuts are available as a separate module.
- Compact cards that fit together on desktop and become short rows on smaller screens, animated cover gradients, a soft background, and subtle interface sounds.
- Black by default, with 10 clickable palette previews including Graphite, Midnight, Amethyst, Forest, and Ember.
- Roblox avatar thumbnails, native solid navigation badges, Builder Sans typography, and search only on library/module pages.
- One **UI Settings** page for themes, text, window size, sound, notification controls and corner placement, and separate animation/background switches.
- Theme-aware toasts for module enable/disable events, with separate global and module-event switches.
- Optional system-style middle-finger pointer loaded from raw GitHub, with automatic native-cursor restoration.
- Each feature owns its settings and keybind inside its module. There is no separate keybind page.
- One shared update manager services render, heartbeat, 0.1-second, and telemetry work; a character manager reconnects respawn-sensitive features without per-module polling connections.
- The back arrow returns to the library and unloads the active game suite. Starting another script unloads the previous one.
- UI preferences carry across the launcher and game windows for the current client session.

## Add scripts and images

Upload `icon.png` beside each script's `main.lua`: [Universal](games/Universal/), [GrassCutter](games/GrassCutter/), or [NeedleInHay](games/NeedleInHay/). Lowercase `icon.jpg` / `icon.jpeg` also work. The loader discovers covers from raw GitHub automatically; image-only uploads need no rebuild. Missing images retain the monogram.

Edit the simple named variables at the top of **[config/Text.lua](config/Text.lua)** for branding, titles, subtitles, card actions, and script descriptions. Text-only edits need no rebuild, and fresh loader runs bypass stale GitHub caches. The advanced section keeps every module and status label editable. See [the text editing guide](docs/TEXT.md). Script entries and paths live in [config/Scripts.lua](config/Scripts.lua). Use `Image = { Enabled = true, ScaleType = "Crop" }` (or `"Fit"`). The image bridge needs `writefile` and `getcustomasset`; executable downloads remain GitHub-only. See [the complete catalog format](docs/CATALOG.md).

UI defaults and the sound asset are in [config/UI.lua](config/UI.lua). Gameplay defaults stay in each game's modules.

## Project structure

```text
config/                 Script catalog and UI defaults
src/api/                Loading, lifecycle, utilities, universal modules
src/ui/                 Controls, window shell, effects, and script cards
src/launcher/App.lua     Script-library controller
src/loader/Bootstrap.lua Main entry source
games/                  Independent game implementations
dist/launchers/Loader.lua The only player entry point
dist/launcher/App.lua    Generated script-library controller
dist/api/FrostScriptsAPI.lua Generated shared API
dist/ui/UI.lua           Generated shared UI
tools/                  Build, validation, and URL audit
tests/                  API, UI, and launcher integration checks
examples/               Developer control gallery
docs/                   API, catalog, and verification guides
```

No scripts belong in the project root. Edit `config/`, `src/`, and `games/`; commit their generated `dist/` outputs together.

## Build and verify

Developers need Python 3.10+ and [Luau 0.738](https://github.com/luau-lang/luau/releases/tag/0.738). Put the Luau tools on PATH or in `.tools/luau`.

```powershell
python tools/build.py
python tools/check.py
```

The checks compile the scripts, exercise the API, UI, and launcher behavior tests, enforce the single entry point and module keybind layout, and reject filesystem loading or incorrect GitHub script hosts. GitHub Actions runs the same checks. These developer commands do not host a service or run on players' computers.

To use another revision, set `getgenv().FrostScriptsConfig.BaseUrl` to this repository's raw branch or commit base URL before running the main loader. Use one revision for every file.

See [API.md](docs/API.md) and [TESTING.md](docs/TESTING.md) for the API contract and in-game verification.
