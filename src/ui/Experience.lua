-- UI-only motion, background, feedback, and preferences.
local RunService = game:GetService("RunService")

function Window:_remember(key, value)
	if self.UIState then self.UIState[key] = value end
end

function Window:PlaySound(kind)
	if self._destroyed or not self.Sounds or self.SoundVolume <= 0 then return end
	local now = os.clock()
	if now - (self._lastSound or -1) < (kind == "Hover" and 0.12 or 0.04) then return end
	self._lastSound = now
	local pitch = ({ Hover = 1.6, Click = 1.25, Open = 0.95, Notify = 1.1 })[kind] or 1.25
	pcall(function()
		self.UISound.Volume = self.SoundVolume * (kind == "Hover" and 0.35 or 1)
		self.UISound.PlaybackSpeed = pitch
		self.UISound.TimePosition = 0
		self.UISound:Play()
	end)
end

function Window:SetSounds(enabled)
	self.Sounds = enabled == true
	self:_remember("Sounds", self.Sounds)
	if not self.Sounds and self.UISound then self.UISound:Stop() end
end

function Window:SetSoundVolume(value)
	self.SoundVolume = math.clamp(tonumber(value) or 0.18, 0, 1)
	self:_remember("SoundVolume", self.SoundVolume)
	if self.UISound then self.UISound.Volume = self.SoundVolume end
end

function Window:SetNotifications(enabled)
	self.NotificationsEnabled = enabled == true
	self:_remember("NotificationsEnabled", self.NotificationsEnabled)
	if not self.NotificationsEnabled then
		for _, frame in ipairs(self.Notifications) do frame:Destroy() end
		table.clear(self.Notifications)
	end
end

function Window:SetModuleNotifications(enabled)
	self.ModuleNotificationsEnabled = enabled == true
	self:_remember("ModuleNotificationsEnabled", self.ModuleNotificationsEnabled)
end

function Window:SetNotificationPosition(position)
	local allowed = { ["Top Left"] = true, ["Top Right"] = true, ["Bottom Left"] = true, ["Bottom Right"] = true }
	if not allowed[position] then return false end
	self.NotificationPosition = position
	self:_remember("NotificationPosition", position)
	self:_layoutNotifications()
	return true
end

function Window:_syncCursor()
	if not self.Cursor then return end
	local active = self.CustomCursorEnabled and self.Visible and self.Cursor.Image ~= ""
	self.Cursor.Visible = active
	if self._cursorConnection then self._cursorConnection:Disconnect(); self._cursorConnection = nil end
	if active then
		if not self._ownsMouseIcon then
			pcall(function() self._savedMouseIconEnabled = UserInputService.MouseIconEnabled end)
			self._ownsMouseIcon = true
		end
		local function update()
			if self._destroyed or not self.Cursor.Visible then return end
			pcall(function()
				UserInputService.MouseIconEnabled = false
				local position = UserInputService:GetMouseLocation()
				self.Cursor.Position = UDim2.fromOffset(
					math.floor(position.X + 0.5), math.floor(position.Y - 0.5))
			end)
		end
		update()
		self._cursorConnection = RunService.RenderStepped:Connect(update)
	elseif self._ownsMouseIcon then
		pcall(function() UserInputService.MouseIconEnabled = self._savedMouseIconEnabled ~= false end)
		self._ownsMouseIcon = false
	end
end

function Window:SetCustomCursor(enabled)
	self.CustomCursorEnabled = enabled == true
	self:_remember("CustomCursorEnabled", self.CustomCursorEnabled)
	self:_syncCursor()
end

function Window:_initCursor()
	self.Cursor = create("ImageLabel", {
		Name = "FrostCursor", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(24, 32), BackgroundTransparency = 1, Image = "",
		ScaleType = Enum.ScaleType.Fit, Visible = false, Active = false, Selectable = false,
		Interactable = false, InputSink = Enum.InputSink.None, ZIndex = 1000,
		Parent = self.NotificationGui,
	})
	self:_syncCursor()
	if type(self.ResolveAsset) == "function" then
		task.spawn(function()
			local ok, content = pcall(self.ResolveAsset, self.CustomCursorAsset)
			if ok and type(content) == "string" and content ~= "" and not self._destroyed then
				self.Cursor.Image = content
				self:_syncCursor()
			end
		end)
	end
