# FrostScripts

One script library. Your games, your settings, your style.

## Run this one script

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Fwrostt/FrostScripts/main/dist/launchers/Loader.lua"))()
```

Choose a script card in the library. The launcher automatically downloads and executes the shared API, UI, library screen, and selected game through `loadstring`. All executable downloads come from [Fwrostt/FrostScripts](https://github.com/Fwrostt/FrostScripts). Players do not need to host anything, install project files, or run a separate game launcher.

The execution environment must support `loadstring` and `game:HttpGet`. Raw GitHub files must be publicly readable. These are client execution scripts, not standard Studio LocalScripts.

## The experience

- Script cards with a name, description, optional image, and launch/retry status.
- Compact cards that fit together on desktop and become short rows on smaller screens, animated cover gradients, a soft background, and subtle interface sounds.
- Black by default, with 10 clickable palette previews including Graphite, Midnight, Amethyst, Forest, and Ember.
- Roblox avatar thumbnails, native solid navigation badges, Builder Sans typography, and search only on library/module pages.
- One **UI Settings** page for themes, text, window size, sound, notifications, and separate animation/background switches.
- Each feature owns its settings and keybind inside its module. There is no separate keybind page.
- The back arrow returns to the library and unloads the active game suite. Starting another script unloads the previous one.
- UI preferences carry across the launcher and game windows for the current client session.

## Add scripts and images

Upload `icon.png` beside each game's `main.lua`: [GrassCutter](games/GrassCutter/) or [NeedleInHay](games/NeedleInHay/). Lowercase `icon.jpg` / `icon.jpeg` also work. The loader discovers covers from raw GitHub automatically; image-only uploads need no rebuild. Missing images retain the monogram.

Edit visible names, descriptions, subtitles, and control labels in **[config/Text.lua](config/Text.lua)**; text-only edits need no rebuild. See [the text editing guide](docs/TEXT.md). Script entries and paths live in [config/Scripts.lua](config/Scripts.lua). Use `Image = { Enabled = true, ScaleType = "Crop" }` (or `"Fit"`). The image bridge needs `writefile` and `getcustomasset`; executable downloads remain GitHub-only. See [the complete catalog format](docs/CATALOG.md).

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

The checks compile the scripts, exercise 32 behavior tests, enforce the single entry point and module keybind layout, and reject filesystem loading or incorrect GitHub script hosts. GitHub Actions runs the same checks. These developer commands do not host a service or run on players' computers.

To use another revision, set `getgenv().FrostScriptsConfig.BaseUrl` to this repository's raw branch or commit base URL before running the main loader. Use one revision for every file.

See [API.md](docs/API.md) and [TESTING.md](docs/TESTING.md) for the API contract and in-game verification.
