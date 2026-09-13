# Script catalog and images

Edit `config/Scripts.lua`, then run `python tools/build.py` and publish the changed source and generated files to `Fwrostt/FrostScripts`. The catalog is bundled into the API; opening the library does not execute any of its game scripts.

Each game uses this format:

```lua
{
    Id = "MyGame",                     -- Unique stable identifier
    Name = "My Game",                  -- Card title
    Description = "What this script does and why you would open it.",
    EntryPoint = "games/MyGame/main.lua",
    Image = {
        Enabled = true,               -- Auto-discover icon.png / icon.jpg / icon.jpeg
        ScaleType = "Crop",            -- Crop fills the cover; Fit shows the whole image
    },
    Monogram = "MG",                   -- Cover fallback
    Tag = "YOUR CATEGORY",             -- Short category caption
    PlaceIds = {},                     -- Optional list of allowed Roblox place IDs
},
```

## GitHub cover images

Upload your cover next to the matching game's `main.lua`:

```text
games/GrassCutter/icon.png
games/NeedleInHay/icon.png
games/Universal/icon.png
```

**PNG is preferred.** `icon.jpg` and `icon.jpeg` also work. Names are lowercase and case-sensitive. The loader tries PNG, JPG, then JPEG, from the same raw GitHub revision as the scripts. Keep just one cover in each game folder. Use an image under 4 MB; a centered subject works best because compact layouts crop to a square. Set `Image.ScaleType = "Fit"` to show the whole image, or `"Crop"` to fill the cover.

On GitHub, open the game's folder, choose **Add file → Upload files**, upload `icon.png`, and commit to `main`. Rerun the loader after GitHub serves the upload. **Image-only uploads do not need a code rebuild.** No Roblox upload or asset ID is needed.

If no supported image exists, the monogram remains and the script can still launch. Set `Image.Enabled = false` to skip cover downloads. Legacy `Image.AssetId` remains an optional fallback.

Roblox ImageLabels cannot display arbitrary HTTPS image URLs directly. The API downloads the bytes from GitHub, validates PNG/JPEG signatures, and uses the executor's `writefile` plus `getcustomasset` (or `getsynasset`) image bridge. This creates a small image cache, not a local hosting service. No executable source is read from disk. Environments without these image functions use the fallback cover.

## Game implementation

`EntryPoint` is a path inside this repository's `games/` directory. The API fetches that file over HTTPS and executes `loadstring(source)(API)`. The file must return a suite table with `Unload()`:

```lua
local API = ...
local UI = API.LoadUI()
local window = UI.new({ Name = "FrostScripts", Game = "My Game", GuiName = "MyGameUI", OverlayName = "MyGameOverlays" })
local modules = window:AddTab("Modules", "M", "Your game controls")
local feature = API.CreateFeature("Example", { ToggleKey = Enum.KeyCode.F })
local module = modules:AddModule({ Name = feature.Name, Feature = feature, Toggleable = true,
    Callback = function(enabled) feature:SetEnabled(enabled) end })
module:AddKeybind({ Name = "Toggle example",
    Get = function() return feature.Settings.ToggleKey end,
    Set = function(key) feature:SetSetting("ToggleKey", key) end,
    OnPressed = function() feature:SetEnabled(not feature.Enabled) end })
window:AddClientSettings(window:AddTab("UI Settings", "S", "Appearance and feedback"))
return { Unload = function() feature:Destroy(); window:Destroy() end }
```

Put all feature settings and shortcuts inside their owning module. Keep UI Settings limited to interface preferences. The library controller manages selection, launch errors, returning to the catalog, and one active suite at a time.

If `PlaceIds` is empty, the entry can launch in any place. Universal intentionally uses an empty list; game-specific entries can add actual place IDs to reject launches elsewhere. No place IDs are guessed or inferred.
