-- Universal entry; invoked by FrostScriptsAPI.RunGame in any Roblox experience.
local API = ...
assert(type(API) == "table" and type(API.CreateFeature) == "function",
	"Launch Universal through the FrostScripts library")

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local VirtualUser
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local player = Players.LocalPlayer
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.FrostScriptsUniversal and type(env.FrostScriptsUniversal.Unload) == "function" then
	pcall(function() env.FrostScriptsUniversal:Unload() end)
end

local Interface
local scope = API.CreateScope()
local features = {}

local function addFeature(feature)
	table.insert(features, feature)
	return feature
end

local function getCharacter()
	return API.GetCharacter(player)
end

local Flight = addFeature(API.UniversalModules.CreateFlight({
	Name = "Flight",
	Speed = 70,
	VerticalSpeed = 50,
	ToggleKey = Enum.KeyCode.F,
	IsInputCaptured = function() return Interface and Interface:IsCapturingInput() end,
}))

local WalkSpeed = addFeature(API.CreateFeature("Walk Speed", {
	Speed = 32,
	ToggleKey = Enum.KeyCode.G,
}))

function WalkSpeed:OnEnable()
	self._original = setmetatable({}, { __mode = "k" })
	self:Track(RunService.Heartbeat:Connect(function()
		local _, humanoid = getCharacter()
		if humanoid and humanoid.Health > 0 then
			if self._original[humanoid] == nil then self._original[humanoid] = humanoid.WalkSpeed end
			if humanoid.WalkSpeed ~= self.Settings.Speed then humanoid.WalkSpeed = self.Settings.Speed end
		end
	end))
	self:SetStatus("Holding walk speed at " .. tostring(self.Settings.Speed))
	return true
end

function WalkSpeed:OnSettingChanged(key, value)
	if key == "Speed" and self.Enabled then self:SetStatus("Holding walk speed at " .. tostring(value)) end
end

function WalkSpeed:OnDisable()
	for humanoid, value in pairs(self._original or {}) do
		if humanoid.Parent then pcall(function() humanoid.WalkSpeed = value end) end
	end
	self._original = nil
	self:SetStatus("Walk speed restored")
end

local JumpPower = addFeature(API.CreateFeature("Jump Power", {
	Power = 75,
	ToggleKey = Enum.KeyCode.J,
}))

function JumpPower:OnEnable()
	self._original = setmetatable({}, { __mode = "k" })
	self:Track(RunService.Heartbeat:Connect(function()
		local _, humanoid = getCharacter()
		if humanoid and humanoid.Health > 0 then
			if not self._original[humanoid] then
				self._original[humanoid] = {
					JumpPower = humanoid.JumpPower,
					UseJumpPower = humanoid.UseJumpPower,
				}
			end
			if not humanoid.UseJumpPower then humanoid.UseJumpPower = true end
			if humanoid.JumpPower ~= self.Settings.Power then humanoid.JumpPower = self.Settings.Power end
		end
	end))
	self:SetStatus("Holding jump power at " .. tostring(self.Settings.Power))
	return true
end

function JumpPower:OnSettingChanged(key, value)
	if key == "Power" and self.Enabled then self:SetStatus("Holding jump power at " .. tostring(value)) end
end

function JumpPower:OnDisable()
	for humanoid, previous in pairs(self._original or {}) do
		if humanoid.Parent then
			pcall(function()
				humanoid.JumpPower = previous.JumpPower
				humanoid.UseJumpPower = previous.UseJumpPower
			end)
		end
	end
	self._original = nil
	self:SetStatus("Jump settings restored")
end

local InfiniteJump = addFeature(API.CreateFeature("Infinite Jump", {
	ToggleKey = Enum.KeyCode.I,
}))

function InfiniteJump:OnEnable()
	self:Track(UserInputService.JumpRequest:Connect(function()
		local _, humanoid = getCharacter()
		if humanoid and humanoid.Health > 0 and not UserInputService:GetFocusedTextBox() then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end))
	self:SetStatus("Jump again while airborne")
	return true
end

function InfiniteJump:OnDisable()
	self:SetStatus("Normal jumping restored")
end

local Noclip = addFeature(API.CreateFeature("Noclip", {
	ToggleKey = Enum.KeyCode.N,
}))

function Noclip:OnEnable()
	self._collidable = setmetatable({}, { __mode = "k" })
	self:Track(RunService.Stepped:Connect(function()
		local character = player.Character
		if not character then return end
		for _, object in ipairs(character:GetDescendants()) do
			if object:IsA("BasePart") and object.CanCollide then
				self._collidable[object] = true
				object.CanCollide = false
			end
		end
	end))
	self:SetStatus("Character collision disabled")
	return true
