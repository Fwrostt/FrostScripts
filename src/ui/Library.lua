local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Module = {}
Module.__index = Module
local translate = makeText(UI_COPY, "Shared")
local textResolvers = setmetatable({}, { __mode = "k" })

function Window:Text(value)
	return self.Translate(value)
end

-- @include Themes.lua

local function copyTheme(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

local THEME = copyTheme(THEMES.Black)

local SIZE_PRESETS = {
	Comfortable = Vector2.new(920, 580),
	Large = Vector2.new(1040, 650),
	["Extra Large"] = Vector2.new(1160, 720),
}

local CARD_HORIZONTAL_GUTTER = 8
local CARD_BODY_INSET = 16
local TOAST_HEIGHT = 78
local TOAST_GAP = 88
local TOAST_MAX_WIDTH = 328

local function create(className, properties, children)
	local object = Instance.new(className)
	local renderText = (properties and textResolvers[properties.Parent]) or translate
	if properties and properties.Localize == false then renderText = function(value) return value end end
	textResolvers[object] = renderText
	if className == "TextLabel" or className == "TextButton" or className == "TextBox" then
		object.TextTruncate = Enum.TextTruncate.AtEnd
	end
	for property, value in pairs(properties or {}) do
		if property ~= "Localize" then object[property] = (property == "Text" or property == "PlaceholderText") and renderText(value) or value end
		if typeof(value) == "Color3" then
			for themeKey, themeValue in pairs(THEME) do
				if value == themeValue then
					object:SetAttribute("FrostTheme_" .. property, themeKey)
					break
				end
			end
		end
	end
	if className == "TextLabel" or className == "TextButton" or className == "TextBox" then
		local property = className == "TextBox" and "PlaceholderText" or "Text"
		local changing = false
		local connection = object:GetPropertyChangedSignal(property):Connect(function()
			if changing then return end
			local original = object[property]
			local rendered = renderText(original)
			if rendered ~= original then
				changing = true; object[property] = rendered; changing = false
			end
		end)
		local cleanup
		cleanup = object.Destroying:Connect(function() connection:Disconnect(); cleanup:Disconnect() end)
	end
	for _, child in ipairs(children or {}) do
		child.Parent = object
	end
	if properties and properties.TextSize
		and (className == "TextLabel" or className == "TextButton" or className == "TextBox") then
		object:SetAttribute("FrostBaseTextSize", properties.TextSize)
	end
	return object
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, transparency)
	return create("UIStroke", {
		Color = color or THEME.Border,
		Transparency = transparency or 0,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Draw disclosure arrows with geometry so missing font glyphs cannot become squares.
local function chevron(parent, position)
	local root = create("Frame", { Name = "Disclosure", Position = position, Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1, Parent = parent })
	for index, rotation in ipairs({ 45, -45 }) do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(index == 1 and 6 or 12, 9),
			Size = UDim2.fromOffset(9, 2), Rotation = rotation, BackgroundColor3 = THEME.Muted,
			BorderSizePixel = 0, Parent = root }, { corner(1) })
	end
	return root
end

local function safeCall(window, callback, ...)
	if not callback then return true end
	local ok, result = pcall(callback, ...)
	if not ok then
		window:Notify({
			Title = "Callback error",
			Text = tostring(result),
			Duration = 5,
			Type = "Error",
		})
	end
	return ok, result
end

local function optionParts(option)
	if type(option) == "table" then
		local value = option.Value
		if value == nil then value = option.value end
		if value == nil then value = option[2] end
		return tostring(option.Label or option.label or option.Name or option.name or option[1]), value
	end
	return tostring(option), option
end

local function copySelection(value)
	local result = {}
	if type(value) ~= "table" then return result end
	for key, selected in pairs(value) do
		if type(key) == "number" then
			result[selected] = true
		else
			result[key] = selected == true
		end
	end
	return result
end

function Window:_tween(object, duration, properties, style, direction)
	if self._destroyed then return nil end
	local running = self._tweens[object] or {}
	self._tweens[object] = running
	for property in pairs(properties) do
		if running[property] then running[property]:Cancel(); running[property] = nil end
	end
	for property, value in pairs(properties) do
		if typeof(value) == "Color3" then
			local key
			for name, color in pairs(THEME) do if color == value then key = name; break end end
			object:SetAttribute("FrostTheme_" .. property, key)
		end
	end
	if not self.Animations then
		for property, value in pairs(properties) do object[property] = value end
		return nil
	end
	local animation = TweenService:Create(
		object,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		properties
	)
	for property in pairs(properties) do running[property] = animation end
	animation:Play()
	return animation
end

function Window:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self._connections, connection)
	return connection
end

function Window:_hover(button, normalColor, hoverColor)
	local normalKey, hoverKey
	for key, color in pairs(THEME) do
		if color == normalColor then normalKey = key end
		if color == hoverColor then hoverKey = key end
	end
	self:_connect(button.MouseEnter, function()
		self:_tween(button, 0.14, { BackgroundColor3 = THEME[hoverKey] or hoverColor })
	end)
	self:_connect(button.MouseLeave, function()
		self:_tween(button, 0.14, { BackgroundColor3 = THEME[normalKey] or normalColor })
	end)
end

function Window:_makeDraggable(object, handle)
	local dragging, activeInput, inputType, dragStart, startPosition, startTopLeft, viewport, size
	local function pointerPosition(input)
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	handle.Active = true
	self:_connect(handle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, activeInput, inputType = true, input, input.UserInputType
			dragStart = pointerPosition(input)
			startPosition = object.Position
			startTopLeft, viewport, size = object.AbsolutePosition, self.Gui.AbsoluteSize, object.AbsoluteSize
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if dragging and (input == activeInput or input.UserInputType == inputType) then
			dragging, activeInput, inputType = false, nil, nil
		end
	end)
	self:_connect(UserInputService.InputChanged, function(input)
		if not dragging or not self.Visible then return end
		local mouseMove = inputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		local touchMove = inputType == Enum.UserInputType.Touch and input == activeInput
		if not mouseMove and not touchMove then return end
		local delta = pointerPosition(input) - dragStart
		local topLeft = startTopLeft + delta
		local clampedTopLeft = Vector2.new(
			math.clamp(topLeft.X, 0, math.max(0, viewport.X - size.X)),
			math.clamp(topLeft.Y, 0, math.max(0, viewport.Y - size.Y)))
		local clampedDelta = clampedTopLeft - startTopLeft
		object.Position = UDim2.new(
			startPosition.X.Scale, startPosition.X.Offset + clampedDelta.X,
			startPosition.Y.Scale, startPosition.Y.Offset + clampedDelta.Y)
	end)
end

function Window:SetAnimations(enabled)
	self.Animations = enabled == true
	self:_remember("Animations", self.Animations)
	self:_syncAmbient()
	if not self.Animations then
		for object, running in pairs(self._tweens) do
			for _, animation in pairs(running) do animation:Cancel() end
			if object == self.Frame then object.Visible = self.Visible end
		end
		for _, tab in ipairs(self.Tabs) do
			for _, module in ipairs(tab.Modules) do module:_refreshHeight() end
		end
	end
end

-- Responsive geometry lives in Shell.lua.

-- Window resizing lives in Shell.lua.

function Window:SetSizePreset(preset)
	if not SIZE_PRESETS[preset] then return false end
	self.SizePreset = preset
	self:_remember("SizePreset", preset)
	self:_resizeWindow(true)
	return true
end

