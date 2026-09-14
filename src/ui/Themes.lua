-- Each palette owns its complete surface system. Accent colors never replace it.
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

local SURFACES = {
	Black = { Background = Color3.fromRGB(7, 7, 8), Panel = Color3.fromRGB(13, 13, 15), PanelRaised = Color3.fromRGB(21, 21, 24), Surface = Color3.fromRGB(29, 29, 33), SurfaceHover = Color3.fromRGB(43, 43, 49), Border = Color3.fromRGB(56, 56, 63), Text = Color3.fromRGB(245, 245, 247), Muted = Color3.fromRGB(165, 165, 175) },
	Graphite = { Background = Color3.fromRGB(20, 22, 25), Panel = Color3.fromRGB(27, 29, 33), PanelRaised = Color3.fromRGB(35, 38, 43), Surface = Color3.fromRGB(44, 48, 54), SurfaceHover = Color3.fromRGB(60, 66, 74), Border = Color3.fromRGB(74, 81, 91), Text = Color3.fromRGB(241, 244, 248), Muted = Color3.fromRGB(176, 185, 198) },
	Midnight = { Background = Color3.fromRGB(8, 12, 22), Panel = Color3.fromRGB(14, 20, 35), PanelRaised = Color3.fromRGB(21, 30, 48), Surface = Color3.fromRGB(30, 41, 64), SurfaceHover = Color3.fromRGB(44, 61, 89), Border = Color3.fromRGB(60, 80, 109), Text = Color3.fromRGB(239, 244, 254), Muted = Color3.fromRGB(161, 179, 207) },
	Frost = { Background = Color3.fromRGB(11, 16, 20), Panel = Color3.fromRGB(17, 25, 31), PanelRaised = Color3.fromRGB(26, 36, 43), Surface = Color3.fromRGB(36, 49, 57), SurfaceHover = Color3.fromRGB(52, 74, 85), Border = Color3.fromRGB(69, 96, 108), Text = Color3.fromRGB(238, 248, 252), Muted = Color3.fromRGB(162, 189, 201) },
	Amethyst = { Background = Color3.fromRGB(16, 13, 25), Panel = Color3.fromRGB(25, 20, 35), PanelRaised = Color3.fromRGB(35, 29, 49), Surface = Color3.fromRGB(48, 40, 63), SurfaceHover = Color3.fromRGB(73, 57, 92), Border = Color3.fromRGB(96, 80, 117), Text = Color3.fromRGB(246, 240, 254), Muted = Color3.fromRGB(187, 170, 207) },
	Forest = { Background = Color3.fromRGB(11, 18, 15), Panel = Color3.fromRGB(18, 28, 23), PanelRaised = Color3.fromRGB(28, 40, 33), Surface = Color3.fromRGB(41, 55, 46), SurfaceHover = Color3.fromRGB(57, 78, 65), Border = Color3.fromRGB(74, 100, 83), Text = Color3.fromRGB(237, 247, 239), Muted = Color3.fromRGB(168, 192, 175) },
	Ember = { Background = Color3.fromRGB(22, 15, 12), Panel = Color3.fromRGB(32, 23, 17), PanelRaised = Color3.fromRGB(44, 33, 25), Surface = Color3.fromRGB(58, 44, 34), SurfaceHover = Color3.fromRGB(82, 61, 46), Border = Color3.fromRGB(107, 80, 64), Text = Color3.fromRGB(255, 243, 233), Muted = Color3.fromRGB(203, 178, 161) },
	Rose = { Background = Color3.fromRGB(22, 13, 18), Panel = Color3.fromRGB(32, 20, 27), PanelRaised = Color3.fromRGB(45, 30, 39), Surface = Color3.fromRGB(59, 41, 52), SurfaceHover = Color3.fromRGB(84, 59, 74), Border = Color3.fromRGB(108, 77, 96), Text = Color3.fromRGB(255, 240, 247), Muted = Color3.fromRGB(203, 174, 190) },
	Neon = { Background = Color3.fromRGB(8, 13, 16), Panel = Color3.fromRGB(16, 25, 29), PanelRaised = Color3.fromRGB(23, 37, 43), Surface = Color3.fromRGB(32, 52, 58), SurfaceHover = Color3.fromRGB(47, 75, 82), Border = Color3.fromRGB(65, 98, 105), Text = Color3.fromRGB(238, 253, 255), Muted = Color3.fromRGB(160, 196, 201) },
	Hayfield = { Background = Color3.fromRGB(20, 18, 9), Panel = Color3.fromRGB(30, 27, 16), PanelRaised = Color3.fromRGB(43, 38, 23), Surface = Color3.fromRGB(57, 51, 31), SurfaceHover = Color3.fromRGB(80, 71, 44), Border = Color3.fromRGB(105, 94, 60), Text = Color3.fromRGB(255, 248, 228), Muted = Color3.fromRGB(200, 189, 153) },
}
for name, palette in pairs(THEMES) do
	for key, value in pairs(SURFACES[name]) do palette[key] = value end
end