end

function Noclip:OnDisable()
	for part in pairs(self._collidable or {}) do
		if part.Parent then pcall(function() part.CanCollide = true end) end
	end
	self._collidable = nil
	self:SetStatus("Character collision restored")
end

local AutoClicker = addFeature(API.UniversalModules.CreateAutoClicker({
	Name = "Auto Clicker",
	ClicksPerSecond = 8,
	ToggleKey = Enum.KeyCode.V,
	IsInputCaptured = function() return Interface and Interface:IsCapturingInput() end,
}))

local Fullbright = addFeature(API.CreateFeature("Fullbright", {
	Brightness = 3,
	ClockTime = 14,
	RemoveFog = true,
	ToggleKey = Enum.KeyCode.B,
}))

local LIGHTING_PROPERTIES = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogEnd", "GlobalShadows" }

function Fullbright:_apply()
	if self._applying then return end
	self._applying = true
	Lighting.Ambient = Color3.fromRGB(178, 178, 178)
	Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	Lighting.Brightness = self.Settings.Brightness
	Lighting.ClockTime = self.Settings.ClockTime
	Lighting.GlobalShadows = false
	if self.Settings.RemoveFog then Lighting.FogEnd = 100000 end
	self._applying = false
end

function Fullbright:OnEnable()
	self._previous = {}
	for _, property in ipairs(LIGHTING_PROPERTIES) do self._previous[property] = Lighting[property] end
	self:_apply()
	for _, property in ipairs(LIGHTING_PROPERTIES) do
		self:Track(Lighting:GetPropertyChangedSignal(property):Connect(function()
			if self.Enabled and not self._applying then task.defer(function() if self.Enabled then self:_apply() end end) end
		end))
	end
	self:SetStatus("Lighting override active")
	return true
end

function Fullbright:OnSettingChanged()
	if self.Enabled then self:_apply() end
end

function Fullbright:OnDisable()
	for property, value in pairs(self._previous or {}) do pcall(function() Lighting[property] = value end) end
	self._previous = nil
	self:SetStatus("Lighting restored")
end

local AntiAFK = addFeature(API.CreateFeature("Anti-AFK", {
	ToggleKey = Enum.KeyCode.K,
}))

function AntiAFK:OnEnable()
	if not VirtualUser then
		self:SetStatus("VirtualUser unavailable")
		return false
	end
	self._prevented = 0
	self:Track(player.Idled:Connect(function()
		self._prevented += 1
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
			task.wait(0.05)
			VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
		end)
		self:SetStatus(string.format("Prevented %d idle kick%s", self._prevented, self._prevented == 1 and "" or "s"))
	end))
	self:SetStatus("Waiting for idle events")
	return true
end

function AntiAFK:OnDisable()
	self:SetStatus("Idle protection disabled")
end

local Performance = addFeature(API.CreateFeature("Performance Mode", {
	ToggleKey = Enum.KeyCode.P,
}))

local EFFECT_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Smoke = true,
	Fire = true,
	Sparkles = true,
}

function Performance:_reduce(object)
	if EFFECT_CLASSES[object.ClassName] and object.Enabled then
		if self._effects[object] == nil then self._effects[object] = true end
		object.Enabled = false
	end
end

function Performance:OnEnable()
	self._effects = setmetatable({}, { __mode = "k" })
	for _, object in ipairs(workspace:GetDescendants()) do self:_reduce(object) end
	self:Track(workspace.DescendantAdded:Connect(function(object) self:_reduce(object) end))
	local count = 0
	for _ in pairs(self._effects) do count += 1 end
	self:SetStatus(string.format("Disabled %d local effects", count))
	return true
end

function Performance:OnDisable()
	for object, enabled in pairs(self._effects or {}) do
		if object.Parent then pcall(function() object.Enabled = enabled end) end
	end
	self._effects = nil
	self:SetStatus("Local effects restored")
end

local UI = API.LoadUI()
Interface = UI.new({
	TextScope = "Universal",
	Name = "FrostScripts",
	Game = "Universal",
	GuiName = "FrostScriptsUniversalUI",
	OverlayName = "FrostScriptsUniversalOverlays",
})

local Home = Interface:AddTab("Home", "home", "Universal tools and session controls")
local Modules = Interface:AddTab("Modules", "modules", "Tools that work across Roblox experiences")
local Settings = Interface:AddTab("UI Settings", "settings", "Appearance, motion, and sound")
Home:SetDashboardLayout()

