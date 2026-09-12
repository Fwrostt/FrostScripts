-- Composed with Library.lua by the build; shares its private UI helpers.
function Window:_targetWindowSize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.min(1, math.max(1, viewport.X - 24) / 480, math.max(1, viewport.Y - 24) / 460)
	local preset = SIZE_PRESETS[self.SizePreset] or SIZE_PRESETS.Large
	self.Scale.Scale = scale
	return Vector2.new(math.clamp((viewport.X - 24) / scale, 480, preset.X),
		math.clamp((viewport.Y - 24) / scale, 460, preset.Y))
end

function Window:_resizeWindow(animate)
	if self._destroyed then return end
	self:CloseDropdown()
	self.TargetSize = self:_targetWindowSize()
	local compact = self.TargetSize.X < 800
	local sidebarWidth = compact and 72 or 216
	self.Sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
	self.Main.Position = UDim2.fromOffset(sidebarWidth, 0)
	self.Main.Size = UDim2.new(1, -sidebarWidth, 1, 0)
	self.BrandName.Visible = not compact
	self.BrandSubtitle.Visible = not compact
	self.NavCaption.Visible = not compact
	self.PlayerName.Visible = not compact
	self.Avatar.Position = UDim2.fromOffset(compact and 3 or 10, 10)
	self.Logo.Position = UDim2.fromOffset(compact and 14 or 20, 24)
	for _, tab in ipairs(self.Tabs) do
		tab.Label.Visible = not compact
		tab.IconLabel.Position = UDim2.fromOffset(compact and 9 or 14, 10)
	end
	self._compact = compact
	local size = UDim2.fromOffset(self.TargetSize.X, self.TargetSize.Y)
	if animate then self:_tween(self.Frame, 0.2, { Size = size }) else self.Frame.Size = size end
	self.Frame.Position = UDim2.fromScale(0.5, 0.5)
	self:_layoutMonitors()
	self:_layoutNotifications()
end

function Window:_refreshSearch()
	if self._destroyed or not self.ActiveTab then return end
	local tab = self.ActiveTab
	local query = (self.Search.Text or ""):lower()
	local shown, active = 0, 0
	for _, module in ipairs(tab.Modules) do
		local matches = not self.ActiveOnly or module.Enabled
		for word in query:gmatch("%S+") do
			if not module.SearchText:find(word, 1, true) then matches = false; break end
		end
		module.Card.Visible = matches
		if matches then shown += 1 end
		if module.Enabled then active += 1 end
	end
	self.Empty.Visible = shown == 0
	self.Empty.Text = #tab.Modules == 0 and "Your workspace is ready.\nAdd a module to get started."
		or "No matching modules\nTry a different search or turn off Active."
	self.Footer.Text = string.format("%d of %d modules  ·  %d active", shown, #tab.Modules, active)
end

function Window:SetSearch(query)
	self.Search.Text = tostring(query or "")
	self:_refreshSearch()
end

function Window:SetActiveOnly(enabled)
	self.ActiveOnly = enabled == true
	self:_tween(self.ActiveFilter, 0.12, {
		BackgroundColor3 = self.ActiveOnly and THEME.AccentSoft or THEME.PanelRaised,
		TextColor3 = self.ActiveOnly and THEME.Accent or THEME.Muted,
	})
	self:_refreshSearch()
end

function Window:CloseDropdown()
	if not self._dropdown then return end
	for _, connection in ipairs(self._dropdown.Connections) do connection:Disconnect() end
	self._dropdown.Root:Destroy()
	self._dropdown = nil
end

function Window:_openDropdown(control, name, options, anchor)
	if self._dropdown and self._dropdown.Control == control then self:CloseDropdown(); return end
	self:CloseDropdown()
	local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = self.Gui })
	local connections = {}
	local function connect(signal, callback) table.insert(connections, signal:Connect(callback)) end
	self._dropdown = { Root = root, Control = control, Connections = connections }
	local scrim = create("TextButton", {
		Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 20, Parent = root,
	})
	connect(scrim.Activated, function() self:CloseDropdown() end)
	local viewport = self.Gui.AbsoluteSize
	local width = math.min(360, math.max(180, viewport.X - 32))
	local height = math.min(360, math.max(140, viewport.Y - 32))
	local x = math.clamp(anchor.AbsolutePosition.X, 16, math.max(16, viewport.X - width - 16))
	local y = math.clamp(anchor.AbsolutePosition.Y, 16, math.max(16, viewport.Y - height - 16))
	local panel = create("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, ZIndex = 21, Parent = root,
	}, { corner(14), stroke(THEME.Border, 0) })
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 32), Text = name,
		BackgroundTransparency = 1, TextColor3 = THEME.Text, Font = Enum.Font.GothamBold,
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = panel,
	})
	local close = create("TextButton", {
		Position = UDim2.new(1, -48, 0, 0), Size = UDim2.fromOffset(44, 44), Text = "×",
		BackgroundTransparency = 1, TextColor3 = THEME.Muted, TextSize = 22, Font = Enum.Font.Gotham,
		ZIndex = 22, Parent = panel,
	})
	connect(close.Activated, function() self:CloseDropdown() end)
	local filter = create("TextBox", {
		Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 40), Text = "",
		PlaceholderText = "Find an option…", ClearTextOnFocus = false,
		BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Muted, TextSize = 13, Font = Enum.Font.Gotham,
		ZIndex = 22, Parent = panel,
	}, { corner(8) })
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 94), Size = UDim2.new(1, -24, 1, -106),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = THEME.Accent, ZIndex = 22, Parent = panel,
	}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local entries = {}
	for index, option in ipairs(options) do
		local label, value = optionParts(option)
		local selected = value == control.Value
		local button = create("TextButton", {
			Size = UDim2.new(1, -5, 0, 44), LayoutOrder = index,
			Text = (selected and "✓  " or "    ") .. label,
			TextColor3 = selected and THEME.Accent or THEME.Text, Font = Enum.Font.GothamMedium,
			TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = selected and THEME.AccentSoft or THEME.PanelRaised,
			BorderSizePixel = 0, AutoButtonColor = true, ZIndex = 23, Parent = list,
		}, { corner(8) })
		table.insert(entries, { Label = label:lower(), Button = button })
		connect(button.Activated, function() self:CloseDropdown(); control:SetValue(value) end)
	end
	connect(filter:GetPropertyChangedSignal("Text"), function()
		for _, entry in ipairs(entries) do entry.Button.Visible = entry.Label:find(filter.Text:lower(), 1, true) ~= nil end
	end)