function Window:_applyTextScale()
	local function apply(root)
		for _, descendant in ipairs(root:GetDescendants()) do
			local baseSize = descendant:GetAttribute("FrostBaseTextSize")
			if baseSize and (descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox")) then
				descendant.TextSize = math.max(11, math.floor(baseSize * self.TextScale + 0.5))
			end
		end
	end
	apply(self.Gui)
	apply(self.OverlayGui)
	apply(self.NotificationGui)
end

function Window:SetTextScale(scale)
	self.TextScale = math.clamp(tonumber(scale) or 1, 1, 1.3)
	self:_remember("TextScale", self.TextScale)
	self:_applyTextScale()
	self:_layoutScriptCards()
end

function Window:SetDimAmount(percent)
	self.DimAmount = math.clamp(tonumber(percent) or 48, 0, 75)
	self:_remember("DimAmount", self.DimAmount)
	self.Shade.BackgroundTransparency = 1 - (self.DimAmount / 100)
end

function Window:_layoutMonitors()
	local visible = {}
	for _, monitor in pairs(self.Monitors) do
		if monitor.Frame.Visible then table.insert(visible, monitor) end
	end
	table.sort(visible, function(a, b) return a.Order < b.Order end)
	for visibleIndex, monitor in ipairs(visible) do
		monitor.Frame.Size = UDim2.fromOffset(math.min(self.MonitorWidth, math.max(120, self.OverlayGui.AbsoluteSize.X - 44)), 64)
		monitor.Frame.AnchorPoint = self.MonitorSide == "Left" and Vector2.new(0, 0) or Vector2.new(1, 0)
		monitor.Frame.Position = self.MonitorSide == "Left"
			and UDim2.fromOffset(22, 22 + (visibleIndex - 1) * 74)
			or UDim2.new(1, -22, 0, 22 + (visibleIndex - 1) * 74)
	end
end

function Window:SetMonitorWidth(width)
	self.MonitorWidth = math.clamp(tonumber(width) or 380, 320, 520)
	self:_remember("MonitorWidth", self.MonitorWidth)
	self:_layoutMonitors()
end

function Window:SetMonitorSide(side)
	if side ~= "Left" and side ~= "Right" then return false end
	self.MonitorSide = side
	self:_remember("MonitorSide", side)
	self:_layoutMonitors()
	return true
end

function Window:IsCapturingInput()
	return self._rebinding ~= nil or self._dropdown ~= nil or UserInputService:GetFocusedTextBox() ~= nil
end

function Window:GetRoot()
	return self.Gui
end

function Window:SetVisible(show)
	if self._destroyed then return end
	show = show == true
	if self.Visible == show then return end
	self:CloseDropdown()
	self._visibilityToken += 1
	local token = self._visibilityToken
	self.Visible = show
	self:_syncAmbient()
	self:_syncCursor()
	self.Launcher.Visible = not show
	if show then
		self:PlaySound("Open")
		self.Gui.Enabled = true
		self.Frame.Visible = true
		self:_tween(self.Shade, 0.18, { BackgroundTransparency = 1 - self.DimAmount / 100 })
	else
		if self._rebinding then self._rebinding:Refresh(); self._rebinding = nil end
		self.Search:ReleaseFocus()
		self.Frame.Visible = false
		self:_tween(self.Shade, 0.14, { BackgroundTransparency = 1 })
		task.delay(self.Animations and 0.15 or 0, function()
			if not self._destroyed and token == self._visibilityToken then self.Gui.Enabled = false end
		end)
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:SelectTab(tab)
	if self._destroyed then return end
	if type(tab) == "string" then tab = self._tabsByName[tab] end
	if not tab or tab.Window ~= self then return end
	self:CloseDropdown()
	if self._rebinding then self._rebinding:Refresh(); self._rebinding = nil end
	if self.ActiveTab then
		self.ActiveTab.Query, self.ActiveTab.ActiveOnly = self.Search.Text, self.ActiveOnly
	end
	self.ActiveTab = tab
	local searchable = tab.SearchEnabled ~= false
	self.Toolbar.Visible, self.SearchHint.Visible = searchable, searchable
	self.Search:ReleaseFocus()
	self.Search.Text = tab.Query or ""
	self.ActiveOnly = tab.ActiveOnly == true
	self.Search.PlaceholderText = tab.ItemNoun == "scripts" and "Find a script..." or "Search modules..."
	local categorized = searchable and tab.Categories and #tab.Categories > 0
	self.CategoryFilter.Visible = categorized == true
	self.CategoryFilter.Text = categorized and self:Text(tab.ActiveCategory or "All") or ""
	self.ActiveFilter.Visible = searchable and tab.ItemNoun ~= "scripts"
	self.Search.Parent.Size = UDim2.new(1, tab.ItemNoun == "scripts" and 0 or (categorized and -230 or -92), 1, 0)
	self.Content.Position = UDim2.fromOffset(20, searchable and 142 or 94)
	self.Content.Size = UDim2.new(1, -40, 1, searchable and -186 or -138)
	self:SetActiveOnly(self.ActiveOnly)
	for _, item in ipairs(self.Tabs) do
		local selected = item == tab
		item.Page.Visible = selected
		self:_tween(item.Button, 0.14, { BackgroundColor3 = selected and THEME.AccentSoft or THEME.Panel })
		self:_tween(item.Label, 0.14, { TextColor3 = selected and THEME.Text or THEME.Muted })
		self:_tween(item.IconLabel, 0.14, { TextColor3 = selected and THEME.Accent or THEME.Muted })
		item.Indicator.BackgroundTransparency = selected and 0 or 1
	end
	self.PageTitle.Text, self.PageSubtitle.Text = tab.Name, tab.Subtitle
	tab.Page.Position = UDim2.fromOffset(0, self.Animations and 10 or 0)
	self:_tween(tab.Page, 0.18, { Position = UDim2.fromOffset(0, 0) })
	self:_refreshSearch()
end

function Window:IsFavorite(id)
	return self.Favorites[tostring(id)] == true
end

function Window:_refreshFavoriteModule(module)
	if module.FavoriteButton then
		local favorite = self:IsFavorite(module.FavoriteId)
		module.FavoriteButton.Text = favorite and "★" or "☆"
		module.FavoriteButton.TextColor3 = favorite and THEME.Accent or THEME.Muted
	end
	for _, proxy in ipairs(module.FavoriteProxies or {}) do
		proxy.Card.Visible = self:IsFavorite(module.FavoriteId)
	end
	if self.ActiveTab and self.ActiveTab.FavoritesView then self:_refreshSearch() end
end

function Module:SetFavorite(favorite)
	if not self.FavoriteId then return false end
	favorite = favorite == true
	if favorite then self.Window.Favorites[self.FavoriteId] = true else self.Window.Favorites[self.FavoriteId] = nil end
	self.Window:_remember("Favorites", self.Window.Favorites)
	if favorite then
		for _, tab in ipairs(self.Window._favoriteTabs) do self.Window:_addFavoriteProxy(tab, self) end
	end
	self.Window:_refreshFavoriteModule(self)
	return true
end

function Module:IsFavorite()
	return self.FavoriteId and self.Window:IsFavorite(self.FavoriteId) or false
end

function Window:_addFavoriteProxy(tab, source)
	source.FavoriteProxies = source.FavoriteProxies or {}
	source.FavoriteProxyTabs = source.FavoriteProxyTabs or {}
	if source.FavoriteProxyTabs[tab] then return source.FavoriteProxyTabs[tab] end
	local proxy = tab:AddModule({
		Name = source.Name,
		Description = source.Status.Text,
		Toggleable = source.Toggle ~= nil,
		Default = source.Enabled,
		Collapsible = false,
		Notifications = false,
		FavoriteSource = source,
		Callback = function(enabled)
			if source.Toggle then source.Toggle:SetValue(enabled) end
		end,
	})
	if source.FavoriteAction then
		proxy:AddButton(source.FavoriteActionText or "Run", function() safeCall(self, source.FavoriteAction) end)
	end
	proxy:AddButton("Open settings", function()
		self:SelectTab(source.Tab)
		self:SetSearch(source.Name)
	end)
	proxy:AddButton("Remove favorite", function() source:SetFavorite(false) end, { Danger = true })
	table.insert(source.FavoriteProxies, proxy)
	source.FavoriteProxyTabs[tab] = proxy
	proxy.Card.Visible = source:IsFavorite()
	return proxy
end

function Window:AddFavoritesTab(name, icon, subtitle)
	local tab = self:AddTab(name or "Favorites", icon or "favorites", subtitle or "Your pinned modules and shortcuts")
	tab.SearchEnabled = true
	tab.FavoritesView = true
	table.insert(self._favoriteTabs, tab)
	for _, module in ipairs(self._favoriteModules) do
		if module:IsFavorite() then self:_addFavoriteProxy(tab, module) end
	end
	return tab
end

function Tab:SetCategories(categories, default)
	assert(type(categories) == "table" and #categories > 0, "Categories must contain at least one option")
	self.Categories = table.clone(categories)
	self.ActiveCategory = default or categories[1]
	local valid = false
	for _, category in ipairs(self.Categories) do
		if category == self.ActiveCategory then valid = true; break end
	end
	assert(valid, "Default category must be present in categories")
	if self.Window.ActiveTab == self then self.Window:SelectTab(self) end
	return self
end

function Tab:SetStatusBar(text)
	self.StatusText = text ~= nil and tostring(text) or nil
	if self.Window.ActiveTab == self then self.Window:_refreshSearch() end
	return self
end

function Window:AddTab(name, icon, subtitle)
	assert(not self._tabsByName[name], "Duplicate tab: " .. name)
	local tab = setmetatable({
		Window = self,
		Name = name,
		Icon = ({ H = "home", L = "library", S = "settings", M = "modules", C = "controls", F = "favorites" })[icon] or icon or "controls",
		SearchEnabled = name == "Library" or name == "Modules" or name == "Controls" or name == "Favorites",
		Subtitle = subtitle or "",
		Modules = {},
	}, Tab)
	tab.Page = create("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.Content,
	})
	tab.Scroll = create("ScrollingFrame", {
		Name = name .. "List",
		Size = UDim2.fromScale(1, 1),
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = THEME.Muted,
		ScrollBarImageTransparency = 0.35,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = tab.Page,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	local button = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = #self.Tabs + 1,
		AutoButtonColor = false,
		BackgroundColor3 = THEME.Panel,
		BorderSizePixel = 0,
		Text = "",
		Parent = self.Navigation,
	}, { corner(10) })
	local indicator = create("Frame", {
		Position = UDim2.fromOffset(4, 10),
		Size = UDim2.fromOffset(3, 30),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = button,
	}, { corner(3) })
	local iconLabel = create("TextLabel", {
		Position = UDim2.fromOffset(self._compact and 9 or 14, 10),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = tostring(tab.Icon),
		TextColor3 = THEME.Muted,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 18,
		Parent = button,
	})
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.new(1, -62, 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		Parent = button,
	})
	self:_attachIcon(iconLabel, tab.Icon)
	tab.Button, tab.Indicator, tab.IconLabel, tab.Label = button, indicator, iconLabel, label
	label.Visible = not self._compact
	table.insert(self.Tabs, tab)
	self._tabsByName[name] = tab
	self:_connect(button.MouseEnter, function()
		if self.ActiveTab ~= tab then
			self:_tween(button, 0.13, { BackgroundColor3 = THEME.PanelRaised })
		self:_tween(label, 0.13, { TextColor3 = THEME.Text })
			self:_tween(iconLabel, 0.13, { TextColor3 = THEME.Accent })
		end
	end)
	self:_connect(button.MouseLeave, function()
		if self.ActiveTab ~= tab then
			self:_tween(button, 0.13, { BackgroundColor3 = THEME.Panel })
			self:_tween(label, 0.13, { TextColor3 = THEME.Muted })
			self:_tween(iconLabel, 0.13, { TextColor3 = THEME.Muted })
		end
	end)
	self:_connect(button.Activated, function() self:SelectTab(tab) end)
	if #self.Tabs == 1 then self:SelectTab(tab) end
	return tab
