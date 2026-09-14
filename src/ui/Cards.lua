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
		BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, Parent = module.Card }, { corner(10) })
	local fallback = create("TextLabel", {
		Name = "CoverFallback", Size = UDim2.fromScale(1, 1), Text = entry.Monogram or entry.Name:sub(1, 2):upper(),
		TextSize = 36, Font = Enum.Font.BuilderSansBold, TextColor3 = THEME.Accent,
		BackgroundTransparency = 1, Parent = cover,
	})
	local image = create("ImageLabel", {
		Name = "CustomCover", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Image = Library.ImageContent(entry.Image),
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 2, Parent = cover,
	}, { corner(10) })
	image.Visible = image.Image ~= ""
	local function imageReady() fallback.Visible = not (image.Visible and image.IsLoaded) end
	self.Window:_connect(image:GetPropertyChangedSignal("IsLoaded"), imageReady)
	imageReady()
	if self.Window.ResolveCover then
		task.spawn(function()
			local ok, content = pcall(self.Window.ResolveCover, entry)
			if ok and content and not self.Window._destroyed then
				image.Image, image.Visible = content, true
				imageReady()
			end
		end)
	end
	local function label(name, text, size, color, font)
		return create("TextLabel", { Name = name, Text = text, TextSize = size, Font = font,
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, BackgroundTransparency = 1, Parent = module.Card })
	end
	local title = label("ScriptTitle", entry.Name, 17, THEME.Text, Enum.Font.BuilderSansBold)
	local description = label("ScriptDescription", entry.Description, 13, THEME.Muted, Enum.Font.BuilderSans)
	description.TextWrapped = true
	local defaultHint = entry.LaunchHint or "Open in the matching game"
	local status = label("LaunchStatus", defaultHint, 11, THEME.Muted, Enum.Font.BuilderSans)
	local button = create("TextButton", { Name = "LaunchScript", Text = "Launch script",
		TextSize = 14, Font = Enum.Font.BuilderSansMedium, TextColor3 = THEME.Text,
		BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, AutoButtonColor = false, Parent = module.Card,
	}, { corner(8), stroke(THEME.Border, 0.25) })
	self.Window:_hover(button, THEME.Surface, THEME.SurfaceHover)
	local cardStroke = module.Card:FindFirstChildWhichIsA("UIStroke")
	local function setHovered(hovered)
		self.Window:_tween(module.Card, 0.13, { BackgroundColor3 = hovered and THEME.Surface or THEME.PanelRaised })
		if cardStroke then self.Window:_tween(cardStroke, 0.13, { Color = hovered and THEME.Accent or THEME.Border, Transparency = hovered and 0.65 or 0.5 }) end
		if hovered then self.Window:PlaySound("Hover") end
	end
	self.Window:_connect(module.Card.MouseEnter, function() setHovered(true) end)
	self.Window:_connect(module.Card.MouseLeave, function() setHovered(false) end)
	self.Window:_connect(button.Activated, function() if button.Active then safeCall(self.Window, onLaunch) end end)
	local card = { Module = module, Button = button, Cover = cover, Image = image, Title = title,
		Description = description, Status = status, DefaultHint = defaultHint }
	function card:Layout(horizontal, height)
		local textScale = self.Module.Window.TextScale
		local titleHeight = math.ceil(24 * textScale)
		if horizontal then
			local compact = height < 100
			local side = math.min(104, height - (compact and 20 or 24))
			local left = side + 26
			cover.Position, cover.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(side, height)
			local compactTitleHeight = compact and math.min(20, titleHeight) or titleHeight
			title.Position, title.Size = UDim2.fromOffset(left, compact and 6 or 10), UDim2.new(1, -left - 12, 0, compactTitleHeight)
			local descriptionTop = (compact and 8 or 14) + compactTitleHeight
			local buttonHeight = compact and 28 or 32
			local buttonBottom = compact and 6 or 8
			local buttonY = height - buttonHeight - buttonBottom
			local descriptionHeight = math.max(0, buttonY - descriptionTop - 4)
			description.Position, description.Size = UDim2.fromOffset(left, descriptionTop), UDim2.new(1, -left - 12, 0, descriptionHeight)
			description.Visible = descriptionHeight >= 12
			button.Position, button.Size = UDim2.fromOffset(left, buttonY), UDim2.new(1, -left - 12, 0, buttonHeight)
			status.Visible = false
		else
			local descriptionHeight = math.ceil(68 * textScale)
			local coverHeight = math.max(0, height - 116 - titleHeight - descriptionHeight)
			cover.Position, cover.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, coverHeight)
			title.Position, title.Size = UDim2.fromOffset(14, coverHeight + 14), UDim2.new(1, -28, 0, titleHeight)
			description.Position, description.Size = UDim2.fromOffset(14, coverHeight + 21 + titleHeight), UDim2.new(1, -28, 0, descriptionHeight)
			description.Visible = true
			button.Position, button.Size = UDim2.new(0, 12, 1, -68), UDim2.new(1, -24, 0, 38)
			status.Position, status.Size = UDim2.new(0, 14, 1, -23), UDim2.new(1, -28, 0, 16)
			status.Visible = true
		end
	end
	function card:SetLaunchState(state, detail)
		self.Button.Text = state == "Loading" and "Loading..." or state == "Retry" and "Try again" or "Launch script"
		status.Text = detail or self.DefaultHint
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
