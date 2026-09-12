function Library.ImageContent(image)
	local value = type(image) == "table" and image.AssetId or image
	if value == nil or value == "" then return "" end
	local digits = tostring(value):match("^(%d+)$") or tostring(value):match("^rbxassetid://(%d+)$")
	if not digits or not digits:find("[1-9]") then return "" end
	return "rbxassetid://" .. digits
end

function Tab:AddScriptCard(entry, onLaunch)
	local module = self:AddModule({ Name = entry.Name, Description = entry.Description, HeaderHeight = 0, Collapsible = false })
	-- Cards share module search/filtering, but have their own editorial layout.
	for _, object in ipairs(module.Card:GetChildren()) do
		if object:IsA("GuiObject") and object ~= module.Body then object.Visible = false end
	end
	module.Body.Position = UDim2.fromOffset(CARD_BODY_INSET, 16)
	local cover = module:_row(144)
	cover.Name = "ScriptCover"
	cover.ClipsDescendants = true
	cover.BackgroundColor3 = THEME.AccentSoft
	cover:SetAttribute("FrostTheme_BackgroundColor3", "AccentSoft")
	create("UIGradient", { Rotation = 25, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(70, 100, 145)), Parent = cover })
	local orbit = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.82, 0.45), Size = UDim2.fromOffset(196, 196),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = cover,
	}, { corner(100), stroke(THEME.Accent, 0.78) })
	create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(142, 142),
		BackgroundTransparency = 1, Parent = orbit }, { corner(90), stroke(THEME.Accent, 0.88) })
	local fallback = create("TextLabel", {
		Position = UDim2.fromOffset(24, 22), Size = UDim2.new(1, -48, 0, 72), Text = entry.Monogram or entry.Name:sub(1, 2):upper(),
		TextSize = 52, Font = Enum.Font.GothamBold, TextColor3 = THEME.Accent,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Parent = cover,
	})
	local image = create("ImageLabel", {
		Name = "CustomCover", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Image = Library.ImageContent(entry.Image), ScaleType = entry.Image and entry.Image.ScaleType == "Fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
		ZIndex = 2, Parent = cover,
	}, { corner(10) })
	image.Visible = image.Image ~= ""
	self.Window:_connect(image:GetPropertyChangedSignal("IsLoaded"), function()
		fallback.Visible = not image.IsLoaded
		orbit.Visible = not image.IsLoaded
	end)
	create("TextLabel", {
		Position = UDim2.new(0, 20, 1, -32), Size = UDim2.new(1, -40, 0, 18), Text = entry.Tag or "FROSTSCRIPTS COLLECTION",
		TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Visible = image.Image == "", Parent = cover,
	})
	module:AddParagraph(entry.Name, entry.Description, { Height = 114 })
	local button = module:AddButton("Launch script  →", onLaunch)
	button.Name = "LaunchScript"
	local status = module:AddParagraph("Ready when you are", "Open while playing this game", { Height = 78 })
	local card = { Module = module, Button = button, Cover = cover, Image = image }
	function card:SetLaunchState(state, detail)
		self.Button.Text = state == "Loading" and "Loading…" or state == "Retry" and "Try again  →" or "Launch script  →"
		status:SetText(detail or "")
	end
	function card:SetLaunchEnabled(enabled)
		self.Button.Active = enabled
		self.Button.Selectable = enabled
		self.Button.AutoButtonColor = enabled
	end
	local scale = create("UIScale", { Parent = cover })
	self.Window:_connect(cover.MouseEnter, function()
		self.Window:_tween(scale, 0.35, { Scale = 1.015 }, Enum.EasingStyle.Back)
		self.Window:_tween(orbit, 0.5, { Rotation = 12 })
	end)
	self.Window:_connect(cover.MouseLeave, function()
		self.Window:_tween(scale, 0.3, { Scale = 1 })
		self.Window:_tween(orbit, 0.5, { Rotation = 0 })
	end)
	return card
end