end

function Tab:SetDashboardLayout()
	assert(not self.CardLayout, "Dashboard layout cannot be used for script cards")
	if self.DashboardGrid then return self end
	local list = self.Scroll:FindFirstChildWhichIsA("UIListLayout")
	if list then list:Destroy() end
	self.DashboardGrid = create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -10, 0, 174),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = self.Scroll,
	})
	self.Window:_layoutDashboardCards()
	return self
end

function Module:_refreshHeight()
	if self.Window._destroyed or self.IsScriptCard then return end
	local bodyHeight = self.BodyLayout.AbsoluteContentSize.Y + 16
	self.Body.Size = UDim2.new(1, -(CARD_BODY_INSET * 2), 0, bodyHeight)
	local target = self.Expanded and self.HeaderHeight + bodyHeight or self.HeaderHeight
	self.Window:_tween(self.Card, 0.2, { Size = UDim2.new(1, -CARD_HORIZONTAL_GUTTER, 0, target) })
	self.Chevron.Rotation = self.Expanded and 180 or 0
	self.Window:_queueTextScale()
end

function Module:SetExpanded(expanded)
	if self.Collapsible == false then expanded = true end
	self.Expanded = expanded == true
	self.Body.Visible = true
	self:_refreshHeight()
end

function Module:SetStatus(status)
	self.Status.Text = tostring(status or "")
	for _, proxy in ipairs(self.FavoriteProxies or {}) do proxy.Status.Text = self.Status.Text end
end

function Module:SetEnabled(enabled, silent)
	enabled = enabled == true
	local changed = self.Enabled ~= enabled
	self.Enabled = enabled
	if changed then self.Window:_refreshSearch() end
	self.Window:_tween(self.Status, 0.12, { TextColor3 = enabled and THEME.Success or THEME.Muted })
	self.Window:_tween(self.Accent, 0.14, {
		BackgroundColor3 = enabled and THEME.Accent or THEME.Border,
	})
	for _, proxy in ipairs(self.FavoriteProxies or {}) do
		if proxy.Toggle and proxy.Toggle.Value ~= enabled then proxy.Toggle:SetValue(enabled, true) end
		proxy.Status.Text = self.Status.Text
	end
	if changed and not silent and self.NotifyState ~= false and self.Window.ModuleNotificationsEnabled then
		self.Window:Notify({
			Title = self.Name,
			Text = enabled and "Module enabled" or "Module disabled",
			Type = enabled and "Success" or "Info",
			Duration = 2.6,
		})
	end
end

function Window:_queueTextScale()
	if self._textScaleQueued or self._destroyed then return end
	self._textScaleQueued = true
	task.defer(function()
		self._textScaleQueued = false
		if not self._destroyed then self:_applyTextScale() end
	end)
end

function Module:_index(text)
	self.SearchText = self.SearchText .. " " .. tostring(self.Window:Text(text) or ""):lower()
end

function Module:_row(height)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		Parent = self.Body,
	}, { corner(10) })
	task.defer(function() self:_refreshHeight() end)
	return row
end

function Module:AddToggle(name, default, callback, description)
	self:_index(name)
	local row = self:_row(description and 54 or 48)
	create("TextLabel", {
		Position = UDim2.fromOffset(14, description and 7 or 0),
		Size = UDim2.new(1, -86, 0, description and 20 or 48),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 13,
		Parent = row,
	})
	if description then
		create("TextLabel", {
			Position = UDim2.fromOffset(14, 28),
			Size = UDim2.new(1, -86, 0, 16),
			BackgroundTransparency = 1,
			Text = description,
			TextColor3 = THEME.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 11,
			Parent = row,
		})
	end
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(44, 24),
		AutoButtonColor = false,
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		Text = "",
		Parent = row,
	}, { corner(12), stroke(THEME.Border, 0.35) })
	local knob = create("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = THEME.Text,
		BorderSizePixel = 0,
		Parent = button,
	}, { corner(9) })
	local control = { Value = default == true }
	function control:SetValue(value, silent)
		self.Value = value == true
		self.Module.Window:_tween(button, 0.14, {
			BackgroundColor3 = self.Value and THEME.Accent or THEME.PanelRaised,
		})
		self.Module.Window:_tween(knob, 0.14, {
			Position = self.Value and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
		})
		if not silent then safeCall(self.Module.Window, callback, self.Value) end
	end
	control.Module = self
	local hitTarget = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(58, 40), Text = "", BackgroundTransparency = 1,
		ZIndex = 4, Parent = row,
	})
	self.Window:_connect(hitTarget.Activated, function()
		control:SetValue(not control.Value)
	end)
	control:SetValue(control.Value, true)
	return control
end

