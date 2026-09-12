-- Edit this catalog, then run python tools/build.py.
-- Covers: upload games/<GameFolder>/icon.png (or icon.jpg / icon.jpeg) to GitHub.
-- The loader discovers the file automatically. No rebuild needed for image-only uploads.
return {
	{
		Id = "GrassCutter",
		Name = "Grass Cutter",
		Description = "Your complete cutting companion. Farming, loot discovery, world navigation, and live progress in one workspace.",
		EntryPoint = "games/GrassCutter/main.lua",
		Image = { Enabled = true, ScaleType = "Crop" },
		Monogram = "GC",
		Tag = "FARMING & EXPLORATION",
		PlaceIds = {}, -- Optional: { 123456789 }; empty means choose manually in the correct game.
	},
	{
		Id = "NeedleInHay",
		Name = "Needle in a Haystack",
		Description = "Find your rhythm in the haystack. Smart harvesting, needle tracking, upgrades, and clear session feedback.",
		EntryPoint = "games/NeedleInHay/main.lua",
		Image = { Enabled = true, ScaleType = "Crop" },
		Monogram = "NH",
		Tag = "HARVESTING & DISCOVERY",
		PlaceIds = {},
	},
}
