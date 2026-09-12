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
        AssetId = "",                  -- Numeric string or rbxassetid:// image ID
        ScaleType = "Crop",            -- Crop fills the cover; Fit shows the whole image
    },
    Monogram = "MG",                   -- Cover fallback
    Tag = "YOUR CATEGORY",             -- Short category caption
    PlaceIds = {},                     -- Optional list of allowed Roblox place IDs
},
```

## Image format

Upload your cover image to Roblox and use the resulting image asset ID. For example, replace the empty string with `"rbxassetid://1234567890"` or `"1234567890"` using your actual ID. A landscape image around **16:9** works well; keep important content away from the edges when using Crop. A normal website image URL is not a Roblox image asset.

Leave `AssetId = ""` when you have no image. Invalid values and images that have not loaded retain the monogram underneath. The UI never waits for an image before enabling launch. Roblox asset permissions determine whether a cover can load in a particular experience. See [ImageLabel documentation](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).

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

If `PlaceIds` is empty, players choose the card while in the correct game. Add actual place IDs to make the API reject launches in other places. No place IDs are guessed or inferred.