end

function Library:CreateWindow(options)
	options = options or {}
	local player = Players.LocalPlayer
	local parent = player:WaitForChild("PlayerGui")
	pcall(function() if type(gethui) == "function" then parent = gethui() end end)
	local guiName = options.GuiName or "FrostScriptsUI"
	if self._windows and self._windows[guiName] then self._windows[guiName]:Destroy() end
	self._windows = self._windows or {}
	local overlayName = options.OverlayName or "FrostScriptsOverlays"
	for _, name in ipairs({ guiName, overlayName, overlayName .. "Notifications" }) do
		local existing = parent:FindFirstChild(name)
		if existing then existing:Destroy() end
	end
	local window = setmetatable({
		Animations = options.Animations ~= false, Visible = true,
		SizePreset = options.SizePreset or "Large", ThemeName = options.Theme or "Frost",
		TextScale = math.clamp(tonumber(options.TextScale) or 1, 1, 1.3),
		DimAmount = math.clamp(tonumber(options.DimAmount) or 40, 0, 75),
		MonitorWidth = math.clamp(tonumber(options.MonitorWidth) or 380, 320, 520),
		MonitorSide = options.MonitorSide == "Left" and "Left" or "Right",
		Tabs = {}, _tabsByName = {}, Keybinds = {}, Monitors = {}, Notifications = {},
		_monitorCount = 0, _connections = {}, _tweens = setmetatable({}, { __mode = "k" }),
		ActiveOnly = false, _visibilityToken = 0,
		ReservedKeys = options.ReservedKeys or {
			[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true,
			[Enum.KeyCode.D] = true, [Enum.KeyCode.Space] = true, [Enum.KeyCode.LeftControl] = true,
		},
	}, Window)
	self._windows[guiName] = window
	window.Gui = create("ScreenGui", {
		Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100, Parent = parent,
	})
	window.OverlayGui = create("ScreenGui", {
		Name = overlayName, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 90, Parent = parent,
	})
	window.NotificationGui = create("ScreenGui", {
		Name = overlayName .. "Notifications", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 102, Parent = parent,
	})
	window.Shade = create("Frame", {
		Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1 - window.DimAmount / 100, BorderSizePixel = 0, Parent = window.Gui,
	})
	window.Frame = create("CanvasGroup", {
		Name = "FrostWorkspace", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1040, 650), BackgroundColor3 = THEME.Background,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = window.Gui,
	}, { corner(18), stroke(THEME.Border, 0.12) })
	window.Scale = create("UIScale", { Parent = window.Frame })
	window.Sidebar = create("Frame", {
		Name = "Sidebar", Size = UDim2.new(0, 216, 1, 0), BackgroundColor3 = THEME.Panel,
		BorderSizePixel = 0, Parent = window.Frame,
	})
	create("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = THEME.Border, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = window.Sidebar })
	window.Logo = create("TextLabel", {
		Position = UDim2.fromOffset(20, 24), Size = UDim2.fromOffset(44, 44), Text = options.Logo or "F",
		BackgroundColor3 = THEME.AccentSoft, TextColor3 = THEME.Accent, Font = Enum.Font.GothamBold,
		TextSize = 26, BorderSizePixel = 0, Parent = window.Sidebar,
	}, { corner(13), stroke(THEME.Accent, 0.65) })
	local function label(parentObject, text, position, size, fontSize, color, bold)
		return create("TextLabel", { Text = text, Position = position, Size = size, BackgroundTransparency = 1,
			TextSize = fontSize, TextColor3 = color, Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = parentObject })
	end
	window.BrandName = label(window.Sidebar, options.Name or "FrostScripts", UDim2.fromOffset(76, 24), UDim2.new(1, -84, 0, 24), 16, THEME.Text, true)
	window.BrandSubtitle = label(window.Sidebar, "YOUR GAME. YOUR WAY.", UDim2.fromOffset(76, 50), UDim2.new(1, -84, 0, 16), 8, THEME.Muted, true)
	window.NavCaption = label(window.Sidebar, "WORKSPACE", UDim2.fromOffset(24, 100), UDim2.new(1, -40, 0, 18), 10, THEME.Muted, true)
	window.Navigation = create("ScrollingFrame", {
		Name = "Navigation", Position = UDim2.fromOffset(12, 132), Size = UDim2.new(1, -24, 1, -228),
		BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), ScrollBarThickness = 0, Parent = window.Sidebar,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local playerCard = create("Frame", {
		Position = UDim2.new(0, 12, 1, -78), Size = UDim2.new(1, -24, 0, 58),
		BackgroundColor3 = THEME.PanelRaised, BorderSizePixel = 0, Parent = window.Sidebar,
	}, { corner(12), stroke(THEME.Border, 0.55) })
	window.Avatar = label(playerCard, string.upper(player.Name:sub(1, 1)), UDim2.fromOffset(10, 10), UDim2.fromOffset(38, 38), 15, THEME.Accent, true)
	window.Avatar.BackgroundColor3 = THEME.AccentSoft
	window.Avatar.BackgroundTransparency = 0
	window.Avatar.TextXAlignment = Enum.TextXAlignment.Center
	corner(10).Parent = window.Avatar
	window.PlayerName = label(playerCard, player.DisplayName or player.Name, UDim2.fromOffset(60, 0), UDim2.new(1, -68, 1, 0), 12, THEME.Text, true)
	window.Main = create("Frame", { Name = "Main", BackgroundTransparency = 1, Parent = window.Frame })
	local topbar = create("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 108), BackgroundTransparency = 1, Parent = window.Main })
	label(topbar, string.upper(options.Game or "FROSTSCRIPTS"), UDim2.fromOffset(24, 18), UDim2.new(1, -96, 0, 16), 10, THEME.Accent, true)
	window.PageTitle = label(topbar, "Workspace", UDim2.fromOffset(24, 39), UDim2.new(1, -96, 0, 32), 27, THEME.Text, true)
	window.PageSubtitle = label(topbar, "", UDim2.fromOffset(24, 77), UDim2.new(1, -48, 0, 19), 12, THEME.Muted, false)
	local close = create("TextButton", {
		Position = UDim2.new(1, -68, 0, 24), Size = UDim2.fromOffset(44, 44), Text = "−",
		BackgroundColor3 = THEME.PanelRaised, TextColor3 = THEME.Muted, BorderSizePixel = 0,
		Font = Enum.Font.Gotham, TextSize = 24, AutoButtonColor = false, Parent = topbar,
	}, { corner(12), stroke(THEME.Border, 0.5) })
	window:_hover(close, THEME.PanelRaised, THEME.SurfaceHover)
	window:_connect(close.Activated, function() window:SetVisible(false) end)
	local toolbar = create("Frame", { Position = UDim2.fromOffset(24, 114), Size = UDim2.new(1, -48, 0, 44), BackgroundTransparency = 1, Parent = window.Main })
	local searchFrame = create("Frame", { Size = UDim2.new(1, -92, 1, 0), BackgroundColor3 = THEME.PanelRaised, BorderSizePixel = 0, Parent = toolbar }, { corner(10), stroke(THEME.Border, 0.4) })
	window.Search = create("TextBox", {
		Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -56, 1, 0), Text = "",
		PlaceholderText = "Search this tab…", ClearTextOnFocus = false,
		BackgroundTransparency = 1, TextColor3 = THEME.Text, PlaceholderColor3 = THEME.Muted,
		TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = searchFrame,
	})
	local clear = create("TextButton", { Position = UDim2.new(1, -44, 0, 0), Size = UDim2.fromOffset(44, 44),
		Text = "×", TextSize = 18, Font = Enum.Font.Gotham, TextColor3 = THEME.Muted,
		BackgroundTransparency = 1, Parent = searchFrame })
	window:_connect(clear.Activated, function() window:SetSearch("") end)
	window:_connect(window.Search:GetPropertyChangedSignal("Text"), function() window:_refreshSearch() end)
	window.ActiveFilter = create("TextButton", { Position = UDim2.new(1, -82, 0, 0), Size = UDim2.fromOffset(82, 44),
		Text = "Active", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = THEME.Muted,
		BackgroundColor3 = THEME.PanelRaised, AutoButtonColor = false, BorderSizePixel = 0, Parent = toolbar,
	}, { corner(10), stroke(THEME.Border, 0.4) })
	window:_connect(window.ActiveFilter.Activated, function() window:SetActiveOnly(not window.ActiveOnly) end)
	window.Content = create("Frame", { Position = UDim2.fromOffset(20, 174), Size = UDim2.new(1, -40, 1, -218),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = window.Main })
	window.Empty = label(window.Main, "", UDim2.new(0, 32, 0.5, 0), UDim2.new(1, -64, 0, 90), 14, THEME.Muted, false)
	window.Empty.TextXAlignment = Enum.TextXAlignment.Center
	window.Empty.Visible = false
	window.Footer = label(window.Main, "Ready", UDim2.new(0, 24, 1, -32), UDim2.new(1, -180, 0, 20), 11, THEME.Muted, false)
	label(window.Main, "CTRL K  /  SEARCH", UDim2.new(1, -152, 1, -32), UDim2.fromOffset(132, 20), 9, THEME.Muted, true)
	window.Launcher = create("TextButton", { Name = "ReopenFrostScripts", AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -20), Size = UDim2.fromOffset(52, 52), Text = "F",
		TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = THEME.Accent,
		BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Visible = false, Parent = window.OverlayGui,
	}, { corner(16), stroke(THEME.Accent, 0.25) })
	window:_connect(window.Launcher.Activated, function() window:SetVisible(true) end)
	window:_makeDraggable(window.Frame, topbar)
	window:_resizeWindow(false)
	local cameraConnection
	local function watchCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		if workspace.CurrentCamera then
			cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() window:_resizeWindow(false) end)
		end
		window:_resizeWindow(false)
	end
	window:_connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
	window:_connect(window.Gui.Destroying, function() if cameraConnection then cameraConnection:Disconnect() end; window:Destroy() end)
	watchCamera()
	window:_connect(UserInputService.InputBegan, function(input, processed) window:_handleKeyboard(input, processed) end)
	window:SetTheme(options.Theme or "Frost")
	window.Frame.GroupTransparency = 1
	window:_tween(window.Frame, 0.22, { GroupTransparency = 0 })
	window:_applyTextScale()
	return window
end
