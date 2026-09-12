function Library.ImageContent(image)
	local value = type(image) == "table" and image.AssetId or image
	if value == nil or value == "" then return "" end
	local digits = tostring(value):match("^(%d+)$") or tostring(value):match("^rbxassetid://(%d+)$")
	if not digits or not digits:find("[1-9]") then return "" end
	return "rbxassetid://" .. digits
end

function Tab:AddScriptCard(entry, onLaunch)
	self.ItemNoun = "scripts"
	if not self.CardLayout then
		local list = self.Scroll:FindFirstChildWhichIsA("UIListLayout")
		if list then list:Destroy() end
		self.ScriptCards = {}
		self.CardLayout = create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -10, 0, 300), CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = self.Scroll,
		})
	end
	local module = self:AddModule({ Name = entry.Name, Description = entry.Description, HeaderHeight = 0, Collapsible = false })
	module.IsScriptCard = true
	-- The grid owns card geometry; cancel the module's initial expansion tween.
	local running = self.Window._tweens[module.Card]
	if running and running.Size then running.Size:Cancel(); running.Size = nil end
	for _, object in ipairs(module.Card:GetChildren()) do
		if object:IsA("GuiObject") then object.Visible = false end
	end
	local cover = create("Frame", { Name = "ScriptCover", ClipsDescendants = true,
		BackgroundColor3 = THEME.AccentSoft, BorderSizePixel = 0, Parent = module.Card }, { corner(10) })
	local gradient = create("UIGradient", { Rotation = 25,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(90, 95, 110)), Parent = cover })
	table.insert(self.Window._coverGradients, gradient)
	local fallback = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), Text = entry.Monogram or entry.Name:sub(1, 2):upper(),
		TextSize = 36, Font = Enum.Font.BuilderSansBold, TextColor3 = THEME.Accent,
		BackgroundTransparency = 1, Parent = cover,
	})
	local image = create("ImageLabel", {
		Name = "CustomCover", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Image = Library.ImageContent(entry.Image),
		ScaleType = type(entry.Image) == "table" and entry.Image.ScaleType == "Fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
		ZIndex = 2, Parent = cover,
	}, { corner(10) })
	image.Visible = image.Image ~= ""
	local function imageReady() fallback.Visible = not (image.Visible and image.IsLoaded) end
	self.Window:_connect(image:GetPropertyChangedSignal("IsLoaded"), imageReady)
	imageReady()
	local function label(name, text, size, color, font)
		return create("TextLabel", { Name = name, Text = text, TextSize = size, Font = font,
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, BackgroundTransparency = 1, Parent = module.Card })
	end
	local title = label("ScriptTitle", entry.Name, 17, THEME.Text, Enum.Font.BuilderSansBold)
	local description = label("ScriptDescription", entry.Description, 13, THEME.Muted, Enum.Font.BuilderSans)
	description.TextWrapped = true
	local status = label("LaunchStatus", "Open in the matching game", 11, THEME.Muted, Enum.Font.BuilderSans)
	local button = create("TextButton", { Name = "LaunchScript", Text = "Launch script",
		TextSize = 14, Font = Enum.Font.BuilderSansMedium, TextColor3 = THEME.Text,
		BackgroundColor3 = THEME.AccentSoft, BorderSizePixel = 0, AutoButtonColor = false, Parent = module.Card,
	}, { corner(8), stroke(THEME.Accent, 0.65) })
	self.Window:_hover(button, THEME.AccentSoft, THEME.SurfaceHover)
	self.Window:_connect(button.Activated, function() if button.Active then safeCall(self.Window, onLaunch) end end)
	local card = { Module = module, Button = button, Cover = cover, Image = image, Title = title, Description = description, Status = status }
	function card:Layout(horizontal, height)
		local textScale = self.Module.Window.TextScale
		local titleHeight = math.ceil(24 * textScale)
		if horizontal then
			local side = math.min(104, height - 24)
			local left = side + 26
			cover.Position, cover.Size = UDim2.fromOffset(12, 12), UDim2.fromOffset(side, side)
			title.Position, title.Size = UDim2.fromOffset(left, 10), UDim2.new(1, -left - 12, 0, titleHeight)
			local descriptionTop = 14 + titleHeight
			description.Position, description.Size = UDim2.fromOffset(left, descriptionTop), UDim2.new(1, -left - 12, 0, math.max(16, height - descriptionTop - 54))
			button.Position, button.Size = UDim2.new(0, left, 1, -48), UDim2.new(1, -left - 12, 0, 36)
			status.Visible = false
		else
			local descriptionHeight = math.ceil(52 * textScale)
			local coverHeight = height - 116 - titleHeight - descriptionHeight
			cover.Position, cover.Size = UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, coverHeight)
			title.Position, title.Size = UDim2.fromOffset(14, coverHeight + 24), UDim2.new(1, -28, 0, titleHeight)
			description.Position, description.Size = UDim2.fromOffset(14, coverHeight + 31 + titleHeight), UDim2.new(1, -28, 0, descriptionHeight)
			button.Position, button.Size = UDim2.new(0, 12, 1, -68), UDim2.new(1, -24, 0, 38)
			status.Position, status.Size = UDim2.new(0, 14, 1, -23), UDim2.new(1, -28, 0, 16)
			status.Visible = true
		end
	end
	function card:SetLaunchState(state, detail)
		self.Button.Text = state == "Loading" and "Loading..." or state == "Retry" and "Try again" or "Launch script"
		status.Text = detail or "Open in the matching game"
	end
	function card:SetLaunchEnabled(enabled)
		self.Button.Active, self.Button.Selectable = enabled, enabled
		self.Button.TextTransparency = enabled and 0 or 0.4
	end
	card:SetLaunchEnabled(true)
	table.insert(self.ScriptCards, card)
	self.Window:_layoutScriptCards()
	return card
end
