-- Edit this catalog, then run python tools/build.py.
-- Images: upload an image to Roblox and paste its IMAGE asset ID below.
-- Leave AssetId empty for the animated monogram cover. See docs/CATALOG.md.
return {
	{
		Id = "GrassCutter",
		Name = "Grass Cutter",
		Description = "Your complete cutting companion. Farming, loot discovery, world navigation, and live progress in one workspace.",
		EntryPoint = "games/GrassCutter/main.lua",
		Image = { AssetId = "", ScaleType = "Crop" },
		Monogram = "GC",
		Tag = "FARMING & EXPLORATION",
		PlaceIds = {}, -- Optional: { 123456789 }; empty means choose manually in the correct game.
	},
	{
		Id = "NeedleInHay",
		Name = "Needle in a Haystack",
		Description = "Find your rhythm in the haystack. Smart harvesting, needle tracking, upgrades, and clear session feedback.",
		EntryPoint = "games/NeedleInHay/main.lua",
		Image = { AssetId = "", ScaleType = "Crop" },
		Monogram = "NH",
		Tag = "HARVESTING & DISCOVERY",
		PlaceIds = {},
	},
}