end

function Window:_syncAmbient()
	if self._ambientConnection then self._ambientConnection:Disconnect(); self._ambientConnection = nil end
	if not self.Ambient then return end
	self.Ambient.Visible = self.BackgroundEffects
	if self._destroyed or not self.Visible or not self.BackgroundEffects or not self.BackgroundAnimations or not self.Animations then return end
	local accumulated = 0
	self._ambientConnection = RunService.RenderStepped:Connect(function(delta)
		accumulated += delta
		if accumulated < 1 / 15 then return end
		self._ambientTime = (self._ambientTime or 0) + accumulated
		accumulated = 0
		local t = self._ambientTime
		for index, item in ipairs(self._aurora) do
			item.Gradient.Offset = Vector2.new(math.sin(t * 0.16 + index) * 0.32, 0)
			item.Frame.Rotation = -24 + math.sin(t * 0.11 + index) * 9
			item.Frame.Position = UDim2.fromScale(0.32 + math.sin(t * 0.08 + index) * 0.12, 0.22 + (index - 1) * 0.38)
		end
	end)
end

function Window:SetBackgroundEffects(enabled)
	self.BackgroundEffects = enabled == true
	self:_remember("BackgroundEffects", self.BackgroundEffects)
	self:_syncAmbient()
end

function Window:SetBackgroundAnimations(enabled)
	self.BackgroundAnimations = enabled == true
	self:_remember("BackgroundAnimations", self.BackgroundAnimations)
	self:_syncAmbient()
end

function Window:_initExperience()
	self._aurora, self._coverGradients = {}, {}
	self.Ambient = create("Frame", {
		Name = "AuroraBackground", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = 0, Parent = self.Frame,
	}, { corner(17) })
	for index = 1, 2 do
		local ribbon = create("Frame", {
		Name = "AuroraRibbon", Position = UDim2.fromScale(0.32, 0.22 + (index - 1) * 0.38),
			Size = UDim2.new(0.95, 0, 0, 210), Rotation = -24,
			BackgroundColor3 = THEME.Accent, BackgroundTransparency = 0.94,
			BorderSizePixel = 0, ZIndex = 0, Parent = self.Ambient,
		}, { corner(100) })
		local gradient = create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = ribbon,
		})
		table.insert(self._aurora, { Frame = ribbon, Gradient = gradient })
	end
	self.UISound = create("Sound", {
		Name = "FrostInterfaceSound", SoundId = self.UIState.SoundAsset or UI_DEFAULTS.SoundAsset,
		Volume = self.SoundVolume, Parent = self.Gui,
	})
	self:_syncAmbient()
end

function Window:ApplyPreferences()
	local state = self.UIState or {}
	local accent, success = state.CustomAccent, state.CustomSuccess
	self:SetAnimations(state.Animations ~= false)
	self:SetBackgroundEffects(state.BackgroundEffects == true)
	self:SetBackgroundAnimations(state.BackgroundAnimations == true)
	self:SetSounds(state.Sounds ~= false)
	self:SetSoundVolume(state.SoundVolume or 0.18)
	self:SetNotifications(state.NotificationsEnabled ~= false)
	self:SetModuleNotifications(state.ModuleNotificationsEnabled ~= false)
	self:SetNotificationPosition(state.NotificationPosition or "Bottom Right")
	self:SetCustomCursor(state.CustomCursorEnabled ~= false)
	self:SetTextScale(state.TextScale or 1)
	self:SetDimAmount(state.DimAmount or 40)
	self:SetSizePreset(state.SizePreset or "Large")
	self:SetMonitorWidth(state.MonitorWidth or 380)
	self:SetMonitorSide(state.MonitorSide or "Right")
	self:SetTheme(state.ThemeName or "Black")
	if accent then self:SetThemeColor("Accent", accent) end
	if success then self:SetThemeColor("Success", success) end
	for _, binding in ipairs(self.Keybinds) do binding:Refresh() end
	for _, refresh in ipairs(self._preferenceRefreshers or {}) do refresh() end
end