function Module:AddActionGrid(actions, options)
	assert(type(actions) == "table" and #actions > 0, "Action grid needs at least one action")
	options = options or {}
	local columns = math.max(1, math.floor(options.Columns or 2))
	local buttonHeight = options.ButtonHeight or 42
	local rows = math.ceil(#actions / columns)
	local row = self:_row(rows * buttonHeight + math.max(0, rows - 1) * 8)
	local grid = create("UIGridLayout", {
		CellSize = UDim2.new(1 / columns, -6, 0, buttonHeight),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = row,
	})
	local controls = {}
	for index, action in ipairs(actions) do
		local button = create("TextButton", {
			Name = tostring(action.Id or action.Name or index),
			LayoutOrder = index,
			BackgroundColor3 = THEME.PanelRaised,
			BorderSizePixel = 0,
			Text = tostring(action.Name or action.Id or "Action"),
			TextColor3 = THEME.Text,
			TextSize = 12,
			Font = Enum.Font.BuilderSansBold,
			AutoButtonColor = false,
			Parent = row,
		}, { corner(10), stroke(THEME.Border, 0.35) })
		local control = { Button = button, Active = action.Active == true, Module = self }
		function control:SetActive(active)
			self.Active = active == true
			self.Module.Window:_tween(self.Button, 0.14, {
				BackgroundColor3 = self.Active and THEME.AccentSoft or THEME.PanelRaised,
				TextColor3 = self.Active and THEME.Accent or THEME.Text,
			})
		end
		self.Window:_connect(button.MouseEnter, function()
			if not control.Active then self.Window:_tween(button, 0.12, { BackgroundColor3 = THEME.SurfaceHover }) end
		end)
		self.Window:_connect(button.MouseLeave, function() control:SetActive(control.Active) end)
		self.Window:_connect(button.Activated, function() safeCall(self.Window, action.Callback, control) end)
		control:SetActive(control.Active)
		table.insert(controls, control)
	end
	return controls, grid
end

function Module:AddSlider(name, minimum, maximum, default, callback, options)
	self:_index(name)
	options = options or {}
	local row = self:_row(options.Description and 90 or 78)
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -104, 0, 22),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		Parent = row,
	})
	if options.Description then
		create("TextLabel", {
			Position = UDim2.fromOffset(16, 35),
			Size = UDim2.new(1, -104, 0, 18),
			BackgroundTransparency = 1,
			Text = options.Description,
			TextColor3 = THEME.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 12,
			Parent = row,
		})
	end
	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 9),
		Size = UDim2.fromOffset(68, 26),
		BackgroundColor3 = THEME.PanelRaised,
		BorderSizePixel = 0,
		TextColor3 = THEME.Text,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 12,
		Parent = row,
	}, { corner(7), stroke(THEME.Border, 0.55) })
	local trackButton = create("TextButton", {
		Position = UDim2.new(0, 16, 1, -27),
		Size = UDim2.new(1, -32, 0, 18),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Parent = row,
	})
	local track = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = THEME.PanelRaised,
		BorderSizePixel = 0,
		Parent = trackButton,
	}, { corner(4), stroke(THEME.Border, 0.5) })
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = track,
	}, { corner(4) })
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = THEME.Text,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = track,
	}, { corner(8), stroke(THEME.Accent, 0.15) })
	local step = math.max(0.0001, tonumber(options.Step) or 1)
	assert(maximum >= minimum, "Slider maximum must be at least minimum")
	local formatter = options.Formatter
	local control = { Module = self, Value = default }
	local function display(value)
		if formatter then return tostring(formatter(value)) end
		if step >= 1 then return tostring(math.floor(value + 0.5)) end
		return string.format(step < 0.1 and "%.2f" or "%.1f", value)
	end
	function control:SetValue(value, silent)
		value = math.clamp(tonumber(value) or minimum, minimum, maximum)
		value = math.clamp(minimum + math.floor((value - minimum) / step + 0.5) * step, minimum, maximum)
		self.Value = value
		local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
		valueLabel.Text = display(value)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		if not silent then safeCall(self.Module.Window, callback, value) end
	end
	local dragging = false
	local function setFromPosition(x)
		if track.AbsoluteSize.X > 0 then
			control:SetValue(minimum + (maximum - minimum)
				* math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1))
		end
	end
	self.Window:_connect(trackButton.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromPosition(input.Position.X)
			self.Window:_tween(knob, 0.1, { Size = UDim2.fromOffset(19, 19) })
		end
	end)
	self.Window:_connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			setFromPosition(input.Position.X)
		end
	end)
	self.Window:_connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			self.Window:_tween(knob, 0.1, { Size = UDim2.fromOffset(16, 16) })
		end
	end)
	control:SetValue(default, true)
	return control
end

function Module:AddDropdown(name, options, default, callback)
	self:_index(name)
	local row = self:_row(96)
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 24),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		Parent = row,
	})
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 44),
		AutoButtonColor = false,
		BackgroundColor3 = THEME.PanelRaised,
		BorderSizePixel = 0,
		TextColor3 = THEME.Text,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 13,
		Parent = row,
	}, { corner(8), stroke(THEME.Border, 0.45) })
	chevron(button, UDim2.new(1, -30, 0.5, -9))
	self.Window:_hover(button, THEME.PanelRaised, THEME.SurfaceHover)
	local control = { Module = self, Value = default, Index = 1 }
	for index, option in ipairs(options) do
		local _, value = optionParts(option)
		if value == default then
			control.Index = index
			break
		end
	end
	function control:SetValue(value, silent)
		for index, option in ipairs(options) do
			local label, candidate = optionParts(option)
			if candidate == value then
				self.Index, self.Value = index, candidate
				button.Text = label
				if not silent then safeCall(self.Module.Window, callback, candidate) end
				return
			end
		end
	end
	self.Window:_connect(button.Activated, function()
		if #options > 0 then self.Window:_openDropdown(control, name, options, button) end
	end)
	if #options > 0 then
		local _, initial = optionParts(options[control.Index])
		control:SetValue(initial, true)
	else button.Text = "No options" end
	return control
end

function Module:AddMultiDropdown(name, options, defaults, callback, colors)
	self:_index(name)
	local rows = math.ceil(#options / 3)
	local row = self:_row(48 + rows * 46)
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -28, 0, 20),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		Parent = row,
	})
	local control = { Module = self, Value = copySelection(defaults), Buttons = {} }
	function control:_refresh(option)
		local button = self.Buttons[option]
		if button then
			self.Module.Window:_tween(button, 0.12, {
				BackgroundColor3 = self.Value[option] and THEME.AccentSoft or THEME.PanelRaised,
				TextColor3 = self.Value[option] and ((colors and colors[option]) or THEME.Text) or THEME.Muted,
			})
			button.Text = (self.Value[option] and "✓ " or "") .. self.Module.Window:Text(tostring(option))
		end
	end
	function control:SetValue(values, silent)
		self.Value = copySelection(values)
		for _, option in ipairs(options) do self:_refresh(option) end
		if not silent then safeCall(self.Module.Window, callback, copySelection(self.Value)) end
	end
	for index, option in ipairs(options) do
		local column, line = (index - 1) % 3, math.floor((index - 1) / 3)
		local button = create("TextButton", {
			Position = UDim2.new(column / 3, 8 + column * 2, 0, 40 + line * 46),
			Size = UDim2.new(1 / 3, -13, 0, 42),
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = option,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 12,
			Parent = row,
		}, { corner(7) })
		control.Buttons[option] = button
		self.Window:_connect(button.Activated, function()
			control.Value[option] = not control.Value[option]
			control:_refresh(option)
			safeCall(self.Window, callback, copySelection(control.Value))
		end)
	end
	control:SetValue(defaults, true)
	return control
end

function Module:AddNumberInput(name, default, callback, options)
	self:_index(name)
	options = options or {}
	local row = self:_row(96)
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 24),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		Parent = row,
	})
	local box = create("TextBox", {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 44),
		BackgroundColor3 = THEME.PanelRaised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = tostring(default),
		TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Muted,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 13,
		Parent = row,
	}, { corner(8), stroke(THEME.Border, 0.45) })
	local control = { Module = self, Value = tonumber(default) or 0 }
	function control:SetValue(value, silent)
		value = tonumber(value) or self.Value
		if value ~= value or math.abs(value) == math.huge then value = self.Value end
		if options.Min then value = math.max(options.Min, value) end
		if options.Max then value = math.min(options.Max, value) end
		self.Value = value
		box.Text = tostring(value)
		if not silent then safeCall(self.Module.Window, callback, value) end
	end
	self.Window:_connect(box.FocusLost, function() control:SetValue(box.Text) end)
	return control
end

function Module:AddTextInput(name, default, callback, options)
	self:_index(name)
	options = options or {}
	local row = self:_row(96)
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 24),
		BackgroundTransparency = 1, Text = name, TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.BuilderSansBold,
		TextSize = 14, Parent = row,
	})
	local box = create("TextBox", {
		Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 44),
		BackgroundColor3 = THEME.PanelRaised, BorderSizePixel = 0,
		ClearTextOnFocus = options.ClearOnFocus == true, Text = tostring(default or ""),
		PlaceholderText = options.Placeholder or "Type here...", TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Muted, Font = Enum.Font.BuilderSansMedium,
		TextSize = 13, Parent = row,
	}, { corner(8), stroke(THEME.Border, 0.45) })
	local control = { Module = self, Value = tostring(default or ""), Box = box }
	function control:SetValue(value, silent)
		self.Value = tostring(value or "")
		box.Text = self.Value
		if not silent then safeCall(self.Module.Window, callback, self.Value) end
	end
	self.Window:_connect(box.FocusLost, function(enterPressed)
		control:SetValue(box.Text)
		if enterPressed and options.OnEnter then safeCall(self.Window, options.OnEnter, control.Value) end
	end)
	return control
end

