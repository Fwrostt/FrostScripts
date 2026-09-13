-- Edit this catalog, then run python tools/build.py.
-- Covers: upload games/<GameFolder>/icon.png (or icon.jpg / icon.jpeg) to GitHub.
-- The loader discovers the file automatically. No rebuild needed for image-only uploads.
return {
	{
		Id = "GrassCutter",
		Name = "Grass Cutter",
		Description = "Auto grass and loot farming, selling, shop and zone navigation, ESP, movement, performance tools, and live stats.",
		EntryPoint = "games/GrassCutter/main.lua",
		Image = { Enabled = true, ScaleType = "Crop" },
		Monogram = "GC",
		Tag = "FARMING & EXPLORATION",
		LaunchHint = "Open while playing this game",
		PlaceIds = {}, -- Optional: add IDs to enforce a game; empty is unrestricted (used by Universal).
	},
	{
		Id = "NeedleInHay",
		Name = "Needle in a Haystack",
		Description = "Auto pick and sell, RGB targeting, needle claiming, upgrades, event tracking, ESP, movement, and performance tools.",
		EntryPoint = "games/NeedleInHay/main.lua",
		Image = { Enabled = true, ScaleType = "Crop" },
		Monogram = "NH",
		Tag = "HARVESTING & DISCOVERY",
		LaunchHint = "Open while playing this game",
		PlaceIds = {},
	},
	{
		Id = "Universal",
		Name = "Universal",
		Description = "Flight, speed and jump controls, infinite jump, noclip, auto clicker, anti-AFK, fullbright, and performance tools.",
		EntryPoint = "games/Universal/main.lua",
		Image = { Enabled = true, ScaleType = "Fit" },
		Monogram = "UN",
		Tag = "EVERY GAME",
		LaunchHint = "Works in every game",
		PlaceIds = {},
	},
}
