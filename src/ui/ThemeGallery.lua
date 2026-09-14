-- Inline palette previews, with separate hover and selected treatments.
function Window:AddThemeGallery(tab)
	local module = tab:AddModule({ Name = "Themes", Description = "Choose a complete palette for your workspace.", Expanded = true })
	local row = module:_row(348)
	row.Name, row.BackgroundTransparency = "ThemeGallery", 1
	local layout = create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 78),
		CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	local gallery = { Window = self, Module = module, Row = row, LayoutObject = layout, Tiles = {} }
	local function fixed(object)
		-- Palette previews show their own colors even when another theme is selected.
		for name in pairs(object:GetAttributes()) do
			if name:match("^FrostTheme_") then object:SetAttribute(name, nil) end
		end
		return object
	end
	for index, name in ipairs(self:GetThemeNames()) do
		local palette = THEMES[name]
		local border = stroke(THEME.Border, 0.35)
		local button = create("TextButton", { Name = name .. "Theme", Text = "", LayoutOrder = index,
			AutoButtonColor = false, BackgroundColor3 = THEME.PanelRaised, BorderSizePixel = 0, Parent = row,
		}, { corner(10), border })
		local preview = fixed(create("Frame", { Name = "PalettePreview", Position = UDim2.fromOffset(7, 7),
			Size = UDim2.new(1, -14, 0, 34), BackgroundColor3 = palette.Background, BorderSizePixel = 0, Parent = button }, { corner(6) }))
		fixed(create("Frame", { Size = UDim2.new(0.2, 0, 1, 0), BackgroundColor3 = palette.Panel,
			BorderSizePixel = 0, Parent = preview }, { corner(6) }))
		for bar, key in ipairs({ "Accent", "Surface", "Muted" }) do
			fixed(create("Frame", { Position = UDim2.new(0.28, 0, 0, 7 + (bar - 1) * 8),
				Size = UDim2.new(bar == 3 and 0.35 or 0.6, 0, 0, 3), BackgroundColor3 = palette[key],
				BorderSizePixel = 0, Parent = preview }, { corner(2) }))
		end
		local label = create("TextLabel", { Text = name, Position = UDim2.fromOffset(10, 47),
			Size = UDim2.new(1, -20, 0, 24), BackgroundTransparency = 1, TextColor3 = THEME.Text,
			Font = Enum.Font.BuilderSansMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = button })
		local selected = create("Frame", { Name = "SelectedIndicator", Position = UDim2.new(1, -16, 0, 53),
			Size = UDim2.fromOffset(6, 6), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Parent = button }, { corner(3) })
		local tile = { Name = name, Button = button, Border = border, Label = label, Selected = selected, Preview = preview }
		table.insert(gallery.Tiles, tile)
		self:_connect(button.Activated, function() self:SetTheme(name) end)
		self:_connect(button.MouseEnter, function()
			if self.ThemeName ~= name then self:_tween(button, 0.14, { BackgroundColor3 = THEME.Surface }) end
		end)
		self:_connect(button.MouseLeave, function() gallery:Refresh() end)
	end
	function gallery:Refresh()
		for _, tile in ipairs(self.Tiles) do
			local selected = self.Window.ThemeName == tile.Name
			self.Window:_tween(tile.Button, 0.14, { BackgroundColor3 = selected and THEME.AccentSoft or THEME.PanelRaised })
			self.Window:_tween(tile.Border, 0.14, { Color = selected and THEME.Accent or THEME.Border, Transparency = selected and 0 or 0.35 })
			tile.Selected.Visible = selected
		end
		self.Module:SetStatus("Current palette: " .. self.Window.ThemeName)
	end
	function gallery:Layout()
		local width = self.Window.TargetSize.X - (self.Window._compact and 72 or 216) - 80
		local columns = width >= 560 and 3 or 2
		self.LayoutObject.CellSize = UDim2.new(1 / columns, -7, 0, 78)
		self.Row.Size = UDim2.new(1, 0, 0, math.ceil(#self.Tiles / columns) * 88 - 10)
		self.Module:_refreshHeight()
	end
	self.ThemeGalleries = self.ThemeGalleries or {}
	table.insert(self.ThemeGalleries, gallery)
	gallery:Layout()
	gallery:Refresh()
	return gallery
end