function Module:AddButton(name, callback, options)
	self:_index(name)
	options = options or {}
	local row = self:_row(42)
	local danger = options.Danger == true
	local button = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = danger and THEME.DangerSurface or THEME.Surface,
		BorderSizePixel = 0,
		Text = name,
		TextColor3 = danger and THEME.Danger or THEME.Text,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 13,
		Parent = row,
	}, { corner(8), stroke(danger and THEME.Danger or THEME.Accent, 0.45) })
	self.Window:_hover(
		button,
		danger and THEME.DangerSurface or THEME.Surface,
		danger and THEME.DangerSurface or THEME.SurfaceHover
	)
	self.Window:_connect(button.Activated, function() safeCall(self.Window, callback) end)
	return button
end

function Module:AddParagraph(title, text, options)
	self:_index(title)
	self:_index(text)
	options = options or {}
	local row = self:_row(options.Height or 66)
	create("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 20),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		Parent = row,
	})
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(14, 29),
		Size = UDim2.new(1, -28, 1, -35),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 12,
		Parent = row,
	})
	return {
		SetText = function(_, value) label.Text = tostring(value) end,
		SetColor = function(_, color) label.TextColor3 = color end,
	}
end

function Tab:AddModule(options)
	if type(options) == "string" then options = { Name = options } end
	options = options or {}
	local module = setmetatable({
		Window = self.Window,
		Tab = self,
		Name = options.Name or "Module",
		SearchText = (self.Window:Text(options.Name or "Module") .. " " .. self.Window:Text(options.Description or "")):lower(),
		HeaderHeight = options.HeaderHeight or 56,
		Expanded = options.Expanded == true or options.Collapsible == false,
		Collapsible = options.Collapsible ~= false,
		NotifyState = options.Notifications ~= false,
		Category = options.Category,
		FavoriteId = options.Favoritable and tostring(options.FavoriteId or options.Name or "Module") or nil,
		FavoriteSource = options.FavoriteSource,
		FavoriteAction = options.FavoriteAction,
		FavoriteActionText = options.FavoriteActionText,
		Enabled = false,
	}, Module)
	module.Card = create("Frame", {
		Name = module.Name,
		Size = UDim2.new(1, -CARD_HORIZONTAL_GUTTER, 0, module.HeaderHeight),
		BackgroundColor3 = THEME.PanelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		LayoutOrder = #self.Modules + 1,
		Parent = self.Scroll,
	}, { corner(13), stroke(THEME.Border, 0.25) })
	module.Accent = create("Frame", {
		Position = UDim2.fromOffset(4, 10),
		Size = UDim2.fromOffset(3, math.max(20, module.HeaderHeight - 20)),
		BackgroundColor3 = options.Accent and THEME.Accent or THEME.Border,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = module.Card,
	}, { corner(3) })
	create("TextLabel", {
		Position = UDim2.fromOffset(22, 9),
		Size = UDim2.new(1, -(options.RightInset or (options.Toggleable and 148 or 58)), 0, 22),
		BackgroundTransparency = 1,
		Text = module.Name,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = options.TitleSize or 16,
		Parent = module.Card,
	})
	module.Status = create("TextLabel", {
		Position = UDim2.fromOffset(22, 30),
		Size = UDim2.new(1, -(options.RightInset or (options.Toggleable and 148 or 64)), 0, 20),
		BackgroundTransparency = 1,
		Text = options.Description or options.Status or "Ready",
		TextColor3 = THEME.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 12,
		Parent = module.Card,
	})
	module.Chevron = chevron(module.Card, UDim2.new(1, options.Toggleable and -100 or -36, 0, 25))
	module.Chevron.Visible = module.Collapsible
	local headerButton = create("TextButton", {
		Size = UDim2.new(1, options.Toggleable and -78 or 0, 0, module.HeaderHeight),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 2,
		Parent = module.Card,
	})
	module.Body = create("Frame", {
		Position = UDim2.fromOffset(CARD_BODY_INSET, module.HeaderHeight),
		Size = UDim2.new(1, -(CARD_BODY_INSET * 2), 0, 0),
		BackgroundTransparency = 1,
		Parent = module.Card,
	})
	module.BodyLayout = create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = module.Body,
	})
	self.Window:_connect(module.BodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		module:_refreshHeight()
	end)
	if module.Collapsible then
		self.Window:_connect(headerButton.Activated, function()
			module:SetExpanded(not module.Expanded)
		end)
		self.Window:_connect(headerButton.MouseEnter, function()
			self.Window:_tween(module.Card, 0.14, { BackgroundColor3 = THEME.Surface })
		end)
		self.Window:_connect(headerButton.MouseLeave, function()
			self.Window:_tween(module.Card, 0.14, { BackgroundColor3 = THEME.PanelRaised })
		end)
	end
	if options.Toggleable then
		module.Toggle = module:AddToggle("", options.Default == true, options.Callback)
		local toggleRow = module.Toggle
		for _, child in ipairs(module.Body:GetChildren()) do
			if child:IsA("Frame") then
				child.Visible = false
				child.Size = UDim2.new(1, 0, 0, 0)
				break
			end
		end
		local toggleButton = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, 18),
			Size = UDim2.fromOffset(48, 26),
			AutoButtonColor = false,
			BackgroundColor3 = THEME.Surface,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 5,
			Parent = module.Card,
		}, { corner(12) })
		local knob = create("Frame", {
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = THEME.Text,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = toggleButton,
		}, { corner(9) })
		function toggleRow:SetValue(value, silent)
			self.Value = value == true
			self.Module.Window:_tween(toggleButton, 0.14, {
				BackgroundColor3 = self.Value and THEME.Accent or THEME.Surface,
			})
			self.Module.Window:_tween(knob, 0.14, {
				Position = self.Value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
			})
			self.Module:SetEnabled(self.Value, silent)
			if not silent then safeCall(self.Module.Window, options.Callback, self.Value) end
		end
		local hitTarget = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 9),
			Size = UDim2.fromOffset(64, 44), Text = "", BackgroundTransparency = 1,
			ZIndex = 7, Parent = module.Card,
		})
		self.Window:_connect(hitTarget.Activated, function()
			toggleRow:SetValue(not toggleRow.Value)
		end)
		toggleRow:SetValue(options.Default == true, true)
	end
	if options.Feature then options.Feature:BindControl(module) end
	if module.FavoriteId then
		module.FavoriteButton = create("TextButton", {
			Name = "FavoriteButton",
			Position = UDim2.new(1, options.Toggleable and -142 or -76, 0, 12),
			Size = UDim2.fromOffset(36, 34),
			BackgroundColor3 = THEME.Surface,
			BorderSizePixel = 0,
			Text = "☆",
			TextColor3 = THEME.Muted,
			TextSize = 20,
			Font = Enum.Font.BuilderSansBold,
			AutoButtonColor = false,
			ZIndex = 8,
			Parent = module.Card,
		}, { corner(9), stroke(THEME.Border, 0.45) })
		self.Window:_hover(module.FavoriteButton, THEME.Surface, THEME.SurfaceHover)
		self.Window:_connect(module.FavoriteButton.Activated, function() module:SetFavorite(not module:IsFavorite()) end)
		table.insert(self.Window._favoriteModules, module)
		if module:IsFavorite() then
			for _, favoriteTab in ipairs(self.Window._favoriteTabs) do self.Window:_addFavoriteProxy(favoriteTab, module) end
		end
		self.Window:_refreshFavoriteModule(module)
	end

	module:SetExpanded(module.Expanded)
	table.insert(self.Modules, module)
	self.Window:_refreshSearch()
	return module
end

