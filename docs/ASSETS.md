# UI image assets

Navigation uses the public Roblox-hosted LucideBlox image assets. Their IDs are referenced directly as `rbxassetid://` values in [src/ui/Icons.lua](../src/ui/Icons.lua), so they are fetched by Roblox and no local image files or SVG renderer are used at runtime.

The asset map comes from [LucideBlox](https://github.com/frappedevs/lucideblox), which is distributed under the MIT License. The public source list is available in its [`icons.json`](https://raw.githubusercontent.com/frappedevs/lucideblox/master/src/modules/util/icons.json).