local overview = Home:AddModule({
	Name = "Universal ready",
	Description = "9 modules available in every game",
	Accent = true,
	Collapsible = false,
})
overview:AddParagraph("Included tools",
	"Flight, speed and jump controls, infinite jump, noclip, auto clicker, anti-AFK, fullbright, and local effect reduction.",
	{ Height = 82 })

local actions = Home:AddModule({
	Name = "Session controls",
	Description = "Quick controls for the current game",
	Collapsible = false,
})

local function stopAll()
	for _, feature in ipairs(features) do feature:SetEnabled(false) end
	Interface:Notify({ Title = "Modules stopped", Text = "All universal modules were disabled.", Type = "Info" })
end

actions:AddButton("Disable all modules", stopAll, { Danger = true })
actions:AddButton("Open Modules", function() Interface:SelectTab(Modules) end)

local function addFeatureModule(feature, description)
	local module = Modules:AddModule({
		Name = feature.Name,
		Description = description,
		Feature = feature,
		Toggleable = true,
		Default = feature.Enabled,
		Callback = function(enabled) feature:SetEnabled(enabled) end,
	})
	module:AddKeybind({
		Name = "Toggle " .. feature.Name,
		Get = function() return feature.Settings.ToggleKey end,
		Set = function(key) feature:SetSetting("ToggleKey", key) end,
		OnPressed = function() feature:SetEnabled(not feature.Enabled) end,
	})
	return module
end

local function addSlider(module, feature, name, key, minimum, maximum, step, formatter)
	return module:AddSlider(name, minimum, maximum, feature.Settings[key], function(value)
		feature:SetSetting(key, value)
	end, { Step = step, Formatter = formatter })
end

local ON_OFF = {
	{ Label = "On", Value = true },
	{ Label = "Off", Value = false },
}

local flightModule = addFeatureModule(Flight, "Camera-relative WASD flight with separate horizontal and vertical speeds")
addSlider(flightModule, Flight, "Flight speed", "Speed", 10, 200, 5)
addSlider(flightModule, Flight, "Vertical speed", "VerticalSpeed", 10, 150, 5)

local walkModule = addFeatureModule(WalkSpeed, "Keeps the local humanoid at your selected walk speed")
addSlider(walkModule, WalkSpeed, "Walk speed", "Speed", 8, 200, 2)

local jumpModule = addFeatureModule(JumpPower, "Keeps the local humanoid at your selected jump power")
addSlider(jumpModule, JumpPower, "Jump power", "Power", 25, 250, 5)

addFeatureModule(InfiniteJump, "Lets the local character jump again while airborne")
addFeatureModule(Noclip, "Disables collision on local character parts and restores it when stopped")

local clickModule = addFeatureModule(AutoClicker, "Sends repeated primary clicks while the UI is not capturing input")
addSlider(clickModule, AutoClicker, "Clicks per second", "ClicksPerSecond", 1, 30, 1)

local brightModule = addFeatureModule(Fullbright, "Overrides local lighting, time, shadows, and fog for visibility")
addSlider(brightModule, Fullbright, "Brightness", "Brightness", 1, 10, 0.5)
addSlider(brightModule, Fullbright, "Clock time", "ClockTime", 0, 24, 1, function(value)
	return string.format("%02d:00", value)
end)
brightModule:AddDropdown("Remove fog", ON_OFF, Fullbright.Settings.RemoveFog, function(value)
	Fullbright:SetSetting("RemoveFog", value)
end)

addFeatureModule(AntiAFK, "Responds to Roblox idle events to prevent automatic idle kicks")
addFeatureModule(Performance, "Disables local particles, trails, beams, smoke, fire, and sparkles")

local server = Modules:AddModule({
	Name = "Server Tools",
	Description = "Reconnect to the current place or unload the Universal suite",
	Collapsible = false,
})
server:AddButton("Rejoin current server", function()
	Interface:Notify({ Title = "Rejoining", Text = "Connecting to the current place…", Type = "Info" })
	if #Players:GetPlayers() <= 1 then
		TeleportService:Teleport(game.PlaceId, player)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end
end)

Interface:AddClientSettings(Settings)
Interface:SelectTab(Home)

local Suite = {
	Window = Interface,
	Interface = Interface,
	Features = features,
}

function Suite:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for _, feature in ipairs(features) do feature:Destroy() end
	scope:Destroy()
	Interface:Destroy()
	if env.FrostScriptsUniversal == self then env.FrostScriptsUniversal = nil end
end

scope:Track(player.CharacterAdded:Connect(function()
	-- Flight owns character movers and must be restarted after Roblox creates a new rig.
	Flight:SetEnabled(false)
end))

env.FrostScriptsUniversal = Suite
server:AddButton("Unload FrostScripts", function() Suite:Unload() end, { Danger = true })
return Suite