function Window:CreateMobileControls(options)
	options = options or {}
	local window = self
	local controls = { Move = Vector2.zero, Vertical = 0, LookDelta = Vector2.zero, Buttons = {}, Visible = false }
	local root = create("Frame", {
		Name = "FrostMobileControls",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.OverlayGui,
	})
	controls.Root = root

	local moveState = { Forward = false, Back = false, Left = false, Right = false, Up = false, Down = false }
	local function refreshMove()
		controls.Move = Vector2.new((moveState.Right and 1 or 0) - (moveState.Left and 1 or 0),
			(moveState.Forward and 1 or 0) - (moveState.Back and 1 or 0))
		local magnitude = math.sqrt(controls.Move.X * controls.Move.X + controls.Move.Y * controls.Move.Y)
		if magnitude > 1 then controls.Move = controls.Move / magnitude end
		controls.Vertical = (moveState.Up and 1 or 0) - (moveState.Down and 1 or 0)
	end
	local function mobileButton(parent, name, text, position, size)
		return create("TextButton", {
			Name = name, Position = position, Size = size or UDim2.fromOffset(50, 50),
			BackgroundColor3 = THEME.PanelRaised, BackgroundTransparency = 0.08,
			BorderSizePixel = 0, Text = text, TextColor3 = THEME.Text,
			TextSize = 13, Font = Enum.Font.BuilderSansBold, AutoButtonColor = false,
			Parent = parent,
		}, { corner(14), stroke(THEME.Border, 0.2) })
	end
	local movement = create("Frame", {
		Name = "Movement", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 1, Parent = root,
	})
	local directions = {
		{ "Forward", "UP", UDim2.fromOffset(60, 0) }, { "Left", "LEFT", UDim2.fromOffset(0, 60) },
		{ "Right", "RIGHT", UDim2.fromOffset(120, 60) }, { "Back", "DOWN", UDim2.fromOffset(60, 120) },
	}
	for _, item in ipairs(directions) do
		local button = mobileButton(movement, item[1], item[2], item[3])
		window:_connect(button.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then moveState[item[1]] = true; refreshMove() end
		end)
		window:_connect(button.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then moveState[item[1]] = false; refreshMove() end
		end)
	end
	local vertical = create("Frame", {
		Name = "Vertical", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(58, 118), BackgroundTransparency = 1, Parent = root,
	})
	for index, item in ipairs({ { "Up", "RISE" }, { "Down", "DROP" } }) do
		local button = mobileButton(vertical, item[1], item[2], UDim2.fromOffset(4, (index - 1) * 60))
		window:_connect(button.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then moveState[item[1]] = true; refreshMove() end
		end)
		window:_connect(button.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then moveState[item[1]] = false; refreshMove() end
		end)
	end
	local lookPad = mobileButton(root, "LookPad", "DRAG TO LOOK", UDim2.new(1, -198, 0.5, -70), UDim2.fromOffset(170, 116))
	lookPad.AnchorPoint = Vector2.new(0, 0.5)
	lookPad.BackgroundTransparency = 0.38
	local lookInput, lookPosition
	window:_connect(lookPad.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			lookInput, lookPosition = input, Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	window:_connect(lookPad.InputChanged, function(input)
		if input ~= lookInput or not lookPosition then return end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		controls.LookDelta += position - lookPosition
		lookPosition = position
	end)
	window:_connect(lookPad.InputEnded, function(input)
		if input == lookInput then lookInput, lookPosition = nil, nil end
	end)
	local quick = create("Frame", {
		Name = "QuickToggles", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(228, 208), BackgroundTransparency = 1, Parent = root,
	}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(108, 44), CellPadding = UDim2.fromOffset(8, 8), FillDirectionMaxCells = 2 }) })

	function controls:AddToggle(name, callback)
		local button = mobileButton(quick, name, name:upper(), UDim2.new(), UDim2.fromOffset(108, 44))
		local control = { Button = button, Active = false }
		function control:SetActive(active)
			self.Active = active == true
			button.BackgroundColor3 = self.Active and THEME.AccentSoft or THEME.PanelRaised
			button.TextColor3 = self.Active and THEME.Accent or THEME.Text
		end
		window:_connect(button.Activated, function() safeCall(window, callback, control) end)
		table.insert(self.Buttons, control)
		return control
	end
	function controls:SetVisible(visible)
		self.Visible = visible == true
		root.Visible = self.Visible
		if not self.Visible then
			for key in pairs(moveState) do moveState[key] = false end
			refreshMove()
			self.LookDelta = Vector2.zero
		end
	end
	function controls:ConsumeLookDelta()
		local delta = self.LookDelta
		self.LookDelta = Vector2.zero
		return delta
	end
	return controls
end

function Module:AddKeybind(options)
	options = options or {}
	self:_index(options.Name or "Keybind")
	local row = self:_row(60)
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -172, 1, 0),
		Text = options.Name or "Toggle key", TextColor3 = THEME.Text,
		TextSize = 13, Font = Enum.Font.BuilderSansBold, TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, Parent = row,
	})
	local button = create("TextButton", {
		Position = UDim2.new(1, -148, 0, 8), Size = UDim2.fromOffset(136, 44),
		BackgroundColor3 = THEME.PanelRaised, BorderSizePixel = 0,
		TextColor3 = THEME.Text, TextSize = 13, Font = Enum.Font.BuilderSansBold,
		AutoButtonColor = false, Parent = row,
	}, { corner(9), stroke(THEME.Border, 0.3) })
	local binding = {
		Window = self.Window,
		Button = button,
		Name = options.Name or "Keybind",
		Get = options.Get,
		Set = options.Set,
		OnPressed = options.OnPressed,
		AllowClear = options.AllowClear ~= false,
		IsVisibility = options.IsVisibility == true,
	}
	function binding:Refresh()
		local key = self.Get()
		self.Button.Text = key == Enum.KeyCode.Unknown and "None" or key.Name
		self.Button.TextColor3 = THEME.Text
	end
	self.Window:_hover(button, THEME.PanelRaised, THEME.SurfaceHover)
	self.Window:_connect(button.Activated, function()
		if self.Window._rebinding then self.Window._rebinding:Refresh() end
		self.Window._rebinding = binding
		button.Text = "Press a key..."
		button.TextColor3 = THEME.Accent
	end)
	table.insert(self.Window.Keybinds, binding)
	binding:Refresh()
	return binding
end

-- Compatibility helper; new game UIs place keybinds in their owning module.
function Tab:AddKeybind(options)
	return self:AddModule({ Name = options.Name or "Shortcut", Expanded = true }):AddKeybind(options)
end

function Window:_keyInUse(key, except)
	for _, binding in ipairs(self.Keybinds) do
		if binding ~= except and binding.Get() == key then return binding.Name end
	end
	return nil
end

function Window:_handleKeyboard(input, processed)
	if self.InputEnabled == false or self._destroyed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if self._rebinding then
		local binding = self._rebinding
		local key = input.KeyCode
		if key == Enum.KeyCode.Escape then
			binding:Refresh()
		elseif (key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete) and binding.AllowClear then
			binding.Set(Enum.KeyCode.Unknown)
			binding:Refresh()
		elseif self.ReservedKeys[key] then
			binding:Refresh()
			self:Notify({ Title = "Reserved key", Text = key.Name .. " is used for movement.", Type = "Error" })
		else
			local conflict = self:_keyInUse(key, binding)
			if conflict then
				binding:Refresh()
				self:Notify({ Title = "Key already assigned", Text = key.Name .. " is bound to " .. conflict .. ".", Type = "Error" })
			else
				binding.Set(key)
				binding:Refresh()
			end
		end
		self._rebinding = nil
		return
	end
	if self._dropdown and input.KeyCode == Enum.KeyCode.Escape then self:CloseDropdown(); return end
	if input.KeyCode == Enum.KeyCode.K and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) and not processed then
		self:SetVisible(true)
		if self.ActiveTab and self.ActiveTab.SearchEnabled ~= false then self.Search:CaptureFocus() end
		return
	end
	if UserInputService:GetFocusedTextBox() == self.Search and input.KeyCode == Enum.KeyCode.Escape then
		self:SetSearch(""); self.Search:ReleaseFocus(); return
	end
	if self._dropdown or processed or UserInputService:GetFocusedTextBox() then return end
	for _, binding in ipairs(self.Keybinds) do
		local key = binding.Get()
		if key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
			safeCall(self, binding.OnPressed)
			break
		end
	end
end

function Window:SetMonitor(key, text)
	local nextText = text ~= nil and tostring(text) or nil
	local monitor = self.Monitors[key]
	local wasVisible = monitor and monitor.Frame.Visible
	if not monitor then
		self._monitorCount += 1
		local frame = create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, 22 + ((self._monitorCount - 1) * 74)),
			Size = UDim2.fromOffset(self.MonitorWidth, 64),
			BackgroundColor3 = THEME.PanelRaised,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = self.OverlayGui,
		}, { corner(10), stroke(THEME.Border, 0.25) })
		create("Frame", {
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.fromOffset(4, 44),
			BackgroundColor3 = THEME.Accent,
			BorderSizePixel = 0,
			Parent = frame,
		}, { corner(3) })
		local label = create("TextLabel", {
			Position = UDim2.fromOffset(18, 8),
			Size = UDim2.new(1, -34, 1, -16),
			BackgroundTransparency = 1,
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = true,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 13,
			Parent = frame,
		})
		self:_makeDraggable(frame, frame)
		monitor = { Frame = frame, Label = label, Order = self._monitorCount }
		self.Monitors[key] = monitor
	end
	if monitor.Text == nextText and monitor.Frame.Visible == (nextText ~= nil) then
		return monitor
	end
	monitor.Text = nextText
	monitor.Label.Text = nextText or ""
	monitor.Frame.Visible = nextText ~= nil
	if not wasVisible and nextText ~= nil then self:_layoutMonitors() end
	self:_applyTextScale()
	return monitor
end