function Window:AddClientSettings(tab)
	self._preferenceRefreshers = self._preferenceRefreshers or {}
	local function bind(control, key)
		table.insert(self._preferenceRefreshers, function()
			local value = self.UIState[key]
			if value ~= nil then control:SetValue(value, true) end
		end)
		return control
	end
	self:AddThemeGallery(tab)
	local motion = tab:AddModule({ Name = "Motion & atmosphere", Description = "Set the pace of your workspace" })
	bind(motion:AddToggle("Interface animations", self.Animations, function(value) self:SetAnimations(value) end,
		"Turn off all movement for a still interface"), "Animations")
	bind(motion:AddToggle("Decorative background", self.BackgroundEffects, function(value) self:SetBackgroundEffects(value) end,
		"Soft gradients behind your workspace"), "BackgroundEffects")
	bind(motion:AddToggle("Animate background", self.BackgroundAnimations, function(value) self:SetBackgroundAnimations(value) end,
		"Pause ambient movement while keeping the artwork"), "BackgroundAnimations")
	local audio = tab:AddModule({ Name = "Sound & feedback", Description = "Small details, on your terms" })
	bind(audio:AddToggle("Interface sounds", self.Sounds, function(value) self:SetSounds(value) end), "Sounds")
	bind(audio:AddSlider("Sound volume", 0, 1, self.SoundVolume, function(value) self:SetSoundVolume(value) end,
		{ Step = 0.05, Formatter = function(value) return math.floor(value * 100) .. "%" end }), "SoundVolume")
	audio:AddButton("Preview sound", function() self:PlaySound("Open") end)
	bind(audio:AddToggle("Notifications", self.NotificationsEnabled, function(value) self:SetNotifications(value) end), "NotificationsEnabled")
	bind(audio:AddToggle("Module notifications", self.ModuleNotificationsEnabled,
		function(value) self:SetModuleNotifications(value) end,
		"Show a toast when modules are enabled or disabled"), "ModuleNotificationsEnabled")
	bind(audio:AddDropdown("Notification position", { "Top Left", "Top Right", "Bottom Left", "Bottom Right" },
		self.NotificationPosition, function(value) self:SetNotificationPosition(value) end), "NotificationPosition")
	local appearance = tab:AddModule({ Name = "Appearance", Description = "Color, type, and spacing" })
	appearance:AddColorPicker("Accent", THEME.Accent, function(value) self:SetThemeColor("Accent", value) end)
	bind(appearance:AddDropdown("Window size", { "Comfortable", "Large", "Extra Large" }, self.SizePreset,
		function(value) self:SetSizePreset(value) end), "SizePreset")
	bind(appearance:AddSlider("Text size", 1, 1.3, self.TextScale, function(value) self:SetTextScale(value) end,
		{ Step = 0.05, Formatter = function(value) return string.format("%.2fx", value) end }), "TextScale")
	bind(appearance:AddSlider("Background dim", 0, 75, self.DimAmount, function(value) self:SetDimAmount(value) end,
		{ Step = 5, Formatter = function(value) return value .. "%" end }), "DimAmount")
	local interface = tab:AddModule({ Name = "Window & overlays", Description = "Visibility and monitor placement" })
	bind(interface:AddToggle("Middle finger cursor", self.CustomCursorEnabled,
		function(value) self:SetCustomCursor(value) end,
		"Use the custom pointer while FrostScripts is open"), "CustomCursorEnabled")
	interface:AddKeybind({ Name = "Show / hide interface", AllowClear = false, IsVisibility = true,
		Get = function() return Enum.KeyCode[self.UIState.VisibilityKey or "RightShift"] or Enum.KeyCode.RightShift end,
		Set = function(key) self:_remember("VisibilityKey", key.Name) end,
		OnPressed = function() self:Toggle() end })
	bind(interface:AddDropdown("Monitor side", { "Left", "Right" }, self.MonitorSide, function(value) self:SetMonitorSide(value) end), "MonitorSide")
	bind(interface:AddSlider("Monitor width", 320, 520, self.MonitorWidth, function(value) self:SetMonitorWidth(value) end, { Step = 20 }), "MonitorWidth")
	return appearance, motion
end
