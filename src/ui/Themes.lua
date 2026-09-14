-- Every palette keeps the same black foundation. Color belongs to small accents.
local THEMES = {
	Black = {
		Accent = Color3.fromRGB(220, 220, 226),
		AccentHover = Color3.fromRGB(255, 255, 255),
		AccentSoft = Color3.fromRGB(30, 30, 34),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Graphite = {
		Accent = Color3.fromRGB(191, 207, 227),
		AccentHover = Color3.fromRGB(218, 230, 247),
		AccentSoft = Color3.fromRGB(46, 66, 100),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Midnight = {
		Accent = Color3.fromRGB(140, 174, 255),
		AccentHover = Color3.fromRGB(182, 201, 255),
		AccentSoft = Color3.fromRGB(38, 60, 104),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Frost = {
		Accent = Color3.fromRGB(154, 220, 236),
		AccentHover = Color3.fromRGB(198, 240, 250),
		AccentSoft = Color3.fromRGB(41, 73, 86),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Amethyst = {
		Accent = Color3.fromRGB(194, 162, 255),
		AccentHover = Color3.fromRGB(219, 197, 255),
		AccentSoft = Color3.fromRGB(73, 50, 103),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Forest = {
		Accent = Color3.fromRGB(141, 216, 165),
		AccentHover = Color3.fromRGB(180, 236, 197),
		AccentSoft = Color3.fromRGB(41, 79, 57),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Ember = {
		Accent = Color3.fromRGB(242, 177, 132),
		AccentHover = Color3.fromRGB(255, 209, 173),
		AccentSoft = Color3.fromRGB(91, 57, 38),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Rose = {
		Accent = Color3.fromRGB(242, 166, 201),
		AccentHover = Color3.fromRGB(255, 206, 227),
		AccentSoft = Color3.fromRGB(90, 48, 71),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Neon = {
		Accent = Color3.fromRGB(80, 230, 219),
		AccentHover = Color3.fromRGB(161, 255, 244),
		AccentSoft = Color3.fromRGB(31, 83, 82),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
	Hayfield = {
		Accent = Color3.fromRGB(235, 201, 108),
		AccentHover = Color3.fromRGB(255, 229, 162),
		AccentSoft = Color3.fromRGB(83, 69, 31),
		Success = Color3.fromRGB(131, 219, 166),
		Danger = Color3.fromRGB(255, 173, 179),
		DangerSurface = Color3.fromRGB(66, 36, 42),
	},
}

local foundation = {
	Background = Color3.fromRGB(8, 8, 9),
	Panel = Color3.fromRGB(12, 12, 13),
	PanelRaised = Color3.fromRGB(18, 18, 20),
	Surface = Color3.fromRGB(26, 26, 29),
	SurfaceHover = Color3.fromRGB(34, 34, 38),
	Border = Color3.fromRGB(48, 48, 53),
	Text = Color3.fromRGB(241, 241, 244),
	Muted = Color3.fromRGB(150, 150, 160),
}
for _, palette in pairs(THEMES) do
	for key, value in pairs(foundation) do palette[key] = value end
end