function Window:HideMonitor(key)
	if self.Monitors[key] then
		self.Monitors[key].Frame.Visible = false
		self:_layoutMonitors()
	end
end

function Window:_layoutNotifications()
	local size = self.OverlayGui.AbsoluteSize
	local maxVisible = math.max(1, math.min(3, math.floor((size.Y - 32) / TOAST_GAP)))
	for index = #self.Notifications, 1, -1 do
		if not self.Notifications[index].Parent then table.remove(self.Notifications, index) end
	end
	while #self.Notifications > maxVisible do table.remove(self.Notifications, 1):Destroy() end
	local position = self.NotificationPosition or "Bottom Right"
	local left = position:find("Left", 1, true) ~= nil
	local top = position:find("Top", 1, true) ~= nil
	for index, frame in ipairs(self.Notifications) do
		frame.Size = UDim2.fromOffset(math.min(TOAST_MAX_WIDTH, math.max(120, size.X - 32)), TOAST_HEIGHT)
		frame.AnchorPoint = Vector2.new(left and 0 or 1, top and 0 or 1)
		local offset = (#self.Notifications - index) * TOAST_GAP
		frame.Position = UDim2.new(left and 0 or 1, left and 16 or -16,
			top and 0 or 1, top and 16 + offset or -16 - offset)
	end
end

function Window:Notify(options)
	if self._destroyed or self.NotificationsEnabled == false then return nil end
	self:PlaySound("Notify")
	if type(options) == "string" then options = { Text = options } end
	options = options or {}
	local duration = math.clamp(tonumber(options.Duration) or 4, 1, 30)
	local tint = options.Type == "Error" and THEME.Danger or options.Type == "Success" and THEME.Success or THEME.Accent
	local frame = create("CanvasGroup", {
		Name = "Notification", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(TOAST_MAX_WIDTH, TOAST_HEIGHT),
		BackgroundColor3 = THEME.PanelRaised, BackgroundTransparency = 0.02,
		BorderSizePixel = 0, GroupTransparency = 1, ClipsDescendants = true,
		Parent = self.NotificationGui,
	}, { corner(14), stroke(THEME.Border, 0.22) })
	local status = create("Frame", {
		Name = "ToastStatus", Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, Parent = frame,
	}, { corner(11), stroke(tint, 0.34) })
	local statusMark = create("Frame", {
		Name = "StatusMark", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = status,
	})
	local markParts = options.Type == "Success"
		and { { 13, 18, 7, 2, 45 }, { 20, 15, 12, 2, -45 } }
		or options.Type == "Error"
		and { { 17, 17, 13, 2, 45 }, { 17, 17, 13, 2, -45 } }
		or { { 17, 17, 12, 2, 0 } }
	for _, part in ipairs(markParts) do
		create("Frame", {
			Name = "MarkLine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(part[1], part[2]),
			Size = UDim2.fromOffset(part[3], part[4]), Rotation = part[5],
			BackgroundColor3 = tint, BorderSizePixel = 0, Parent = statusMark,
		}, { corner(1) })
	end
	create("TextLabel", { Name = "ToastTitle", Position = UDim2.fromOffset(60, 11), Size = UDim2.new(1, -104, 0, 22),
		Text = options.Title or "FrostScripts", TextColor3 = THEME.Text, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, Font = Enum.Font.BuilderSansBold, Parent = frame })
	create("TextLabel", { Name = "ToastBody", Position = UDim2.fromOffset(60, 34), Size = UDim2.new(1, -104, 0, 19),
		Text = options.Text or "", TextColor3 = THEME.Muted, BackgroundTransparency = 1, TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextSize = 11, Font = Enum.Font.BuilderSansMedium, Parent = frame })
	local close = create("TextButton", {
		Name = "ToastClose", Position = UDim2.new(1, -38, 0, 10), Size = UDim2.fromOffset(28, 28),
		Text = "", AutoButtonColor = false, BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0, Parent = frame,
	}, { corner(9) })
	local closeLines = {}
	for _, rotation in ipairs({ 45, -45 }) do
		table.insert(closeLines, create("Frame", {
			Name = "CloseLine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 1), Rotation = rotation,
			BackgroundColor3 = THEME.Muted, BorderSizePixel = 0, Parent = close,
		}, { corner(1) }))
	end
	local track = create("Frame", {
		Name = "ToastProgressTrack", Position = UDim2.new(0, 14, 1, -9), Size = UDim2.new(1, -28, 0, 3),
		BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, ClipsDescendants = true, Parent = frame,
	}, { corner(2) })
	local progress = create("Frame", {
		Name = "ToastProgress", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tint, BackgroundTransparency = 0.14, BorderSizePixel = 0, Parent = track,
	}, { corner(2) })
	local connections = {}
	local dismissed = false
	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end
	local function disconnectAll()
		for _, connection in ipairs(connections) do
			if connection.Connected then connection:Disconnect() end
		end
	end
	local function dismiss()
		if dismissed then return end
		dismissed = true
		disconnectAll()
		frame:Destroy()
		if not self._destroyed then self:_layoutNotifications() end
	end
	connect(close.MouseEnter, function()
		self:_tween(close, 0.12, { BackgroundColor3 = THEME.SurfaceHover })
		for _, line in ipairs(closeLines) do self:_tween(line, 0.12, { BackgroundColor3 = THEME.Text }) end
	end)
	connect(close.MouseLeave, function()
		self:_tween(close, 0.12, { BackgroundColor3 = THEME.Surface })
		for _, line in ipairs(closeLines) do self:_tween(line, 0.12, { BackgroundColor3 = THEME.Muted }) end
	end)
	connect(frame.MouseEnter, function() self:_tween(frame, 0.12, { BackgroundColor3 = THEME.Surface }) end)
	connect(frame.MouseLeave, function() self:_tween(frame, 0.12, { BackgroundColor3 = THEME.PanelRaised }) end)
	connect(close.Activated, dismiss)
	table.insert(self.Notifications, frame)
	self:_layoutNotifications()
	self:_queueTextScale()
	local targetPosition = frame.Position
	local left = (self.NotificationPosition or "Bottom Right"):find("Left", 1, true) ~= nil
	frame.Position = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset + (left and -14 or 14),
		targetPosition.Y.Scale, targetPosition.Y.Offset)
	self:_tween(frame, 0.2, { GroupTransparency = 0, Position = targetPosition }, Enum.EasingStyle.Quart)
	if self.Animations then self:_tween(progress, duration, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear) end
	task.delay(duration, function()
		if dismissed or self._destroyed or not frame.Parent then disconnectAll(); return end
		local exitPosition = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset + (left and -10 or 10),
			frame.Position.Y.Scale, frame.Position.Y.Offset)
		self:_tween(frame, 0.16, { GroupTransparency = 1, Position = exitPosition }, Enum.EasingStyle.Quart)
		task.delay(self.Animations and 0.17 or 0, dismiss)
	end)
	return frame
end


function Window:AddWorldMarker(instances, object, options)
	options = options or {}
	instances = instances or {}
	local color = options.Color or THEME.Accent
	local adornment = object:IsA("Model") and object or object:FindFirstAncestorWhichIsA("Model") or object
	local part = options.Adornee
	if not (typeof(part) == "Instance" and part:IsA("BasePart")) then
		part = adornment:IsA("BasePart") and adornment or adornment:FindFirstChildWhichIsA("BasePart", true)
	end
	if not part then return end
	local highlight
	if options.Highlight ~= false then
		highlight = Instance.new("Highlight")
		highlight.Name = "FrostScriptsMarker"
		highlight.Adornee = adornment
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = color
		highlight.FillTransparency = 0.8
		highlight.OutlineColor = color
		highlight.OutlineTransparency = 0.18
		highlight.Parent = adornment
		instances[highlight] = true
	end
	local scale = math.clamp(tonumber(options.Scale) or 1, 0.1, 1.8)
	local baseWidth = math.max(80, tonumber(options.Width) or 220)
	local baseHeight = math.max(28, tonumber(options.Height) or 52)
	local titleTextSize = math.max(8, tonumber(options.TitleTextSize) or 14)
	local detailTextSize = math.max(8, tonumber(options.DetailTextSize) or 12)
	local compact = options.Compact == true
	local horizontalPadding = compact and 10 or 14
	local titleY = compact and 3 or 5
	local detailY = compact and math.floor(baseHeight * 0.52) or 26
	local offset = typeof(options.Offset) == "Vector3" and options.Offset or Vector3.new(0, 2.5, 0)
	local sizeOffset = typeof(options.SizeOffset) == "Vector2" and options.SizeOffset or Vector2.zero
	local billboard = create("BillboardGui", {
		Name = "FrostScriptsLabel",
		Adornee = part,
		AlwaysOnTop = true,
		MaxDistance = tonumber(options.MaxDistance) or 750,
		Size = UDim2.fromOffset(baseWidth * scale, baseHeight * scale),
		StudsOffsetWorldSpace = offset,
		SizeOffset = sizeOffset,
		Parent = self.OverlayGui,
	})
	local panelStroke = stroke(color, 0.22)
	local panel = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Background,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = billboard,
	}, { corner(9), panelStroke })
	local titleLabel = create("TextLabel", {
		Position = UDim2.fromOffset(horizontalPadding * scale, titleY * scale),
		Size = UDim2.new(1, -horizontalPadding * 2 * scale, 0, (compact and 17 or 21) * scale),
		BackgroundTransparency = 1,
		Text = options.Title or "Marker",
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = titleTextSize * scale,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = panel,
	})
	local detailLabel = create("TextLabel", {
		Position = UDim2.fromOffset(horizontalPadding * scale, detailY * scale),
		Size = UDim2.new(1, -horizontalPadding * 2 * scale, 0, (compact and 14 or 18) * scale),
		BackgroundTransparency = 1,
		Text = options.Detail or "Marker",
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansMedium,
		TextSize = detailTextSize * scale,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = panel,
	})
	instances[billboard] = true
	local marker = {
		Billboard = billboard,
		Highlight = highlight,
	}
	local function applyGeometry()
		billboard.Size = UDim2.fromOffset(baseWidth * scale, baseHeight * scale)
		titleLabel.Position = UDim2.fromOffset(horizontalPadding * scale, titleY * scale)
		titleLabel.Size = UDim2.new(1, -horizontalPadding * 2 * scale, 0, (compact and 17 or 21) * scale)
		titleLabel.TextSize = titleTextSize * scale
		detailLabel.Position = UDim2.fromOffset(horizontalPadding * scale, detailY * scale)
		detailLabel.Size = UDim2.new(1, -horizontalPadding * 2 * scale, 0, (compact and 14 or 18) * scale)
		detailLabel.TextSize = detailTextSize * scale
	end
	function marker:Update(nextOptions)
		nextOptions = nextOptions or {}
		local nextColor = nextOptions.Color or color
		local nextScale = math.clamp(tonumber(nextOptions.Scale) or scale, 0.1, 1.8)
		titleLabel.Text = nextOptions.Title or titleLabel.Text
		detailLabel.Text = nextOptions.Detail or detailLabel.Text
		detailLabel.TextColor3 = nextColor
		panelStroke.Color = nextColor
		billboard.MaxDistance = tonumber(nextOptions.MaxDistance) or billboard.MaxDistance
		if typeof(nextOptions.Adornee) == "Instance" and nextOptions.Adornee:IsA("BasePart") then
			billboard.Adornee = nextOptions.Adornee
		end
		if typeof(nextOptions.Offset) == "Vector3" then
			billboard.StudsOffsetWorldSpace = nextOptions.Offset
		end
		if typeof(nextOptions.SizeOffset) == "Vector2" then
			billboard.SizeOffset = nextOptions.SizeOffset
		end
		if nextScale ~= scale then
			scale = nextScale
			applyGeometry()
		end
		if highlight then
			highlight.FillColor = nextColor
			highlight.OutlineColor = nextColor
		end
		color = nextColor
	end
	function marker:Destroy()
		if highlight then
			instances[highlight] = nil
			if highlight.Parent then highlight:Destroy() end
		end
		instances[billboard] = nil
		if billboard.Parent then billboard:Destroy() end
	end
	return marker
end

function Window:Destroy()
	if self._destroyed then return end
	if self.Cursor then
		self.CustomCursorEnabled = false
		self:_syncCursor()
	end
	self._destroyed = true
	if self._ambientConnection then self._ambientConnection:Disconnect(); self._ambientConnection = nil end
	self:CloseDropdown()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
	for _, running in pairs(self._tweens) do
		for _, animation in pairs(running) do animation:Cancel() end
	end
	table.clear(self._tweens)
	if self.Gui then self.Gui:Destroy() end
	if self.OverlayGui then self.OverlayGui:Destroy() end
	if self.NotificationGui then self.NotificationGui:Destroy() end
end

function Window:_applyTheme()
	for _, running in pairs(self._tweens) do
		for property, animation in pairs(running) do
			if property:find("Color") then animation:Cancel(); running[property] = nil end
		end
	end
	local function apply(root)
		if not root then return end
		local objects = root:GetDescendants()
		table.insert(objects, root)
		for _, object in ipairs(objects) do
			for attribute, themeKey in pairs(object:GetAttributes()) do
				local property = attribute:match("^FrostTheme_(.+)$")
				if property and THEME[themeKey] then
					pcall(function()
						object[property] = THEME[themeKey]
					end)
				end
			end
		end
	end
	apply(self.Gui)
	apply(self.OverlayGui)
	apply(self.NotificationGui)
	if self.ActiveTab then
		for _, item in ipairs(self.Tabs) do
			local selected = item == self.ActiveTab
			item.Button.BackgroundColor3 = selected and THEME.AccentSoft or THEME.Panel
			item.Label.TextColor3 = selected and THEME.Text or THEME.Muted
			item.IconLabel.TextColor3 = selected and THEME.Accent or THEME.Muted
			item.IconLabel.BackgroundColor3 = selected and THEME.AccentSoft or THEME.Surface
			item.Indicator.BackgroundColor3 = THEME.Accent
			item.Indicator.BackgroundTransparency = selected and 0 or 1
		end
	end
end

function Window:SetTheme(themeName)
	local source = THEMES[themeName]
	if not source then return false end
	self.ThemeName = themeName
	self:_remember("ThemeName", themeName)
	self:_remember("CustomAccent", nil)
	self:_remember("CustomSuccess", nil)
	for key, value in pairs(source) do
		THEME[key] = value
	end
	self:_applyTheme()
	for _, gallery in ipairs(self.ThemeGalleries or {}) do gallery:Refresh() end
	return true
end

function Window:SetThemeColor(key, color)
	if not THEME[key] or typeof(color) ~= "Color3" then return false end
	THEME[key] = color
	if key == "Accent" or key == "Success" then self:_remember("Custom" .. key, color) end
	self.CustomTheme = true
	self:_applyTheme()
	return true
end

function Window:GetThemeColor(key)
	return THEME[key]
end

function Window:GetThemeNames()
	return { "Black", "Graphite", "Midnight", "Frost", "Amethyst", "Forest", "Ember", "Rose", "Neon", "Hayfield" }
end

function Module:AddColorPicker(name, default, callback)
	self:_index(name)
	local value = typeof(default) == "Color3" and default or THEME.Accent
	local preview = self:_row(54)
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -96, 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		Parent = preview,
	})
	local swatch = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(52, 30),
		BackgroundColor3 = value,
		BorderSizePixel = 0,
		Parent = preview,
	}, { corner(8), stroke(THEME.Border, 0.35) })
	local control = { Module = self, Value = value }
	local channels = {
		{ "R", function(color) return math.floor(color.R * 255 + 0.5) end },
		{ "G", function(color) return math.floor(color.G * 255 + 0.5) end },
		{ "B", function(color) return math.floor(color.B * 255 + 0.5) end },
	}
	local values = {
		R = channels[1][2](value),
		G = channels[2][2](value),
		B = channels[3][2](value),
	}
	local function refresh(silent)
		control.Value = Color3.fromRGB(values.R, values.G, values.B)
		swatch.BackgroundColor3 = control.Value
		if not silent then safeCall(control.Module.Window, callback, control.Value) end
	end
	local sliders = {}
	for _, channel in ipairs(channels) do
		sliders[channel[1]] = self:AddSlider(name .. " " .. channel[1], 0, 255, values[channel[1]], function(nextValue)
			values[channel[1]] = nextValue
			refresh(false)
		end, { Step = 1 })
	end
	function control:SetValue(color, silent)
		if typeof(color) ~= "Color3" then return end
		values.R = math.floor(color.R * 255 + 0.5)
		values.G = math.floor(color.G * 255 + 0.5)
		values.B = math.floor(color.B * 255 + 0.5)
		for channel, slider in pairs(sliders) do slider:SetValue(values[channel], true) end
		refresh(silent)
	end
	return control
end

-- @include Icons.lua

-- @include ThemeGallery.lua

-- @include Experience.lua

-- @include Cards.lua

-- @include Shell.lua

function Library.new(options)
	return Library:CreateWindow(options)
end

Library.Theme = THEME
Library.Themes = THEMES

return Library
