-- Universal entry; invoked by FrostScriptsAPI.RunGame in any Roblox experience.
local API = ...
assert(type(API) == "table" and type(API.CreateFeature) == "function",
	"Launch Universal through the FrostScripts library")

local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
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
local Updates = API.CreateUpdateManager({ SlowInterval = 0.1, StatsInterval = 0.75 })
local Character = API.CreateCharacterManager(player)
scope:Track(Updates)
scope:Track(Character)

local features = {}
local entries = {}
local modulesByName = {}
local recent = {}
local savedPositions = {}
local deathPosition
local selectedPlayerQuery = ""
local MobileControls
local gameName = game.Name
task.spawn(function()
	pcall(function() gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name end)
end)

local function getCharacter()
	return Character:Get()
end

local function notify(title, text, kind)
	if Interface then Interface:Notify({ Title = title, Text = text, Type = kind or "Info" }) end
end

local function addRecent(name)
	for index = #recent, 1, -1 do if recent[index] == name then table.remove(recent, index) end end
	table.insert(recent, 1, name)
	while #recent > 5 do table.remove(recent) end
	if Interface and Interface.RecentText then Interface.RecentText:SetText(table.concat(recent, "  •  ")) end
end

local function registerFeature(feature, category, description, configure, compatibility)
	table.insert(features, feature)
	table.insert(entries, {
		Feature = feature, Category = category, Description = description,
		Configure = configure, Compatibility = compatibility or "Universal",
	})
	scope:Track(feature:ObserveState(function(enabled) if enabled then addRecent(feature.Name) end end, false))
	return feature
end

local function registerLoopFeature(name, category, description, settings, bucket, step, cleanup, prepare)
	local feature = API.CreateFeature(name, settings or { ToggleKey = Enum.KeyCode.Unknown })
	if feature.Settings.ToggleKey == nil then feature.Settings.ToggleKey = Enum.KeyCode.Unknown end
	function feature:OnEnable()
		if prepare and prepare(self) == false then return false end
		self:Track(Updates:Register("Universal:" .. name, bucket, function(dt) step(self, dt) end))
		self:SetStatus("Active"); return true
	end
	function feature:OnDisable()
		if cleanup then cleanup(self) end
		self:SetStatus("Disabled")
	end
	return registerFeature(feature, category, description)
end

local function findPlayer(query)
	query = tostring(query or selectedPlayerQuery):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then return nil end
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= player and (candidate.Name:lower():sub(1, #query) == query
			or candidate.DisplayName:lower():sub(1, #query) == query) then return candidate end
	end
	return nil
end

local function rootOf(target)
	local character = target and target.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function copyText(value)
	local copied = false
	if type(env.setclipboard) == "function" then copied = pcall(env.setclipboard, tostring(value)) end
	notify(copied and "Copied" or "Clipboard unavailable", tostring(value), copied and "Success" or "Info")
	return copied
end

local function savePosition(name)
	local _, _, root = getCharacter()
	if not root then notify("Position", "Character is not ready", "Error"); return false end
	savedPositions[name or "home"] = root.CFrame
	notify("Position saved", name or "home", "Success"); return true
end

local function loadPosition(name)
	local target = savedPositions[name or "home"]
	local _, _, root = getCharacter()
	if not target or not root then notify("Position", "No saved position named " .. tostring(name or "home"), "Error"); return false end
	root.CFrame = target; addRecent("Return Position"); return true
end

local function rejoin()
	if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, player)
	else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end
end

local function serverHop(preferLarge)
	local ok, err = pcall(function()
		local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100",
			game.PlaceId, preferLarge and "Desc" or "Asc")
		local data = HttpService:JSONDecode(game:HttpGet(url))
		for _, server in ipairs(data.data or {}) do
			if server.id ~= game.JobId and server.playing < server.maxPlayers then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player); return
			end
		end
		error("No available server found")
	end)
	if not ok then notify("Server hop failed", tostring(err), "Error") end
end

local Flight = registerFeature(API.UniversalModules.CreateFlight({
	Name = "Flight", Speed = 70, VerticalSpeed = 50, ToggleKey = Enum.KeyCode.F,
	UpdateManager = Updates, CharacterManager = Character,
	IsInputCaptured = function() return Interface and Interface:IsCapturingInput() end,
	GetMoveVector = function() return MobileControls and MobileControls.Visible and MobileControls.Move or Vector2.zero end,
	GetVertical = function() return MobileControls and MobileControls.Visible and MobileControls.Vertical or 0 end,
}), "Movement", "Respawn-safe flight with character, hover, float, levitate, and vehicle modes", function(module, feature)
	module:AddDropdown("Flight mode", { "Character Flight", "Vehicle Flight", "Hover", "Float", "Levitate" }, feature.Settings.Mode,
		function(value) feature:SetSetting("Mode", value) end)
	module:AddDropdown("Flight style", { "Smooth Flight", "Instant Flight" }, feature.Settings.Style,
		function(value) feature:SetSetting("Style", value) end)
	module:AddDropdown("Direction", { "Camera-direction Flight", "Mouse-direction Flight", "Character-direction Flight" }, feature.Settings.Direction,
		function(value) feature:SetSetting("Direction", value) end)
	module:AddSlider("Flight speed", 10, 250, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 5 })
	module:AddSlider("Vertical speed", 10, 180, feature.Settings.VerticalSpeed, function(value) feature:SetSetting("VerticalSpeed", value) end, { Step = 5 })
	module:AddSlider("Inertia", 1, 30, feature.Settings.Inertia, function(value) feature:SetSetting("Inertia", value) end, { Step = 1 })
end)

local Noclip = API.CreateFeature("Noclip", { ToggleKey = Enum.KeyCode.N })
function Noclip:OnEnable()
	self._parts = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:Noclip", "Heartbeat", function()
		local character = Character.Character
		if not character then self:SetStatus("Waiting for character"); return end
		for _, object in ipairs(character:GetDescendants()) do
			if object:IsA("BasePart") and object.CanCollide then self._parts[object] = true; object.CanCollide = false end
		end
		self:SetStatus("Collision disabled")
	end)); return true
end
function Noclip:OnDisable()
	for part, value in pairs(self._parts or {}) do if part.Parent then pcall(function() part.CanCollide = value end) end end
	self._parts = nil; self:SetStatus("Collision restored")
end
registerFeature(Noclip, "Movement", "Disables local character collision and restores every changed part")

local Speed = API.CreateFeature("Speed", { Speed = 32, ToggleKey = Enum.KeyCode.Unknown })
function Speed:OnEnable()
	self._original = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:Speed", "Heartbeat", function()
		local _, humanoid = getCharacter()
		if humanoid and humanoid.Health > 0 then
			if self._original[humanoid] == nil then self._original[humanoid] = humanoid.WalkSpeed end
			humanoid.WalkSpeed = self.Settings.Speed; self:SetStatus("Holding " .. tostring(self.Settings.Speed) .. " walk speed")
		else self:SetStatus("Waiting for character") end
	end)); return true
end
function Speed:OnSettingChanged(key, value) if key == "Speed" and self.Enabled then self:SetStatus("Holding " .. tostring(value) .. " walk speed") end end
function Speed:OnDisable()
	for humanoid, value in pairs(self._original or {}) do if humanoid.Parent then pcall(function() humanoid.WalkSpeed = value end) end end
	self._original = nil; self:SetStatus("Walk speed restored")
end
registerFeature(Speed, "Movement", "Maintains a chosen local humanoid speed across respawns", function(module, feature)
	module:AddSlider("Walk speed", 8, 250, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 2 })
end)

local InfiniteJump = API.CreateFeature("Infinite Jump", { ToggleKey = Enum.KeyCode.J })
function InfiniteJump:OnEnable()
	self:Track(UserInputService.JumpRequest:Connect(function()
		local _, humanoid = getCharacter()
		if humanoid and humanoid.Health > 0 and not UserInputService:GetFocusedTextBox() then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)); self:SetStatus("Air jumps ready"); return true
end
function InfiniteJump:OnDisable() self:SetStatus("Normal jumping restored") end
registerFeature(InfiniteJump, "Movement", "Allows another jump while airborne on keyboard, controller, and Roblox mobile jump controls")

local JumpPower = API.CreateFeature("Jump Power", { Power = 75, ToggleKey = Enum.KeyCode.Unknown })
function JumpPower:OnEnable()
	self._original = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:JumpPower", "Heartbeat", function()
		local _, humanoid = getCharacter()
		if humanoid and humanoid.Health > 0 then
			if not self._original[humanoid] then self._original[humanoid] = { humanoid.JumpPower, humanoid.UseJumpPower } end
			humanoid.UseJumpPower = true; humanoid.JumpPower = self.Settings.Power
		end
	end)); self:SetStatus("Holding jump power"); return true
end
function JumpPower:OnDisable()
	for humanoid, old in pairs(self._original or {}) do if humanoid.Parent then humanoid.JumpPower, humanoid.UseJumpPower = old[1], old[2] end end
	self._original = nil; self:SetStatus("Jump power restored")
end
registerFeature(JumpPower, "Movement", "Maintains jump power across new characters", function(module, feature)
	module:AddSlider("Jump power", 25, 300, feature.Settings.Power, function(value) feature:SetSetting("Power", value) end, { Step = 5 })
end)

local Gravity = API.CreateFeature("Gravity", { Gravity = 100, ToggleKey = Enum.KeyCode.Unknown })
function Gravity:OnEnable()
	self._old = workspace.Gravity
	self:Track(Updates:Register("Universal:Gravity", "Slow", function() workspace.Gravity = self.Settings.Gravity end))
	self:SetStatus("Gravity set to " .. tostring(self.Settings.Gravity)); return true
end
function Gravity:OnDisable() if self._old then workspace.Gravity = self._old end; self:SetStatus("Gravity restored") end
registerFeature(Gravity, "Movement", "Overrides local world gravity", function(module, feature)
	module:AddSlider("Gravity", 0, 300, feature.Settings.Gravity, function(value) feature:SetSetting("Gravity", value) end, { Step = 5 })
end)

local Sprint = registerLoopFeature("Sprint", "Movement", "Raises walk speed only while Shift is held", { Speed = 48, ToggleKey = Enum.KeyCode.Unknown }, "Heartbeat", function(self)
	local _, humanoid = getCharacter(); if not humanoid then return end
	if not self._original then self._original = setmetatable({}, { __mode = "k" }) end
	if self._original[humanoid] == nil then self._original[humanoid] = humanoid.WalkSpeed end
	local held = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	humanoid.WalkSpeed = held and self.Settings.Speed or self._original[humanoid]
end, function(self)
	for humanoid, value in pairs(self._original or {}) do if humanoid.Parent then humanoid.WalkSpeed = value end end; self._original = nil
end)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Sprint speed", 16, 250, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 2 })
end

local BunnyHop = registerLoopFeature("Bunny Hop", "Movement", "Automatically jumps while the character is moving", { ToggleKey = Enum.KeyCode.Unknown }, "Heartbeat", function()
	local _, humanoid = getCharacter()
	if humanoid and humanoid.Health > 0 and humanoid.MoveDirection.Magnitude > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local AutoWalk = registerLoopFeature("Auto Walk", "Movement", "Continuously walks in the camera-facing direction", { ToggleKey = Enum.KeyCode.Unknown }, "Heartbeat", function()
	local _, humanoid = getCharacter(); local camera = workspace.CurrentCamera
	if humanoid and camera then humanoid:Move(Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z), false) end
end, function() local _, humanoid = getCharacter(); if humanoid then humanoid:Move(Vector3.zero, false) end end)

local SlowFall = registerLoopFeature("Slow Fall", "Movement", "Caps downward velocity for controllable descents", { FallSpeed = 18, ToggleKey = Enum.KeyCode.Unknown }, "Heartbeat", function(self)
	local _, _, root = getCharacter()
	if root and root.AssemblyLinearVelocity.Y < -self.Settings.FallSpeed then
		local velocity = root.AssemblyLinearVelocity; root.AssemblyLinearVelocity = Vector3.new(velocity.X, -self.Settings.FallSpeed, velocity.Z)
	end
end)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Maximum fall speed", 4, 80, feature.Settings.FallSpeed, function(value) feature:SetSetting("FallSpeed", value) end, { Step = 2 })
end

local FollowPlayer = registerLoopFeature("Follow Player", "Movement", "Walks toward the selected player without teleporting", { Distance = 6, ToggleKey = Enum.KeyCode.Unknown }, "Slow", function(self)
	local target = findPlayer(); local _, humanoid, root = getCharacter(); local targetRoot = rootOf(target)
	if not target or not humanoid or not root or not targetRoot then self:SetStatus("Select an online player"); return end
	if (root.Position - targetRoot.Position).Magnitude > self.Settings.Distance then humanoid:MoveTo(targetRoot.Position) end
	self:SetStatus("Following " .. target.Name)
end, function() local _, humanoid, root = getCharacter(); if humanoid and root then humanoid:MoveTo(root.Position) end end)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Follow distance", 2, 30, feature.Settings.Distance, function(value) feature:SetSetting("Distance", value) end, { Step = 1 })
end

local AirWalk = API.CreateFeature("Air Walk", { ToggleKey = Enum.KeyCode.Unknown })
function AirWalk:OnEnable()
	local platform = Instance.new("Part"); platform.Name = "FrostScriptsAirWalk"; platform.Size = Vector3.new(7, 0.4, 7)
	platform.Anchored = true; platform.CanCollide = true; platform.Transparency = 1; platform.Parent = workspace; self._platform = platform
	self:Track(Updates:Register("Universal:AirWalk", "Heartbeat", function()
		local _, _, root = getCharacter()
		if root then platform.CFrame = CFrame.new(root.Position - Vector3.new(0, 3.35, 0)); platform.Parent = workspace else platform.Parent = nil end
	end)); self:SetStatus("Invisible platform active"); return true
end
function AirWalk:OnDisable() if self._platform then self._platform:Destroy(); self._platform = nil end; self:SetStatus("Air walk disabled") end
registerFeature(AirWalk, "Movement", "Maintains one invisible collision platform beneath the character")

local Hover = registerLoopFeature("Hover", "Movement", "Holds altitude without taking over horizontal movement", { Strength = 10, ToggleKey = Enum.KeyCode.Unknown }, "Heartbeat", function(self)
	local _, _, root = getCharacter(); if not root then return end
	if self._lastRoot ~= root then self._lastRoot, self._height = root, root.Position.Y end
	local velocity = root.AssemblyLinearVelocity; local correction = math.clamp((self._height - root.Position.Y) * self.Settings.Strength, -45, 45)
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, correction, velocity.Z)
end, function(self) self._height, self._lastRoot = nil, nil end, function(self) local _, _, root = getCharacter(); self._lastRoot, self._height = root, root and root.Position.Y or nil; return root ~= nil end)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Hover response", 2, 30, feature.Settings.Strength, function(value) feature:SetSetting("Strength", value) end, { Step = 1 })
end

local VehicleFly = registerFeature(API.UniversalModules.CreateFlight({
	Name = "Vehicle Fly", Mode = "Vehicle Flight", Speed = 90, VerticalSpeed = 60,
	UpdateManager = Updates, CharacterManager = Character,
	IsInputCaptured = function() return Interface and Interface:IsCapturingInput() end,
	GetMoveVector = function() return MobileControls and MobileControls.Visible and MobileControls.Move or Vector2.zero end,
	GetVertical = function() return MobileControls and MobileControls.Visible and MobileControls.Vertical or 0 end,
}), "Movement", "Moves the assembly of the currently occupied vehicle seat", function(module, feature)
	module:AddSlider("Vehicle speed", 20, 300, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 5 })
	module:AddSlider("Vertical speed", 10, 200, feature.Settings.VerticalSpeed, function(value) feature:SetSetting("VerticalSpeed", value) end, { Step = 5 })
end, "Depends on vehicle")

local function characterPropertyFeature(name, description, property, valueKey, default, minimum, maximum, step)
	local feature = API.CreateFeature(name, { [valueKey] = default, ToggleKey = Enum.KeyCode.Unknown })
	function feature:OnEnable()
		self._old = setmetatable({}, { __mode = "k" })
		self:Track(Updates:Register("Universal:" .. name, "Heartbeat", function()
			local _, humanoid = getCharacter(); if not humanoid then return end
			if self._old[humanoid] == nil then self._old[humanoid] = humanoid[property] end
			humanoid[property] = self.Settings[valueKey]
		end)); self:SetStatus("Active"); return true
	end
	function feature:OnDisable()
		for humanoid, old in pairs(self._old or {}) do if humanoid.Parent then pcall(function() humanoid[property] = old end) end end
		self._old = nil; self:SetStatus("Restored")
	end
	registerFeature(feature, "Character", description, function(module, item)
		module:AddSlider(name, minimum, maximum, item.Settings[valueKey], function(value) item:SetSetting(valueKey, value) end, { Step = step })
	end); return feature
end

local HipHeight = characterPropertyFeature("Hip Height", "Changes the humanoid hip offset and restores it on disable", "HipHeight", "Height", 2, 0, 20, 0.5)
local Sit = registerLoopFeature("Sit", "Character", "Keeps the current humanoid seated", { ToggleKey = Enum.KeyCode.Unknown }, "Heartbeat",
	function() local _, humanoid = getCharacter(); if humanoid then humanoid.Sit = true end end,
	function() local _, humanoid = getCharacter(); if humanoid then humanoid.Sit = false end end)

local Ragdoll = API.CreateFeature("Local Ragdoll", { ToggleKey = Enum.KeyCode.Unknown })
function Ragdoll:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:LocalRagdoll", "Heartbeat", function()
		local _, humanoid = getCharacter(); if humanoid then
			if self._old[humanoid] == nil then self._old[humanoid] = humanoid.PlatformStand end; humanoid.PlatformStand = true
		end
	end)); self:SetStatus("Local physics ragdoll active"); return true
end
function Ragdoll:OnDisable() for humanoid, old in pairs(self._old or {}) do if humanoid.Parent then humanoid.PlatformStand = old end end; self:SetStatus("Ragdoll disabled") end
registerFeature(Ragdoll, "Character", "Uses local PlatformStand physics and restores the prior state")

local Transparency = API.CreateFeature("Transparency", { Amount = 0.65, ToggleKey = Enum.KeyCode.Unknown })
function Transparency:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:Transparency", "Slow", function()
		local character = Character.Character; if not character then return end
		for _, object in ipairs(character:GetDescendants()) do if object:IsA("BasePart") then
			if self._old[object] == nil then self._old[object] = object.LocalTransparencyModifier end; object.LocalTransparencyModifier = self.Settings.Amount
		end end
	end)); self:SetStatus("Character faded locally"); return true
end
function Transparency:OnDisable() for object, old in pairs(self._old or {}) do if object.Parent then object.LocalTransparencyModifier = old end end; self._old = nil; self:SetStatus("Transparency restored") end
registerFeature(Transparency, "Character", "Applies local-only transparency to every character part", function(module, feature)
	module:AddSlider("Transparency", 0, 1, feature.Settings.Amount, function(value) feature:SetSetting("Amount", value) end, { Step = 0.05 })
end)

local HideAccessories = API.CreateFeature("Hide Accessories", { ToggleKey = Enum.KeyCode.Unknown })
function HideAccessories:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:HideAccessories", "Slow", function()
		local character = Character.Character; if not character then return end
		for _, object in ipairs(character:GetChildren()) do if object:IsA("Accessory") then
			for _, part in ipairs(object:GetDescendants()) do if part:IsA("BasePart") then
				if self._old[part] == nil then self._old[part] = part.LocalTransparencyModifier end; part.LocalTransparencyModifier = 1
			end end
		end end
	end)); self:SetStatus("Accessories hidden locally"); return true
end
function HideAccessories:OnDisable()
	for part, old in pairs(self._old or {}) do if part.Parent then part.LocalTransparencyModifier = old end end
	self._old = nil; self:SetStatus("Accessories restored")
end
registerFeature(HideAccessories, "Character", "Hides accessory handles locally without deleting character assets")

local AnimationSpeed = registerLoopFeature("Animation Speed", "Character", "Adjusts the playback speed of current humanoid animations", { Speed = 1.5, ToggleKey = Enum.KeyCode.Unknown }, "Slow", function(self)
	local _, humanoid = getCharacter(); local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:AdjustSpeed(self.Settings.Speed) end end
end, function()
	local _, humanoid = getCharacter(); local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:AdjustSpeed(1) end end
end)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Playback speed", 0, 5, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 0.1 })
end

local Spin = registerLoopFeature("Spin", "Character", "Rotates the local root through the shared render scheduler", { DegreesPerSecond = 180, ToggleKey = Enum.KeyCode.Unknown }, "Render", function(self, dt)
	local _, _, root = getCharacter(); if root then root.CFrame *= CFrame.Angles(0, math.rad(self.Settings.DegreesPerSecond) * dt, 0) end
end)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Degrees per second", 30, 720, feature.Settings.DegreesPerSecond, function(value) feature:SetSetting("DegreesPerSecond", value) end, { Step = 15 })
end

local function trailFeature(name, colorA, colorB, category, description)
	local feature = API.CreateFeature(name, { ToggleKey = Enum.KeyCode.Unknown })
	function feature:_attach(character, _, root)
		for _, object in ipairs({ self._trail, self._a, self._b }) do if object then object:Destroy() end end
		if not root then return end
		local a = Instance.new("Attachment"); a.Position = Vector3.new(-1.2, 0, 0); a.Parent = root
		local b = Instance.new("Attachment"); b.Position = Vector3.new(1.2, 0, 0); b.Parent = root
		local trail = Instance.new("Trail"); trail.Name = "FrostScripts" .. name:gsub("%s", "")
		trail.Attachment0, trail.Attachment1 = a, b; trail.Lifetime = 0.65; trail.Color = ColorSequence.new(colorA, colorB); trail.Parent = root
		self._trail, self._a, self._b = trail, a, b
	end
	function feature:OnEnable()
		self:Track(Character:OnAdded(function(...) if self.Enabled then self:_attach(...) end end, false)); self:_attach(Character:Get()); self:SetStatus("Effect attached"); return true
	end
	function feature:OnDisable()
		for _, object in ipairs({ self._trail, self._a, self._b }) do if object then object:Destroy() end end
		self._trail, self._a, self._b = nil, nil, nil; self:SetStatus("Effect removed")
	end
	return registerFeature(feature, category, description)
end

local CharacterTrail = trailFeature("Character Trail", Color3.fromRGB(135, 225, 255), Color3.fromRGB(65, 120, 255), "Character", "Attaches a respawn-safe cyan trail")
local FrostTrail = trailFeature("Frost Trail", Color3.fromRGB(240, 255, 255), Color3.fromRGB(110, 190, 255), "Fun", "Adds a bright snow-colored motion trail")

local FrostAura = API.CreateFeature("Frost Aura", { Rate = 18, ToggleKey = Enum.KeyCode.Unknown })
function FrostAura:_attach(_, _, root)
	if self._emitter then self._emitter:Destroy() end; if not root then return end
	local emitter = Instance.new("ParticleEmitter"); emitter.Name = "FrostScriptsAura"; emitter.Texture = "rbxassetid://241594419"
	emitter.Rate = self.Settings.Rate; emitter.Lifetime = NumberRange.new(0.7, 1.3); emitter.Speed = NumberRange.new(0.4, 1.8)
	emitter.SpreadAngle = Vector2.new(180, 180); emitter.Color = ColorSequence.new(Color3.fromRGB(205, 245, 255), Color3.fromRGB(80, 160, 255))
	emitter.Parent = root; self._emitter = emitter
end
function FrostAura:OnEnable()
	self:Track(Character:OnAdded(function(...) if self.Enabled then self:_attach(...) end end, false)); self:_attach(Character:Get()); self:SetStatus("Frost particles active"); return true
end
function FrostAura:OnSettingChanged() if self._emitter then self._emitter.Rate = self.Settings.Rate end end
function FrostAura:OnDisable() if self._emitter then self._emitter:Destroy(); self._emitter = nil end; self:SetStatus("Aura removed") end
registerFeature(FrostAura, "Character", "Respawn-safe local particle aura", function(module, feature)
	module:AddSlider("Particle rate", 2, 60, feature.Settings.Rate, function(value) feature:SetSetting("Rate", value) end, { Step = 2 })
end)

local Freecam = API.CreateFeature("Freecam", { Speed = 80, Sensitivity = 0.22, FOV = 70, ToggleKey = Enum.KeyCode.G })
function Freecam:OnEnable()
	local camera = workspace.CurrentCamera; if not camera then return false end
	self._camera = camera; self._old = { Type = camera.CameraType, Subject = camera.CameraSubject, CFrame = camera.CFrame, FOV = camera.FieldOfView,
		MouseBehavior = UserInputService.MouseBehavior, MouseIconEnabled = UserInputService.MouseIconEnabled }
	self._position = camera.CFrame.Position; self._pitch, self._yaw = camera.CFrame:ToOrientation()
	camera.CameraType = Enum.CameraType.Scriptable; camera.FieldOfView = self.Settings.FOV
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter; UserInputService.MouseIconEnabled = false
	self:Track(Updates:Register("Universal:Freecam", "Render", function(dt)
		if workspace.CurrentCamera ~= camera then self:SetStatus("Waiting for camera"); return end
		local delta = UserInputService:GetMouseDelta()
		if MobileControls and MobileControls.Visible then delta += MobileControls:ConsumeLookDelta() end
		self._yaw -= delta.X * self.Settings.Sensitivity * 0.01
		self._pitch = math.clamp(self._pitch - delta.Y * self.Settings.Sensitivity * 0.01, -1.55, 1.55)
		local rotation = CFrame.fromOrientation(self._pitch, self._yaw, 0); local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += rotation.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= rotation.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += rotation.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= rotation.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) then move += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.yAxis end
		if MobileControls and MobileControls.Visible then move += rotation.RightVector * MobileControls.Move.X + rotation.LookVector * MobileControls.Move.Y + Vector3.yAxis * MobileControls.Vertical end
		if move.Magnitude > 1 then move = move.Unit end
		self._position += move * self.Settings.Speed * dt; camera.CFrame = CFrame.new(self._position) * rotation; camera.FieldOfView = self.Settings.FOV
	end)); self:SetStatus("WASD/QE free camera active"); return true
end
function Freecam:OnDisable()
	local camera, old = self._camera, self._old
	if camera and camera.Parent and old then camera.CameraType, camera.CameraSubject, camera.CFrame, camera.FieldOfView = old.Type, old.Subject, old.CFrame, old.FOV end
	if old then UserInputService.MouseBehavior, UserInputService.MouseIconEnabled = old.MouseBehavior, old.MouseIconEnabled end
	self._camera, self._old = nil, nil; self:SetStatus("Camera restored")
end
registerFeature(Freecam, "Camera", "Scriptable free camera with desktop mouse look and mobile directional controls", function(module, feature)
	module:AddSlider("Camera speed", 10, 300, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 5 })
	module:AddSlider("Mouse sensitivity", 0.05, 1, feature.Settings.Sensitivity, function(value) feature:SetSetting("Sensitivity", value) end, { Step = 0.05 })
	module:AddSlider("Field of view", 30, 120, feature.Settings.FOV, function(value) feature:SetSetting("FOV", value) end, { Step = 1 })
end)

local function cameraPropertyFeature(name, description, property, valueKey, default, minimum, maximum, step)
	local feature = API.CreateFeature(name, { [valueKey] = default, ToggleKey = Enum.KeyCode.Unknown })
	function feature:OnEnable()
		local camera = workspace.CurrentCamera; if not camera then return false end
		self._camera, self._old = camera, camera[property]
		self:Track(Updates:Register("Universal:" .. name, "Render", function() local current = workspace.CurrentCamera; if current then current[property] = self.Settings[valueKey] end end))
		self:SetStatus("Active"); return true
	end
	function feature:OnDisable() if self._camera and self._camera.Parent then self._camera[property] = self._old end; self:SetStatus("Restored") end
	registerFeature(feature, "Camera", description, function(module, item)
		module:AddSlider(name, minimum, maximum, item.Settings[valueKey], function(value) item:SetSetting(valueKey, value) end, { Step = step })
	end); return feature
end

local FieldOfView = cameraPropertyFeature("Field of View", "Maintains the selected camera FOV", "FieldOfView", "FOV", 90, 30, 120, 1)

local Fullbright = API.CreateFeature("Fullbright", { Brightness = 3, ClockTime = 14, RemoveFog = true, ToggleKey = Enum.KeyCode.B })
local LIGHTING_PROPERTIES = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogEnd", "GlobalShadows" }
function Fullbright:_apply()
	if self._applying then return end; self._applying = true
	Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	Lighting.Brightness = self.Settings.Brightness; Lighting.ClockTime = self.Settings.ClockTime; Lighting.GlobalShadows = false
	if self.Settings.RemoveFog then Lighting.FogEnd = 100000 end; self._applying = false
end
function Fullbright:OnEnable()
	self._previous = {}; for _, property in ipairs(LIGHTING_PROPERTIES) do self._previous[property] = Lighting[property] end; self:_apply()
	for _, property in ipairs(LIGHTING_PROPERTIES) do self:Track(Lighting:GetPropertyChangedSignal(property):Connect(function()
		if self.Enabled and not self._applying then task.defer(function() if self.Enabled then self:_apply() end end) end
	end)) end
	self:SetStatus("Lighting override active"); return true
end
function Fullbright:OnSettingChanged() if self.Enabled then self:_apply() end end
function Fullbright:OnDisable() for property, value in pairs(self._previous or {}) do pcall(function() Lighting[property] = value end) end; self:SetStatus("Lighting restored") end
registerFeature(Fullbright, "World", "Overrides local ambient light, time, shadows, and fog", function(module, feature)
	module:AddSlider("Brightness", 1, 10, feature.Settings.Brightness, function(value) feature:SetSetting("Brightness", value) end, { Step = 0.5 })
	module:AddSlider("Clock time", 0, 24, feature.Settings.ClockTime, function(value) feature:SetSetting("ClockTime", value) end, { Step = 1 })
	module:AddToggle("Remove fog", feature.Settings.RemoveFog, function(value) feature:SetSetting("RemoveFog", value) end)
end)

local AntiAFK = API.CreateFeature("Anti-AFK", { ToggleKey = Enum.KeyCode.Unknown })
function AntiAFK:OnEnable()
	if not VirtualUser then self:SetStatus("VirtualUser unavailable"); return false end
	self._prevented = 0
	self:Track(player.Idled:Connect(function()
		self._prevented += 1
		pcall(function()
			VirtualUser:CaptureController(); VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
			task.wait(0.05); VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
		end)
		self:SetStatus(string.format("Prevented %d idle kick%s", self._prevented, self._prevented == 1 and "" or "s"))
	end)); self:SetStatus("Waiting for idle events"); return true
end
function AntiAFK:OnDisable() self:SetStatus("Idle protection disabled") end
registerFeature(AntiAFK, "Utility", "Responds only when Roblox raises the local idle event")

local EFFECT_CLASSES = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }
local FPSBoost = API.CreateFeature("FPS Boost", { ToggleKey = Enum.KeyCode.Unknown })
function FPSBoost:_reduce(object)
	if (EFFECT_CLASSES[object.ClassName] or object:IsA("PostEffect")) and object.Enabled then
		if self._effects[object] == nil then self._effects[object] = object.Enabled end; object.Enabled = false
	end
end
function FPSBoost:OnEnable()
	self._effects = setmetatable({}, { __mode = "k" })
	for _, object in ipairs(workspace:GetDescendants()) do self:_reduce(object) end
	for _, object in ipairs(Lighting:GetChildren()) do self:_reduce(object) end
	self:Track(workspace.DescendantAdded:Connect(function(object) self:_reduce(object) end))
	local count = 0; for _ in pairs(self._effects) do count += 1 end
	self:SetStatus(string.format("Disabled %d local effects", count)); return true
end
function FPSBoost:OnDisable()
	for object, enabled in pairs(self._effects or {}) do if object.Parent then pcall(function() object.Enabled = enabled end) end end
	self._effects = nil; self:SetStatus("Local effects restored")
end
registerFeature(FPSBoost, "Performance", "Disables particles, trails, beams, smoke, fire, sparkles, and post-processing locally")

local function simplePropertyFeature(name, category, description, objectGetter, property, value, bucket)
	local feature = API.CreateFeature(name, { Value = value, ToggleKey = Enum.KeyCode.Unknown })
	function feature:OnEnable()
		self._objects = setmetatable({}, { __mode = "k" })
		self:Track(Updates:Register("Universal:" .. name, bucket or "Slow", function()
			local objects = objectGetter()
			if typeof(objects) == "Instance" then objects = { objects } end
			for _, object in ipairs(objects or {}) do if object and object.Parent then
				if self._objects[object] == nil then self._objects[object] = object[property] end
				object[property] = self.Settings.Value
			end end
		end)); self:SetStatus("Active"); return true
	end
	function feature:OnDisable()
		for object, old in pairs(self._objects or {}) do if object.Parent then pcall(function() object[property] = old end) end end
		self._objects = nil; self:SetStatus("Restored")
	end
	return registerFeature(feature, category, description)
end

local NoFog = simplePropertyFeature("No Fog", "World", "Extends local fog distance while leaving server lighting untouched",
	function() return Lighting end, "FogEnd", 100000)
local TimeChanger = simplePropertyFeature("Time Changer", "World", "Locks the local clock to a selected hour",
	function() return Lighting end, "ClockTime", 14)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Clock time", 0, 24, feature.Settings.Value, function(value) feature:SetSetting("Value", value) end, { Step = 1 })
end
local Brightness = simplePropertyFeature("Brightness", "World", "Maintains a local Lighting brightness value",
	function() return Lighting end, "Brightness", 3)
entries[#entries].Configure = function(module, feature)
	module:AddSlider("Brightness", 0, 10, feature.Settings.Value, function(value) feature:SetSetting("Value", value) end, { Step = 0.5 })
end
local RemoveShadows = simplePropertyFeature("Remove Shadows", "World", "Disables global shadows locally",
	function() return Lighting end, "GlobalShadows", false)

local Ambient = API.CreateFeature("Ambient", { Color = Color3.fromRGB(150, 175, 205), ToggleKey = Enum.KeyCode.Unknown })
function Ambient:OnEnable()
	self._old = { Lighting.Ambient, Lighting.OutdoorAmbient }
	self:Track(Updates:Register("Universal:Ambient", "Slow", function()
		Lighting.Ambient, Lighting.OutdoorAmbient = self.Settings.Color, self.Settings.Color
	end)); self:SetStatus("Ambient color active"); return true
end
function Ambient:OnDisable() if self._old then Lighting.Ambient, Lighting.OutdoorAmbient = self._old[1], self._old[2] end; self:SetStatus("Ambient restored") end
registerFeature(Ambient, "World", "Applies one local ambient color indoors and outdoors", function(module, feature)
	module:AddColorPicker("Ambient color", feature.Settings.Color, function(value) feature:SetSetting("Color", value) end)
end)

local SkyboxPreset = API.CreateFeature("Skybox Preset", { ToggleKey = Enum.KeyCode.Unknown })
function SkyboxPreset:OnEnable()
	self._old = {}
	for _, object in ipairs(Lighting:GetChildren()) do if object:IsA("Sky") then table.insert(self._old, object); object.Parent = nil end end
	local sky = Instance.new("Sky"); sky.Name = "FrostScriptsSky"
	sky.SkyboxBk = "rbxassetid://159454299"; sky.SkyboxDn = "rbxassetid://159454296"; sky.SkyboxFt = "rbxassetid://159454293"
	sky.SkyboxLf = "rbxassetid://159454286"; sky.SkyboxRt = "rbxassetid://159454300"; sky.SkyboxUp = "rbxassetid://159454288"
	sky.Parent = Lighting; self._sky = sky; self:SetStatus("Frost sky active"); return true
end
function SkyboxPreset:OnDisable()
	if self._sky then self._sky:Destroy(); self._sky = nil end
	for _, sky in ipairs(self._old or {}) do sky.Parent = Lighting end; self._old = nil; self:SetStatus("Sky restored")
end
registerFeature(SkyboxPreset, "World", "Swaps local Sky instances for a reversible Frost preset")

local function effectsByClass(className)
	local result = {}
	for _, object in ipairs(Lighting:GetChildren()) do if object:IsA(className) then table.insert(result, object) end end
	return result
end
local AtmosphereToggle = simplePropertyFeature("Atmosphere Toggle", "World", "Disables Atmosphere instances without deleting them",
	function() return effectsByClass("Atmosphere") end, "Density", 0)
local NoBlur = simplePropertyFeature("No Blur", "World", "Disables local BlurEffect instances",
	function() return effectsByClass("BlurEffect") end, "Enabled", false)
local NoBloom = simplePropertyFeature("No Bloom", "World", "Disables local BloomEffect instances",
	function() return effectsByClass("BloomEffect") end, "Enabled", false)
local NoSunRays = simplePropertyFeature("No Sun Rays", "World", "Disables local SunRaysEffect instances",
	function() return effectsByClass("SunRaysEffect") end, "Enabled", false)
local NoDepthOfField = simplePropertyFeature("No Depth of Field", "World", "Disables local DepthOfFieldEffect instances",
	function() return effectsByClass("DepthOfFieldEffect") end, "Enabled", false)

local function colorCorrectionFeature(name, property, default, minimum, maximum, step, description)
	local feature = API.CreateFeature(name, { Value = default, ToggleKey = Enum.KeyCode.Unknown })
	function feature:OnEnable()
		local effect = Instance.new("ColorCorrectionEffect"); effect.Name = "FrostScripts" .. name:gsub("%s", "")
		effect[property] = self.Settings.Value; effect.Parent = Lighting; self._effect = effect; self:SetStatus("Active"); return true
	end
	function feature:OnSettingChanged() if self._effect then self._effect[property] = self.Settings.Value end end
	function feature:OnDisable() if self._effect then self._effect:Destroy(); self._effect = nil end; self:SetStatus("Removed") end
	registerFeature(feature, "World", description, function(module, item)
		module:AddSlider(name, minimum, maximum, item.Settings.Value, function(value) item:SetSetting("Value", value) end, { Step = step })
	end); return feature
end
local Saturation = colorCorrectionFeature("Saturation", "Saturation", 0.35, -1, 1, 0.05, "Adds a dedicated local saturation correction")
local Contrast = colorCorrectionFeature("Contrast", "Contrast", 0.2, -1, 1, 0.05, "Adds a dedicated local contrast correction")
local ScreenTint = colorCorrectionFeature("Screen Tint", "TintColor", Color3.fromRGB(205, 235, 255), 0, 1, 0.05, "Adds a cold Frost tint to the local camera")
entries[#entries].Configure = nil

local DisableParticles = API.CreateFeature("Disable Particles", { ToggleKey = Enum.KeyCode.Unknown })
function DisableParticles:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	local function apply(object)
		if object:IsA("ParticleEmitter") and object.Enabled then self._old[object] = true; object.Enabled = false end
	end
	for _, object in ipairs(workspace:GetDescendants()) do apply(object) end
	self:Track(workspace.DescendantAdded:Connect(apply)); self:SetStatus("Particles disabled"); return true
end
function DisableParticles:OnDisable() for object, old in pairs(self._old or {}) do if object.Parent then object.Enabled = old end end; self:SetStatus("Particles restored") end
registerFeature(DisableParticles, "Performance", "Disables only ParticleEmitter objects and watches newly added effects")

local RemoveTextures = API.CreateFeature("Texture Reduction", { Transparency = 1, ToggleKey = Enum.KeyCode.Unknown })
function RemoveTextures:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	local function apply(object)
		if object:IsA("Decal") or object:IsA("Texture") then
			if self._old[object] == nil then self._old[object] = object.Transparency end; object.Transparency = self.Settings.Transparency
		end
	end
	for _, object in ipairs(workspace:GetDescendants()) do apply(object) end
	self:Track(workspace.DescendantAdded:Connect(apply)); self:SetStatus("Textures reduced"); return true
end
function RemoveTextures:OnDisable() for object, old in pairs(self._old or {}) do if object.Parent then object.Transparency = old end end; self:SetStatus("Textures restored") end
registerFeature(RemoveTextures, "Performance", "Raises local Decal and Texture transparency and restores it", function(module, feature)
	module:AddSlider("Texture transparency", 0, 1, feature.Settings.Transparency, function(value) feature:SetSetting("Transparency", value) end, { Step = 0.1 })
end)

local LowGraphics = API.CreateFeature("Low Graphics", { ToggleKey = Enum.KeyCode.Unknown })
function LowGraphics:OnEnable()
	self._parts, self._effects = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
	local function apply(object)
		if object:IsA("BasePart") then
			if not self._parts[object] then self._parts[object] = { object.Material, object.Reflectance, object.CastShadow } end
			object.Material, object.Reflectance, object.CastShadow = Enum.Material.Plastic, 0, false
		elseif (EFFECT_CLASSES[object.ClassName] or object:IsA("PostEffect")) and object.Enabled then self._effects[object] = true; object.Enabled = false end
	end
	for _, object in ipairs(workspace:GetDescendants()) do apply(object) end
	self:Track(workspace.DescendantAdded:Connect(apply)); self:SetStatus("Low graphics preset active"); return true
end
function LowGraphics:OnDisable()
	for object, old in pairs(self._parts or {}) do if object.Parent then object.Material, object.Reflectance, object.CastShadow = old[1], old[2], old[3] end end
	for object, old in pairs(self._effects or {}) do if object.Parent then object.Enabled = old end end
	self:SetStatus("Graphics restored")
end
registerFeature(LowGraphics, "Performance", "Combines plastic materials, shadow reduction, and effect cleanup with restoration")

local ZoomUnlock = API.CreateFeature("Zoom Unlock", { Maximum = 1000, ToggleKey = Enum.KeyCode.Unknown })
function ZoomUnlock:OnEnable()
	self._old = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, self.Settings.Maximum; self:SetStatus("Zoom range unlocked"); return true
end
function ZoomUnlock:OnSettingChanged() if self.Enabled then player.CameraMaxZoomDistance = self.Settings.Maximum end end
function ZoomUnlock:OnDisable() if self._old then player.CameraMinZoomDistance, player.CameraMaxZoomDistance = self._old[1], self._old[2] end; self:SetStatus("Zoom restored") end
registerFeature(ZoomUnlock, "Camera", "Widens the local camera zoom range", function(module, feature)
	module:AddSlider("Maximum zoom", 50, 5000, feature.Settings.Maximum, function(value) feature:SetSetting("Maximum", value) end, { Step = 50 })
end)

local function cameraModeFeature(name, mode, description)
	local feature = API.CreateFeature(name, { ToggleKey = Enum.KeyCode.Unknown })
	function feature:OnEnable()
		self._old = player.CameraMode; player.CameraMode = mode
		self:Track(Updates:Register("Universal:" .. name, "Slow", function() player.CameraMode = mode end)); self:SetStatus("Active"); return true
	end
	function feature:OnDisable() player.CameraMode = self._old; self:SetStatus("Restored") end
	return registerFeature(feature, "Camera", description)
end
local FirstPerson = cameraModeFeature("First Person", Enum.CameraMode.LockFirstPerson, "Locks the local player camera to first person")
local ThirdPerson = cameraModeFeature("Third Person", Enum.CameraMode.Classic, "Keeps the camera in classic third person")

local ShoulderCam = API.CreateFeature("Shoulder Cam", { Offset = 2.5, ToggleKey = Enum.KeyCode.Unknown })
function ShoulderCam:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:ShoulderCam", "Render", function()
		local _, humanoid = getCharacter(); if humanoid then
			if self._old[humanoid] == nil then self._old[humanoid] = humanoid.CameraOffset end
			humanoid.CameraOffset = Vector3.new(self.Settings.Offset, 0, 0)
		end
	end)); self:SetStatus("Shoulder offset active"); return true
end
function ShoulderCam:OnDisable() for humanoid, old in pairs(self._old or {}) do if humanoid.Parent then humanoid.CameraOffset = old end end; self:SetStatus("Offset restored") end
registerFeature(ShoulderCam, "Camera", "Adds a configurable horizontal shoulder offset", function(module, feature)
	module:AddSlider("Horizontal offset", -6, 6, feature.Settings.Offset, function(value) feature:SetSetting("Offset", value) end, { Step = 0.25 })
end)

local CameraOffset = API.CreateFeature("Camera Offset", { X = 0, Y = 3, Z = 0, ToggleKey = Enum.KeyCode.Unknown })
function CameraOffset:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:CameraOffset", "Render", function()
		local _, humanoid = getCharacter(); if humanoid then
			if self._old[humanoid] == nil then self._old[humanoid] = humanoid.CameraOffset end
			humanoid.CameraOffset = Vector3.new(self.Settings.X, self.Settings.Y, self.Settings.Z)
		end
	end)); self:SetStatus("Camera offset active"); return true
end
function CameraOffset:OnDisable() for humanoid, old in pairs(self._old or {}) do if humanoid.Parent then humanoid.CameraOffset = old end end; self:SetStatus("Offset restored") end
registerFeature(CameraOffset, "Camera", "Applies a three-axis humanoid camera offset", function(module, feature)
	for _, axis in ipairs({ "X", "Y", "Z" }) do module:AddSlider(axis .. " offset", -10, 10, feature.Settings[axis], function(value) feature:SetSetting(axis, value) end, { Step = 0.5 }) end
end)

local CameraLock = API.CreateFeature("Camera Lock", { ToggleKey = Enum.KeyCode.Unknown })
function CameraLock:OnEnable()
	self._old = UserInputService.MouseBehavior; UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	self:Track(Updates:Register("Universal:CameraLock", "Render", function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end)); self:SetStatus("Pointer locked to center"); return true
end
function CameraLock:OnDisable() UserInputService.MouseBehavior = self._old; self:SetStatus("Pointer released") end
registerFeature(CameraLock, "Camera", "Keeps desktop pointer input locked to the center")

local CameraSmoothing = API.CreateFeature("Camera Smoothing", { Response = 14, ToggleKey = Enum.KeyCode.Unknown })
function CameraSmoothing:OnEnable()
	self._last = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or nil
	self:Track(Updates:Register("Universal:CameraSmoothing", "Render", function(dt)
		local camera = workspace.CurrentCamera; if not camera then return end
		local target = camera.CFrame; self._last = self._last and self._last:Lerp(target, 1 - math.exp(-self.Settings.Response * dt)) or target
		camera.CFrame = self._last
	end)); self:SetStatus("Camera motion softened"); return true
end
function CameraSmoothing:OnDisable() self._last = nil; self:SetStatus("Smoothing disabled") end
registerFeature(CameraSmoothing, "Camera", "Softens abrupt local camera CFrame changes through exponential interpolation", function(module, feature)
	module:AddSlider("Response", 2, 30, feature.Settings.Response, function(value) feature:SetSetting("Response", value) end, { Step = 1 })
end)

local ShakeRemover = API.CreateFeature("Shake Remover", { ToggleKey = Enum.KeyCode.Unknown })
function ShakeRemover:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:ShakeRemover", "Render", function()
		local _, humanoid = getCharacter(); if humanoid then
			if self._old[humanoid] == nil then self._old[humanoid] = humanoid.CameraOffset end; humanoid.CameraOffset = Vector3.zero
		end
	end)); self:SetStatus("Humanoid camera offset locked"); return true
end
function ShakeRemover:OnDisable() for humanoid, old in pairs(self._old or {}) do if humanoid.Parent then humanoid.CameraOffset = old end end; self:SetStatus("Camera offset restored") end
registerFeature(ShakeRemover, "Camera", "Suppresses shake implemented through Humanoid.CameraOffset and restores the prior offset")

local Spectate = API.CreateFeature("Spectate Player", { ToggleKey = Enum.KeyCode.Unknown })
function Spectate:OnEnable()
	local target = findPlayer(); local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera; if not target or not humanoid or not camera then self:SetStatus("Select an online player"); return false end
	self._camera, self._old = camera, camera.CameraSubject; camera.CameraSubject = humanoid
	self:Track(Updates:Register("Universal:Spectate", "Stats", function()
		local currentTarget = findPlayer(); local currentHumanoid = currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChildOfClass("Humanoid")
		local currentCamera = workspace.CurrentCamera
		if currentCamera and currentHumanoid then currentCamera.CameraSubject = currentHumanoid; self:SetStatus("Watching " .. currentTarget.Name) end
	end)); self:SetStatus("Watching " .. target.Name); return true
end
function Spectate:OnDisable() if self._camera and self._camera.Parent then local _, humanoid = getCharacter(); self._camera.CameraSubject = humanoid or self._old end; self:SetStatus("Spectate stopped") end
registerFeature(Spectate, "Players", "Moves only the local camera subject to the selected player's humanoid")

local HideNameplate = API.CreateFeature("Hide Nameplate", { ToggleKey = Enum.KeyCode.Unknown })
function HideNameplate:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:HideNameplate", "Slow", function()
		local _, humanoid = getCharacter(); if humanoid then
			if self._old[humanoid] == nil then self._old[humanoid] = humanoid.DisplayDistanceType end
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end)); self:SetStatus("Nameplate hidden"); return true
end
function HideNameplate:OnDisable() for humanoid, old in pairs(self._old or {}) do if humanoid.Parent then humanoid.DisplayDistanceType = old end end; self:SetStatus("Nameplate restored") end
registerFeature(HideNameplate, "Character", "Hides the local humanoid nameplate")

local DisableAnimate = API.CreateFeature("Disable Animate", { ToggleKey = Enum.KeyCode.Unknown })
function DisableAnimate:OnEnable()
	self._scripts = setmetatable({}, { __mode = "k" })
	self:Track(Updates:Register("Universal:DisableAnimate", "Slow", function()
		local character = Character.Character; local animate = character and character:FindFirstChild("Animate")
		if animate and (animate:IsA("LocalScript") or animate:IsA("Script")) then
			if self._scripts[animate] == nil then self._scripts[animate] = animate.Disabled end; animate.Disabled = true
		end
	end)); self:SetStatus("Default animator disabled"); return true
end
function DisableAnimate:OnDisable() for scriptObject, old in pairs(self._scripts or {}) do if scriptObject.Parent then scriptObject.Disabled = old end end; self:SetStatus("Animator restored") end
registerFeature(DisableAnimate, "Character", "Temporarily disables the character Animate script and restores it")

local ForceFieldVisual = API.CreateFeature("Force Field Visual", { ToggleKey = Enum.KeyCode.Unknown })
function ForceFieldVisual:_attach(character)
	if self._field then self._field:Destroy() end; if not character then return end
	local field = Instance.new("ForceField"); field.Name = "FrostScriptsForceField"; field.Visible = true; field.Parent = character; self._field = field
end
function ForceFieldVisual:OnEnable()
	self:Track(Character:OnAdded(function(character) if self.Enabled then self:_attach(character) end end, false)); self:_attach(Character.Character); self:SetStatus("Local force-field visual active"); return true
end
function ForceFieldVisual:OnDisable() if self._field then self._field:Destroy(); self._field = nil end; self:SetStatus("Visual removed") end
registerFeature(ForceFieldVisual, "Character", "Adds a local ForceField visual without claiming server-side protection")

local RainbowCharacter = API.CreateFeature("Rainbow Character", { Speed = 0.15, ToggleKey = Enum.KeyCode.Unknown })
function RainbowCharacter:OnEnable()
	self._old = setmetatable({}, { __mode = "k" }); self._hue = 0
	self:Track(Updates:Register("Universal:RainbowCharacter", "Slow", function(_, dt)
		self._hue = (self._hue + self.Settings.Speed * dt) % 1; local character = Character.Character; if not character then return end
		for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then
			if self._old[part] == nil then self._old[part] = part.Color end; part.Color = Color3.fromHSV(self._hue, 0.8, 1)
		end end
	end)); self:SetStatus("Rainbow cycle active"); return true
end
function RainbowCharacter:OnDisable() for part, old in pairs(self._old or {}) do if part.Parent then part.Color = old end end; self:SetStatus("Colors restored") end
registerFeature(RainbowCharacter, "Fun", "Cycles local character part colors with one low-frequency task", function(module, feature)
	module:AddSlider("Cycle speed", 0.05, 1, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 0.05 })
end)

local HighlightSelected = API.CreateFeature("Highlight Selected Player", { ToggleKey = Enum.KeyCode.Unknown })
function HighlightSelected:OnEnable()
	local target = findPlayer(); if not target or not target.Character then self:SetStatus("Select an online player"); return false end
	self:Track(Updates:Register("Universal:HighlightSelected", "Stats", function()
		local current = findPlayer(); local character = current and current.Character
		if not character then return end
		if not self._highlight or self._highlight.Parent ~= character then
			if self._highlight then self._highlight:Destroy() end
			local highlight = Instance.new("Highlight"); highlight.Name = "FrostScriptsSelectedHighlight"; highlight.FillColor = Color3.fromRGB(120, 210, 255)
			highlight.OutlineColor = Color3.fromRGB(235, 250, 255); highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent = character
			self._highlight = highlight
		end
		self:SetStatus("Highlighting " .. current.Name)
	end)); self:SetStatus("Highlighting " .. target.Name); return true
end
function HighlightSelected:OnDisable() if self._highlight then self._highlight:Destroy(); self._highlight = nil end; self:SetStatus("Highlight removed") end
registerFeature(HighlightSelected, "Players", "Highlights the selected player's current character locally")

local PlayerESP = API.CreateFeature("Player ESP", { ToggleKey = Enum.KeyCode.Unknown })
function PlayerESP:OnEnable()
	self._highlights = {}
	local function add(target)
		if target == player or not target.Character or self._highlights[target] then return end
		local highlight = Instance.new("Highlight"); highlight.Name = "FrostScriptsPlayerESP"; highlight.FillTransparency = 0.75
		highlight.OutlineColor = target.TeamColor and target.TeamColor.Color or Color3.fromRGB(135, 215, 255)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent = target.Character; self._highlights[target] = highlight
	end
	for _, target in ipairs(Players:GetPlayers()) do add(target) end
	self:Track(Players.PlayerAdded:Connect(function(target) self:Track(target.CharacterAdded:Connect(function() task.defer(add, target) end)) end))
	for _, target in ipairs(Players:GetPlayers()) do if target ~= player then self:Track(target.CharacterAdded:Connect(function() task.defer(add, target) end)) end end
	self:SetStatus("Player outlines active"); return true
end
function PlayerESP:OnDisable() for _, highlight in pairs(self._highlights or {}) do highlight:Destroy() end; self._highlights = {}; self:SetStatus("ESP removed") end
registerFeature(PlayerESP, "Players", "Adds local Highlight outlines and refreshes them after player respawns")

local JoinNotifications = API.CreateFeature("Join Notifications", { ToggleKey = Enum.KeyCode.Unknown })
function JoinNotifications:OnEnable()
	self:Track(Players.PlayerAdded:Connect(function(target) notify("Player joined", target.DisplayName .. " (@" .. target.Name .. ")", "Info") end))
	self:SetStatus("Watching joins"); return true
end
function JoinNotifications:OnDisable() self:SetStatus("Join notices disabled") end
registerFeature(JoinNotifications, "Players", "Shows a FrostScripts toast when another player joins")

local LeaveNotifications = API.CreateFeature("Leave Notifications", { ToggleKey = Enum.KeyCode.Unknown })
function LeaveNotifications:OnEnable()
	self:Track(Players.PlayerRemoving:Connect(function(target) notify("Player left", target.DisplayName .. " (@" .. target.Name .. ")", "Info") end))
	self:SetStatus("Watching leaves"); return true
end
function LeaveNotifications:OnDisable() self:SetStatus("Leave notices disabled") end
registerFeature(LeaveNotifications, "Players", "Shows a FrostScripts toast when another player leaves")

local MobileMode = API.CreateFeature("Mobile Mode", { ToggleKey = Enum.KeyCode.Unknown })
function MobileMode:OnEnable()
	if not MobileControls then self:SetStatus("Controls are still loading"); return false end
	MobileControls:SetVisible(true); self:SetStatus("On-screen controls visible"); return true
end
function MobileMode:OnDisable() if MobileControls then MobileControls:SetVisible(false) end; self:SetStatus("On-screen controls hidden") end
registerFeature(MobileMode, "Utility", "Shows large touch controls for movement, vertical flight, and the eight quick toggles")

local ControllerSupport = API.CreateFeature("Controller Support", { ToggleKey = Enum.KeyCode.Unknown })
function ControllerSupport:OnEnable()
	self:Track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.ButtonX then Flight:SetEnabled(not Flight.Enabled)
		elseif input.KeyCode == Enum.KeyCode.ButtonY then Noclip:SetEnabled(not Noclip.Enabled)
		elseif input.KeyCode == Enum.KeyCode.ButtonB then Freecam:SetEnabled(not Freecam.Enabled)
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then Speed:SetEnabled(not Speed.Enabled) end
	end)); self:SetStatus("X Flight  •  Y Noclip  •  B Freecam  •  L3 Speed"); return true
end
function ControllerSupport:OnDisable() self:SetStatus("Controller shortcuts disabled") end
registerFeature(ControllerSupport, "Utility", "Adds explicit gamepad shortcuts without replacing Roblox movement controls")

local AutoRejoin = API.CreateFeature("Auto Rejoin", { ToggleKey = Enum.KeyCode.Unknown })
function AutoRejoin:OnEnable()
	self:Track(GuiService.ErrorMessageChanged:Connect(function(message)
		if self.Enabled and tostring(message) ~= "" then task.delay(2, function() if self.Enabled then pcall(rejoin) end end) end
	end)); self:SetStatus("Watching disconnect messages"); return true
end
function AutoRejoin:OnDisable() self:SetStatus("Auto rejoin disabled") end
registerFeature(AutoRejoin, "Server", "Retries the current place after Roblox reports a client error")

local FPSCap = API.CreateFeature("FPS Cap", { Cap = 144, ToggleKey = Enum.KeyCode.Unknown })
function FPSCap:OnEnable()
	if type(env.setfpscap) ~= "function" then self:SetStatus("setfpscap unavailable"); return false end
	self._oldCap = 60; if type(env.getfpscap) == "function" then pcall(function() self._oldCap = env.getfpscap() end) end
	env.setfpscap(self.Settings.Cap); self:SetStatus("Cap set to " .. tostring(self.Settings.Cap)); return true
end
function FPSCap:OnSettingChanged() if self.Enabled and type(env.setfpscap) == "function" then env.setfpscap(self.Settings.Cap) end end
function FPSCap:OnDisable() if type(env.setfpscap) == "function" then env.setfpscap(self._oldCap or 60) end; self:SetStatus("Previous cap restored") end
registerFeature(FPSCap, "Performance", "Uses setfpscap when the execution environment exposes it", function(module, feature)
	module:AddSlider("FPS cap", 30, 360, feature.Settings.Cap, function(value) feature:SetSetting("Cap", value) end, { Step = 15 })
end, "Executor dependent")

local HideEffects = API.CreateFeature("Hide Effects", { ToggleKey = Enum.KeyCode.Unknown })
function HideEffects:OnEnable()
	self._old = setmetatable({}, { __mode = "k" })
	local function apply(object)
		if (object:IsA("Beam") or object:IsA("Trail") or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles")) and object.Enabled then
			self._old[object] = true; object.Enabled = false
		end
	end
	for _, object in ipairs(workspace:GetDescendants()) do apply(object) end
	self:Track(workspace.DescendantAdded:Connect(apply)); self:SetStatus("World effects hidden"); return true
end
function HideEffects:OnDisable() for object, old in pairs(self._old or {}) do if object.Parent then object.Enabled = old end end; self:SetStatus("Effects restored") end
registerFeature(HideEffects, "Performance", "Disables beams, trails, smoke, fire, and sparkles while leaving particles alone")

local FrozenSteps = API.CreateFeature("Frozen Steps", { Interval = 0.25, Lifetime = 4, ToggleKey = Enum.KeyCode.Unknown })
function FrozenSteps:OnEnable()
	self:Track(Updates:Register("Universal:FrozenSteps", "Slow", function()
		local _, _, root = getCharacter(); if not root or root.AssemblyLinearVelocity.Magnitude < 2 then return end
		local step = Instance.new("Part"); step.Name = "FrostScriptsFrozenStep"; step.Anchored = true; step.CanCollide = false
		step.Material = Enum.Material.Neon; step.Color = Color3.fromRGB(160, 225, 255); step.Transparency = 0.35
		step.Size = Vector3.new(2.4, 0.08, 1.4); step.CFrame = root.CFrame * CFrame.new(0, -3, 0); step.Parent = workspace
		Debris:AddItem(step, self.Settings.Lifetime)
	end)); self:SetStatus("Leaving temporary frozen steps"); return true
end
function FrozenSteps:OnDisable() self:SetStatus("Frozen steps stopped") end
registerFeature(FrozenSteps, "Fun", "Leaves short-lived non-colliding neon footprints through Debris cleanup", function(module, feature)
	module:AddSlider("Step lifetime", 1, 10, feature.Settings.Lifetime, function(value) feature:SetSetting("Lifetime", value) end, { Step = 1 })
end)

local OrbitingSnowflakes = API.CreateFeature("Orbiting Snowflakes", { Radius = 4, Speed = 1.4, ToggleKey = Enum.KeyCode.Unknown })
function OrbitingSnowflakes:OnEnable()
	self._parts = {}; self._angle = 0
	for index = 1, 6 do
		local part = Instance.new("Part"); part.Name = "FrostScriptsSnowflake"; part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(0.35, 0.35, 0.35); part.Anchored = true; part.CanCollide = false
		part.Material = Enum.Material.Neon; part.Color = Color3.fromRGB(220, 250, 255); part.Parent = workspace; table.insert(self._parts, part)
	end
	self:Track(Updates:Register("Universal:OrbitingSnowflakes", "Render", function(dt)
		local _, _, root = getCharacter(); if not root then return end; self._angle += dt * self.Settings.Speed
		for index, part in ipairs(self._parts) do
			local angle = self._angle + (index - 1) * math.pi * 2 / #self._parts
			part.Position = root.Position + Vector3.new(math.cos(angle) * self.Settings.Radius, 1 + math.sin(angle * 2), math.sin(angle) * self.Settings.Radius)
		end
	end)); self:SetStatus("Snowflakes orbiting"); return true
end
function OrbitingSnowflakes:OnDisable() for _, part in ipairs(self._parts or {}) do part:Destroy() end; self._parts = {}; self:SetStatus("Snowflakes removed") end
registerFeature(OrbitingSnowflakes, "Fun", "Animates six lightweight local snow orbs through the shared render task", function(module, feature)
	module:AddSlider("Orbit radius", 2, 10, feature.Settings.Radius, function(value) feature:SetSetting("Radius", value) end, { Step = 0.5 })
	module:AddSlider("Orbit speed", 0.2, 5, feature.Settings.Speed, function(value) feature:SetSetting("Speed", value) end, { Step = 0.2 })
end)

local MoonGravity = API.CreateFeature("Moon Gravity", { ToggleKey = Enum.KeyCode.Unknown })
function MoonGravity:OnEnable() self._old = workspace.Gravity; workspace.Gravity = 32.4; self:SetStatus("Moon gravity active"); return true end
function MoonGravity:OnDisable() if self._old then workspace.Gravity = self._old end; self:SetStatus("Gravity restored") end
registerFeature(MoonGravity, "Fun", "Applies a 32.4-stud moon-gravity preset locally")

local Blizzard = API.CreateFeature("Blizzard", { ToggleKey = Enum.KeyCode.Unknown })
function Blizzard:OnEnable()
	local camera = workspace.CurrentCamera; if not camera then return false end
	local attachment = Instance.new("Attachment"); attachment.Name = "FrostScriptsBlizzard"; attachment.Parent = camera
	local emitter = Instance.new("ParticleEmitter"); emitter.Texture = "rbxassetid://241594419"; emitter.Rate = 90
	emitter.Lifetime = NumberRange.new(1, 2); emitter.Speed = NumberRange.new(18, 28); emitter.Acceleration = Vector3.new(-12, -8, 0)
	emitter.SpreadAngle = Vector2.new(45, 45); emitter.Parent = attachment; self._attachment = attachment; self:SetStatus("Local blizzard active"); return true
end
function Blizzard:OnDisable() if self._attachment then self._attachment:Destroy(); self._attachment = nil end; self:SetStatus("Blizzard cleared") end
registerFeature(Blizzard, "Fun", "Attaches a local snow emitter to the current camera")

local Snowfall = API.CreateFeature("Snowfall", { ToggleKey = Enum.KeyCode.Unknown })
function Snowfall:_attach(_, _, root)
	if self._attachment then self._attachment:Destroy() end; if not root then return end
	local attachment = Instance.new("Attachment"); attachment.Position = Vector3.new(0, 12, 0); attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter"); emitter.Texture = "rbxassetid://241594419"; emitter.Rate = 35
	emitter.Lifetime = NumberRange.new(2.5, 4); emitter.Speed = NumberRange.new(2, 5); emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.SpreadAngle = Vector2.new(35, 35); emitter.Parent = attachment; self._attachment = attachment
end
function Snowfall:OnEnable()
	self:Track(Character:OnAdded(function(...) if self.Enabled then self:_attach(...) end end, false)); self:_attach(Character:Get())
	self:SetStatus("Snowfall active"); return true
end
function Snowfall:OnDisable() if self._attachment then self._attachment:Destroy(); self._attachment = nil end; self:SetStatus("Snowfall stopped") end
registerFeature(Snowfall, "Fun", "Creates a lightweight local snowfall emitter above the character")

local IceAura = API.CreateFeature("Ice Aura", { ToggleKey = Enum.KeyCode.Unknown })
function IceAura:_attach(character)
	if self._highlight then self._highlight:Destroy() end; if not character then return end
	local highlight = Instance.new("Highlight"); highlight.Name = "FrostScriptsIceAura"; highlight.FillColor = Color3.fromRGB(140, 225, 255)
	highlight.FillTransparency = 0.65; highlight.OutlineColor = Color3.fromRGB(235, 255, 255); highlight.Parent = character; self._highlight = highlight
end
function IceAura:OnEnable()
	self:Track(Character:OnAdded(function(character) if self.Enabled then self:_attach(character) end end, false)); self:_attach(Character.Character)
	self:SetStatus("Ice aura active"); return true
end
function IceAura:OnDisable() if self._highlight then self._highlight:Destroy(); self._highlight = nil end; self:SetStatus("Ice aura removed") end
registerFeature(IceAura, "Fun", "Applies a local icy Highlight effect to the character")

local FrostWings = API.CreateFeature("Frost Wings", { ToggleKey = Enum.KeyCode.Unknown })
function FrostWings:_attach(character)
	if self._folder then self._folder:Destroy() end
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")); if not torso then return end
	local folder = Instance.new("Folder"); folder.Name = "FrostScriptsWings"; folder.Parent = character
	for _, side in ipairs({ -1, 1 }) do
		for segment = 1, 3 do
			local wing = Instance.new("WedgePart"); wing.Name = "FrostWing"; wing.Size = Vector3.new(0.2, 2.8 - segment * 0.35, 1.8)
			wing.Material = Enum.Material.Neon; wing.Color = Color3.fromRGB(180, 235, 255); wing.Transparency = 0.18
			wing.CanCollide = false; wing.Massless = true
			wing.CFrame = torso.CFrame * CFrame.new(side * (1 + segment * 0.45), 0.4 - segment * 0.35, 0.55)
				* CFrame.Angles(0, math.rad(side * (18 + segment * 10)), math.rad(side * (18 + segment * 8)))
			wing.Parent = folder
			local weld = Instance.new("WeldConstraint"); weld.Part0, weld.Part1, weld.Parent = torso, wing, wing
		end
	end
	self._folder = folder
end
function FrostWings:OnEnable()
	self:Track(Character:OnAdded(function(character) if self.Enabled then self:_attach(character) end end, false)); self:_attach(Character.Character)
	self:SetStatus("Local wings attached"); return true
end
function FrostWings:OnDisable() if self._folder then self._folder:Destroy(); self._folder = nil end; self:SetStatus("Wings removed") end
registerFeature(FrostWings, "Fun", "Builds lightweight neon wings and reattaches them after respawn")

local SpawnMarker = API.CreateFeature("Spawn Marker", { ToggleKey = Enum.KeyCode.Unknown })
function SpawnMarker:OnEnable()
	local _, _, root = getCharacter(); if not root then return false end
	self._position = root.Position
	local marker = Instance.new("Part"); marker.Name = "FrostScriptsSpawnMarker"; marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.18, 5, 5); marker.Anchored = true; marker.CanCollide = false; marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(100, 210, 255); marker.Transparency = 0.45
	marker.CFrame = CFrame.new(self._position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)); marker.Parent = workspace
	self._marker = marker; self:SetStatus("Spawn marker placed"); return true
end
function SpawnMarker:OnDisable() if self._marker then self._marker:Destroy(); self._marker = nil end; self:SetStatus("Marker removed") end
registerFeature(SpawnMarker, "Navigation", "Places a reversible local neon marker at the current spawn position")

local function readPing()
	local result
	pcall(function()
		local network = Stats:FindFirstChild("Network")
		local server = network and network:FindFirstChild("ServerStatsItem")
		local ping = server and server:FindFirstChild("Data Ping")
		result = ping and ping:GetValue()
	end)
	return math.max(0, math.floor(tonumber(result) or 0))
end

local startedAt = os.clock()
local frameCount, frameElapsed, currentFPS = 0, 0, 0
scope:Track(Updates:Register("Universal:FPSCounter", "Render", function(dt) frameCount += 1; frameElapsed += dt end))

local function activeCount()
	local count = 0; for _, feature in ipairs(features) do if feature.Enabled then count += 1 end end; return count
end

local function hudFeature(name, description, key, bucket, render)
	local feature = API.CreateFeature(name, { ToggleKey = Enum.KeyCode.Unknown })
	function feature:OnEnable()
		self:Track(Updates:Register("Universal:HUD:" .. key, bucket or "Stats", function()
			if Interface then Interface:SetMonitor("Universal:" .. key, render()) end
		end)); self:SetStatus("Overlay visible"); return true
	end
	function feature:OnDisable() if Interface then Interface:HideMonitor("Universal:" .. key) end; self:SetStatus("Overlay hidden") end
	return registerFeature(feature, "HUD", description)
end

local FPSHUD = hudFeature("FPS HUD", "Shows the measured client frame rate", "FPS", "Stats", function() return "FPS\n" .. tostring(currentFPS) end)
local PingHUD = hudFeature("Ping HUD", "Shows Roblox Data Ping when available", "Ping", "Stats", function() return "PING\n" .. tostring(readPing()) .. " ms" end)
local CoordinatesHUD = hudFeature("Coordinates HUD", "Shows rounded local character coordinates", "Coordinates", "Slow", function()
	local _, _, root = getCharacter(); return root and string.format("COORDINATES\nX %d  Y %d  Z %d", root.Position.X, root.Position.Y, root.Position.Z) or "COORDINATES\nWaiting"
end)
local SpeedHUD = hudFeature("Speed HUD", "Shows horizontal assembly speed", "Speed", "Slow", function()
	local _, _, root = getCharacter(); if not root then return "SPEED\nWaiting" end
	local value = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude; return string.format("SPEED\n%.1f studs/s", value)
end)
local VelocityHUD = hudFeature("Velocity HUD", "Shows the complete local assembly velocity", "Velocity", "Slow", function()
	local _, _, root = getCharacter(); if not root then return "VELOCITY\nWaiting" end; local v = root.AssemblyLinearVelocity
	return string.format("VELOCITY\n%.0f, %.0f, %.0f", v.X, v.Y, v.Z)
end)
local HealthHUD = hudFeature("Health HUD", "Shows local humanoid health and maximum health", "Health", "Slow", function()
	local _, humanoid = getCharacter(); return humanoid and string.format("HEALTH\n%.0f / %.0f", humanoid.Health, humanoid.MaxHealth) or "HEALTH\nWaiting"
end)
local SelectedHealthHUD = hudFeature("Selected Player Health HUD", "Shows the selected player's humanoid health", "SelectedHealth", "Slow", function()
	local target = findPlayer(); local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	return humanoid and string.format("TARGET HEALTH\n%s  •  %.0f / %.0f", target.Name, humanoid.Health, humanoid.MaxHealth) or "TARGET HEALTH\nSelect a player"
end)
local PlayerCountHUD = hudFeature("Player Count HUD", "Shows current and maximum server population", "Players", "Stats", function()
	return string.format("PLAYERS\n%d / %d", #Players:GetPlayers(), Players.MaxPlayers)
end)
local SessionTimeHUD = hudFeature("Session Time HUD", "Shows elapsed time since Universal loaded", "Session", "Stats", function()
	local elapsed = math.floor(os.clock() - startedAt); return string.format("SESSION\n%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
end)
local ActiveModulesHUD = hudFeature("Active Modules HUD", "Shows the number of enabled Universal features", "Active", "Stats", function()
	return string.format("MODULES\n%d Active", activeCount())
end)
local FlightStatusHUD = hudFeature("Flight Status HUD", "Shows current Flight and Noclip states", "FlightStatus", "Stats", function()
	return string.format("MOVEMENT\nFlight %s  •  Noclip %s", Flight.Enabled and "ON" or "OFF", Noclip.Enabled and "ON" or "OFF")
end)
local DistanceHUD = hudFeature("Player Distance HUD", "Shows distance to the selected player", "Distance", "Slow", function()
	local target = findPlayer(); local _, _, root = getCharacter(); local other = rootOf(target)
	return target and root and other and string.format("DISTANCE\n%s  •  %s", target.Name, API.FormatDistance((root.Position - other.Position).Magnitude)) or "DISTANCE\nSelect a player"
end)
local TeamHUD = hudFeature("Team HUD", "Shows the selected player's current team", "Team", "Stats", function()
	local target = findPlayer(); return target and ("TEAM\n" .. target.Name .. "  •  " .. (target.Team and target.Team.Name or "Neutral")) or "TEAM\nSelect a player"
end)
local NearestPlayerHUD = hudFeature("Nearest Player HUD", "Finds the nearest other character at low frequency", "Nearest", "Slow", function()
	local _, _, root = getCharacter(); if not root then return "NEAREST\nWaiting" end
	local nearest, distance
	for _, target in ipairs(Players:GetPlayers()) do local other = target ~= player and rootOf(target) or nil
		if other then local value = (root.Position - other.Position).Magnitude; if not distance or value < distance then nearest, distance = target, value end end
	end
	return nearest and string.format("NEAREST\n%s  •  %s", nearest.Name, API.FormatDistance(distance)) or "NEAREST\nNone"
end)
local CompassHUD = hudFeature("Compass HUD", "Shows camera heading as a compass bearing", "Compass", "Slow", function()
	local camera = workspace.CurrentCamera; if not camera then return "COMPASS\nWaiting" end
	local look = camera.CFrame.LookVector; local degrees = (math.deg(math.atan2(-look.X, -look.Z)) + 360) % 360
	return string.format("COMPASS\n%03d degrees", degrees)
end)
local MemoryHUD = hudFeature("Memory HUD", "Shows total client memory reported by Roblox Stats", "Memory", "Stats", function()
	local memory = 0; pcall(function() memory = Stats:GetTotalMemoryUsageMb() end); return string.format("MEMORY\n%.0f MB", memory)
end)
local ServerInfoHUD = hudFeature("Server Info HUD", "Shows place and job identifiers", "ServerInfo", "Stats", function()
	return string.format("SERVER\nPlace %s  •  %d players", tostring(game.PlaceId), #Players:GetPlayers())
end)
local CameraFOVHUD = hudFeature("Camera FOV HUD", "Shows the active camera field of view", "CameraFOV", "Stats", function()
	local camera = workspace.CurrentCamera; return string.format("CAMERA\nFOV %.0f", camera and camera.FieldOfView or 0)
end)
local GravityHUD = hudFeature("Gravity HUD", "Shows current workspace gravity", "Gravity", "Stats", function() return string.format("GRAVITY\n%.1f", workspace.Gravity) end)
local HumanoidStateHUD = hudFeature("Humanoid State HUD", "Shows the local humanoid state", "HumanoidState", "Slow", function()
	local _, humanoid = getCharacter(); return "STATE\n" .. (humanoid and humanoid:GetState().Name or "Waiting")
end)
local WaypointDistanceHUD = hudFeature("Waypoint Distance HUD", "Shows distance to the Home saved position", "WaypointDistance", "Slow", function()
	local _, _, root = getCharacter(); local point = savedPositions.home
	return root and point and ("HOME WAYPOINT\n" .. API.FormatDistance((root.Position - point.Position).Magnitude)) or "HOME WAYPOINT\nNot saved"
end)

local BreadcrumbTrail = API.CreateFeature("Breadcrumb Trail", { Limit = 30, ToggleKey = Enum.KeyCode.Unknown })
function BreadcrumbTrail:OnEnable()
	self._parts = {}
	self:Track(Updates:Register("Universal:BreadcrumbTrail", "Stats", function()
		local _, _, root = getCharacter(); if not root then return end
		local part = Instance.new("Part"); part.Name = "FrostScriptsBreadcrumb"; part.Anchored = true; part.CanCollide = false
		part.Shape = Enum.PartType.Ball; part.Material = Enum.Material.Neon; part.Color = Color3.fromRGB(100, 205, 255)
		part.Size = Vector3.new(0.35, 0.35, 0.35); part.Position = root.Position - Vector3.new(0, 2.8, 0); part.Parent = workspace
		table.insert(self._parts, part); while #self._parts > self.Settings.Limit do table.remove(self._parts, 1):Destroy() end
	end)); self:SetStatus("Recording breadcrumbs"); return true
end
function BreadcrumbTrail:OnDisable() for _, part in ipairs(self._parts or {}) do part:Destroy() end; self._parts = {}; self:SetStatus("Breadcrumbs cleared") end
registerFeature(BreadcrumbTrail, "Navigation", "Places a bounded trail of lightweight local markers", function(module, feature)
	module:AddSlider("Marker limit", 5, 60, feature.Settings.Limit, function(value) feature:SetSetting("Limit", value) end, { Step = 5 })
end)

local actionEntries = {}
local function addAction(name, category, description, callback, configure, buttonText)
	table.insert(actionEntries, { Name = name, Category = category, Description = description, Callback = callback,
		Configure = configure, ButtonText = buttonText or "Run" })
end

addAction("Dash", "Movement", "Applies a forward velocity burst to the local root", function()
	local _, _, root = getCharacter(); local camera = workspace.CurrentCamera
	if root and camera then root.AssemblyLinearVelocity += camera.CFrame.LookVector * 90; addRecent("Dash") end
end)
addAction("Save Position", "Navigation", "Saves the current CFrame as Home for this session", function() savePosition("home") end, nil, "Save Home")
addAction("Return Position", "Navigation", "Returns to the Home position saved in this session", function() loadPosition("home") end, nil, "Return Home")
addAction("Death Position", "Navigation", "Returns to the last position recorded before a character removal", function()
	local _, _, root = getCharacter(); if root and deathPosition then root.CFrame = deathPosition else notify("Death position", "No death position recorded", "Error") end
end, nil, "Return to Death Position")
addAction("Click Teleport", "Movement", "Teleports to the current mouse hit once", function()
	local _, _, root = getCharacter(); local mouse = player:GetMouse(); if root and mouse and mouse.Hit then root.CFrame = mouse.Hit + Vector3.new(0, 3, 0); addRecent("Click Teleport") end
end, nil, "Teleport to Mouse")
addAction("Teleport to Player", "Players", "Moves the local root beside the selected player", function()
	local target = findPlayer(); local other = rootOf(target); local _, _, root = getCharacter()
	if root and other then root.CFrame = other.CFrame * CFrame.new(3, 0, 0); addRecent("Teleport to Player") else notify("Player", "Select an online player", "Error") end
end)
addAction("Copy Username", "Players", "Copies the selected player's account name", function() local target = findPlayer(); if target then copyText(target.Name) else notify("Player", "Select an online player", "Error") end end)
addAction("Copy UserId", "Players", "Copies the selected player's numeric user ID", function() local target = findPlayer(); if target then copyText(target.UserId) else notify("Player", "Select an online player", "Error") end end)
addAction("Player List", "Players", "Copies a compact list of players in the current server", function()
	local names = {}; for _, target in ipairs(Players:GetPlayers()) do table.insert(names, target.DisplayName .. " (@" .. target.Name .. ")") end; copyText(table.concat(names, "\n"))
end, nil, "Copy Player List")
addAction("Player Search", "Players", "Resolves a username or display-name prefix for player tools", nil, function(module)
	module:AddTextInput("Username or display name", selectedPlayerQuery, function(value) selectedPlayerQuery = value end, { Placeholder = "PlayerName" })
	module:AddButton("Find Player", function()
		local target = findPlayer()
		notify(target and "Player found" or "Player not found",
			target and (target.DisplayName .. " (@" .. target.Name .. ")") or selectedPlayerQuery, target and "Success" or "Error")
	end)
end)
addAction("Respawn", "Character", "Requests a clean local character respawn", function()
	local ok = pcall(function() player:LoadCharacter() end)
	if not ok then local _, humanoid = getCharacter(); if humanoid then humanoid.Health = 0 end end
end)
addAction("Reset Character", "Character", "Sets local humanoid health to zero", function() local _, humanoid = getCharacter(); if humanoid then humanoid.Health = 0 end end, nil, "Reset")
addAction("Stand Up", "Character", "Clears Sit and PlatformStand on the local humanoid", function()
	local _, humanoid = getCharacter(); if humanoid then humanoid.Sit = false; humanoid.PlatformStand = false; humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
end)
addAction("Remove Local Effects", "Character", "Deletes FrostScripts-created character effects only", function()
	local character = Character.Character; if character then for _, object in ipairs(character:GetDescendants()) do if object.Name:find("FrostScripts", 1, true) then object:Destroy() end end end
end)
addAction("Animation Selector", "Character", "Plays the configured Roblox animation on the current Animator", nil, function(module)
	local animationId = "507770239"
	module:AddTextInput("Animation ID", animationId, function(value) animationId = tostring(value):match("%d+") or animationId end)
	module:AddButton("Play Animation", function()
		local _, humanoid = getCharacter(); local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		if animator then local animation = Instance.new("Animation"); animation.AnimationId = "rbxassetid://" .. animationId
			local track = animator:LoadAnimation(animation); track:Play(); Debris:AddItem(animation, 2); addRecent("Animation Selector") end
	end)
end)
addAction("Custom Emote", "Fun", "Plays Roblox's default wave animation as a quick emote", function()
	local _, humanoid = getCharacter(); local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
	if animator then local animation = Instance.new("Animation"); animation.AnimationId = "rbxassetid://507770239"
		local track = animator:LoadAnimation(animation); track:Play(); Debris:AddItem(animation, 2) end
end, nil, "Wave")
addAction("Stop Animations", "Character", "Stops every animation track on the current Animator", function()
	local _, humanoid = getCharacter(); local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0.15) end end
end)
addAction("Rejoin", "Server", "Reconnects to the current server when possible", rejoin)
addAction("Server Hop", "Server", "Moves to another public server with available room", function() serverHop(false) end)
addAction("Small Server", "Server", "Finds a low-population public server", function() serverHop(false) end)
addAction("Large Server", "Server", "Finds a high-population public server with space", function() serverHop(true) end)
addAction("Copy JobId", "Server", "Copies the current Roblox server JobId", function() copyText(game.JobId) end)
addAction("Copy PlaceId", "Server", "Copies the current Roblox PlaceId", function() copyText(game.PlaceId) end)
addAction("Copy Server Link", "Server", "Copies a shareable roblox.com game link", function() copyText("https://www.roblox.com/games/" .. tostring(game.PlaceId)) end)
addAction("Day Preset", "World", "Sets local clock time to 14:00", function() Lighting.ClockTime = 14; addRecent("Day Preset") end)
addAction("Night Preset", "World", "Sets local clock time to 00:00", function() Lighting.ClockTime = 0; addRecent("Night Preset") end)
addAction("Sunset Preset", "World", "Sets local clock time to 18:30", function() Lighting.ClockTime = 18.5; addRecent("Sunset Preset") end)
addAction("Clear Local Weather", "World", "Disables local atmosphere and post-processing effects", function()
	for _, object in ipairs(Lighting:GetChildren()) do if object:IsA("PostEffect") then object.Enabled = false elseif object:IsA("Atmosphere") then object.Density = 0 end end
end)
addAction("Copy Coordinates", "Navigation", "Copies rounded character coordinates", function()
	local _, _, root = getCharacter(); if root then copyText(string.format("%.1f, %.1f, %.1f", root.Position.X, root.Position.Y, root.Position.Z)) end
end)
addAction("Face North", "Navigation", "Rotates the local root to world north", function()
	local _, _, root = getCharacter(); if root then root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, -1)) end
end)
addAction("Face Selected Player", "Navigation", "Turns the local root toward the selected player", function()
	local target = findPlayer(); local other = rootOf(target); local _, _, root = getCharacter()
	if root and other then root.CFrame = CFrame.lookAt(root.Position, Vector3.new(other.Position.X, root.Position.Y, other.Position.Z)) end
end)
addAction("Clear Breadcrumbs", "Navigation", "Clears active breadcrumb markers", function()
	if BreadcrumbTrail.Enabled then BreadcrumbTrail:SetEnabled(false); BreadcrumbTrail:SetEnabled(true) end
end)
addAction("FPS 30 Preset", "Performance", "Applies a 30 FPS cap when setfpscap is available", function() if type(env.setfpscap) == "function" then env.setfpscap(30) end end)
addAction("FPS 60 Preset", "Performance", "Applies a 60 FPS cap when setfpscap is available", function() if type(env.setfpscap) == "function" then env.setfpscap(60) end end)
addAction("FPS 144 Preset", "Performance", "Applies a 144 FPS cap when setfpscap is available", function() if type(env.setfpscap) == "function" then env.setfpscap(144) end end)
addAction("Open Favorites", "Utility", "Jumps directly to the Favorites tab", function() if Interface then Interface:SelectTab("Favorites") end end)
addAction("Open Module Search", "Utility", "Opens Modules and focuses the searchable catalog", function() if Interface then Interface:SelectTab("Modules"); Interface.Search:CaptureFocus() end end)
addAction("Clear Search", "Utility", "Clears the current tab search query", function() if Interface then Interface:SetSearch("") end end)
addAction("Hide Interface", "Utility", "Hides the workspace while leaving enabled modules active", function() if Interface then Interface:SetVisible(false) end end)
addAction("Show Interface", "Utility", "Makes the FrostScripts workspace visible", function() if Interface then Interface:SetVisible(true) end end)
addAction("Copy Session Summary", "Utility", "Copies FPS, ping, player count, and active-module status", function()
	copyText(string.format("FPS %d | Ping %dms | %d Modules Active | %d/%d Players", currentFPS, readPing(), activeCount(), #Players:GetPlayers(), Players.MaxPlayers))
end)
addAction("Save Session Config", "Utility", "Stores feature settings and enabled states for this executor session", function()
	local config = {}; for _, feature in ipairs(features) do config[feature.Name] = { Enabled = feature.Enabled, Settings = table.clone(feature.Settings) } end
	env.FrostScriptsUniversalConfig = config; notify("Config saved", "Session configuration stored", "Success")
end)
addAction("Load Session Config", "Utility", "Restores the last in-memory Universal configuration", function()
	local config = env.FrostScriptsUniversalConfig; if type(config) ~= "table" then notify("Config", "No saved session configuration", "Error"); return end
	for _, feature in ipairs(features) do local saved = config[feature.Name]; if saved then
		for key, value in pairs(saved.Settings or {}) do if feature.Settings[key] ~= nil then feature:SetSetting(key, value) end end
		feature:SetEnabled(saved.Enabled)
	end end; notify("Config loaded", "Session configuration restored", "Success")
end)

scope:Track(Character:OnRemoving(function(character)
	local root = character and character:FindFirstChild("HumanoidRootPart"); if root then deathPosition = root.CFrame end
end))

local function stopAll()
	for _, feature in ipairs(features) do feature:SetEnabled(false) end
	if MobileControls then MobileControls:SetVisible(false) end
	notify("Modules stopped", "All Universal modules were disabled.", "Info")
end
addAction("Panic", "Utility", "Immediately disables every enabled Universal feature", stopAll, nil, "STOP ALL")

local commandAliases = {
	unfly = "flight off", clip = "noclip off", fs = "flyspeed", ws = "speed", walkspeed = "speed",
	jp = "jump", jumppower = "jump", tp = "goto", spec = "spectate",
}
local function commandFeature(feature, argument)
	if argument == "off" or argument == "false" or argument == "0" then feature:SetEnabled(false)
	elseif argument == "on" or argument == "true" or argument == "1" or argument == nil then feature:SetEnabled(true)
	else feature:SetEnabled(not feature.Enabled) end
end
local function runCommand(text)
	local words = {}; for word in tostring(text or ""):gmatch("%S+") do table.insert(words, word) end
	if #words == 0 then return end
	local name = words[1]:lower(); table.remove(words, 1)
	local alias = commandAliases[name]
	if alias then local expanded = {}; for word in alias:gmatch("%S+") do table.insert(expanded, word) end
		name = table.remove(expanded, 1); for index = #expanded, 1, -1 do table.insert(words, 1, expanded[index]) end end
	local argument = words[1] and words[1]:lower() or nil
	if name == "fly" then commandFeature(Flight, argument)
	elseif name == "noclip" then commandFeature(Noclip, argument)
	elseif name == "freecam" then commandFeature(Freecam, argument)
	elseif name == "fullbright" then commandFeature(Fullbright, argument)
	elseif name == "nofog" then commandFeature(NoFog, argument)
	elseif name == "fpsboost" then commandFeature(FPSBoost, argument)
	elseif name == "antiafk" then commandFeature(AntiAFK, argument)
	elseif name == "mobile" then commandFeature(MobileMode, argument)
	elseif name == "flyspeed" then local value = tonumber(words[1]); if value then Flight:SetSetting("Speed", math.clamp(value, 10, 250)) end
	elseif name == "speed" then local value = tonumber(words[1]); if value then Speed:SetSetting("Speed", math.clamp(value, 8, 250)); Speed:SetEnabled(true) end
	elseif name == "jump" then local value = tonumber(words[1]); if value then JumpPower:SetSetting("Power", math.clamp(value, 25, 300)); JumpPower:SetEnabled(true) end
	elseif name == "gravity" then local value = tonumber(words[1]); if value then Gravity:SetSetting("Gravity", math.clamp(value, 0, 300)); Gravity:SetEnabled(true) end
	elseif name == "goto" then selectedPlayerQuery = table.concat(words, " "); local target = findPlayer(); local other = rootOf(target); local _, _, root = getCharacter(); if root and other then root.CFrame = other.CFrame * CFrame.new(3, 0, 0) end
	elseif name == "spectate" then selectedPlayerQuery = table.concat(words, " "); Spectate:SetEnabled(false); Spectate:SetEnabled(true)
	elseif name == "follow" then selectedPlayerQuery = table.concat(words, " "); FollowPlayer:SetEnabled(true)
	elseif name == "fov" then local value = tonumber(words[1]); if value then FieldOfView:SetSetting("FOV", math.clamp(value, 30, 120)); FieldOfView:SetEnabled(true) end
	elseif name == "day" then Lighting.ClockTime = 14
	elseif name == "night" then Lighting.ClockTime = 0
	elseif name == "savepos" then savePosition(words[1] or "home")
	elseif name == "loadpos" then loadPosition(words[1] or "home")
	elseif name == "serverhop" then serverHop(false)
	elseif name == "rejoin" then rejoin()
	elseif name == "panic" then stopAll()
	elseif name == "reset" then local _, humanoid = getCharacter(); if humanoid then humanoid.Health = 0 end
	else notify("Unknown command", name, "Error"); return false end
	addRecent("Command: " .. name); return true
end

local UI = API.LoadUI()
Interface = UI.new({ TextScope = "Universal", Name = "FrostScripts", Game = "Universal",
	GuiName = "FrostScriptsUniversalUI", OverlayName = "FrostScriptsUniversalOverlays" })

local Home = Interface:AddTab("Home", "home", "Universal tools and live session status")
local Favorites = Interface:AddFavoritesTab("Favorites", "favorites", "Your pinned modules and shortcuts")
local Modules = Interface:AddTab("Modules", "modules", "Fast, respawn-safe tools grouped by category")
local Settings = Interface:AddTab("UI Settings", "settings", "Appearance, motion, sound, and mobile controls")
Modules:SetCategories({ "All", "Movement", "Character", "Camera", "World", "Players", "Server", "Navigation", "Performance", "Fun", "Utility", "HUD" }, "All")

local overview = Home:AddModule({ Name = "Universal ready", Description = "A focused suite of tested local tools", Accent = true, Collapsible = false })
local overviewText = overview:AddParagraph("Catalog", "Loading modules…", { Height = 62 })

local quick = Home:AddModule({ Name = "Quick Actions", Description = "The eight controls most useful across Roblox", Collapsible = false })
local quickFeatures = {
	{ Label = "FLY", Feature = Flight }, { Label = "NOCLIP", Feature = Noclip }, { Label = "SPEED", Feature = Speed },
	{ Label = "INFINITE JUMP", Feature = InfiniteJump }, { Label = "FREECAM", Feature = Freecam },
	{ Label = "FULLBRIGHT", Feature = Fullbright }, { Label = "ANTI-AFK", Feature = AntiAFK }, { Label = "FPS BOOST", Feature = FPSBoost },
}
local actionSpecs = {}
for _, item in ipairs(quickFeatures) do table.insert(actionSpecs, { Name = item.Label, Active = item.Feature.Enabled,
	Callback = function() item.Feature:SetEnabled(not item.Feature.Enabled) end }) end
local quickControls = quick:AddActionGrid(actionSpecs, { Columns = 2, ButtonHeight = 42 })

local status = Home:AddModule({ Name = "Status", Description = "Live session telemetry", Collapsible = false })
local statusText = status:AddParagraph("Current session", "FPS —  |  Ping —  |  0 Modules Active", { Height = 82 })

local recentlyUsed = Home:AddModule({ Name = "Recently Used", Description = "Your five latest module activations and commands", Collapsible = false })
Interface.RecentText = recentlyUsed:AddParagraph("History", "Nothing used yet", { Height = 52 })

local targetCard = Home:AddModule({ Name = "Player Target", Description = "Used by goto, spectate, follow, highlight, and player HUDs", Collapsible = false })
targetCard:AddTextInput("Username or display name", "", function(value) selectedPlayerQuery = value end, { Placeholder = "PlayerName" })

local commandCard = Home:AddModule({ Name = "Command Bar", Description = "Commands: fly, noclip, speed, jump, goto, spectate, follow, freecam, fov, fullbright, nofog, day, night, savepos, loadpos, serverhop, panic", Collapsible = false })
local pendingCommand = ""
commandCard:AddTextInput("Command", "", function(value) pendingCommand = value end, { Placeholder = "flyspeed 50" })
commandCard:AddButton("Run Command", function() runCommand(pendingCommand) end)

local session = Home:AddModule({ Name = "Session Controls", Description = "Server actions and emergency cleanup", Collapsible = false })
session:AddButton("Rejoin current server", rejoin)
session:AddButton("Disable all modules", stopAll, { Danger = true })

local function addFeatureModule(entry)
	local feature = entry.Feature
	local module = Modules:AddModule({ Name = feature.Name, Description = entry.Description .. "  •  " .. entry.Compatibility,
		Category = entry.Category, Feature = feature, Toggleable = true, Favoritable = true,
		FavoriteId = "Universal:" .. feature.Name, Default = feature.Enabled,
		Callback = function(enabled) feature:SetEnabled(enabled) end })
	modulesByName[feature.Name] = module
	module:AddKeybind({ Name = "Toggle " .. feature.Name, Get = function() return feature.Settings.ToggleKey end,
		Set = function(key) feature:SetSetting("ToggleKey", key) end, OnPressed = function() feature:SetEnabled(not feature.Enabled) end })
	if entry.Configure then entry.Configure(module, feature) end
	return module
end
for _, entry in ipairs(entries) do addFeatureModule(entry) end

for _, entry in ipairs(actionEntries) do
	local module = Modules:AddModule({ Name = entry.Name, Description = entry.Description, Category = entry.Category,
		Favoritable = true, FavoriteId = "Universal:" .. entry.Name, Collapsible = true,
		FavoriteAction = entry.Callback, FavoriteActionText = entry.ButtonText })
	modulesByName[entry.Name] = module
	if entry.Configure then entry.Configure(module) else module:AddButton(entry.ButtonText, function() entry.Callback(); addRecent(entry.Name) end) end
end

local utilityCards = {
	{ "Favorites Guide", "Utility", "Star any module to pin a synchronized shortcut in Favorites.", function() Interface:SelectTab(Favorites) end, "Open Favorites" },
	{ "Recent Modules", "Utility", "Shows the five latest activations on Home.", function() Interface:SelectTab(Home) end, "Open Recent" },
	{ "Module Search", "Utility", "Searches names, descriptions, settings, and commands.", function() Interface:SelectTab(Modules); Interface.Search:CaptureFocus() end, "Search" },
	{ "Keybind Manager", "Utility", "Every toggleable module owns its conflict-checked keybind.", function() Interface:SelectTab(Modules); Interface:SetSearch("Toggle") end, "Find Keybinds" },
	{ "Quick Toggle Menu", "Utility", "The Home grid and mobile overlay expose the same eight core features.", function() Interface:SelectTab(Home) end, "Open Quick Actions" },
	{ "Compatibility Guide", "Utility", "Universal modules are local; vehicle, animation, and executor tools show compatibility notes.", function() Interface:SelectTab(Modules) end, "Browse Compatibility" },
}
local catalogSize = #entries + #actionEntries + #utilityCards
assert(catalogSize >= 100 and catalogSize <= 200, "Universal catalog must stay focused between 100 and 200 modules")
for _, item in ipairs(utilityCards) do
	local module = Modules:AddModule({ Name = item[1], Description = item[3], Category = item[2], Favoritable = true,
		FavoriteId = "Universal:" .. item[1], FavoriteAction = item[4], FavoriteActionText = item[5] })
	module:AddButton(item[5], item[4]); modulesByName[item[1]] = module
end

Interface:AddClientSettings(Settings)
local mobileSettings = Settings:AddModule({ Name = "Mobile Mode", Description = "Large touch controls that stay usable when the main window is hidden", Collapsible = false })
MobileControls = Interface:CreateMobileControls()
local mobileToggle = mobileSettings:AddToggle("Show mobile controls", UserInputService.TouchEnabled, function(enabled) MobileMode:SetEnabled(enabled) end,
	"Includes D-pad movement, rise/drop controls, and eight quick toggles")
scope:Track(MobileMode:ObserveState(function(enabled) mobileToggle:SetValue(enabled, true) end))

for index, item in ipairs(quickFeatures) do
	local quickControl = quickControls[index]
	local mobileControl = MobileControls:AddToggle(item.Label, function() item.Feature:SetEnabled(not item.Feature.Enabled) end)
	scope:Track(item.Feature:ObserveState(function(enabled)
		quickControl:SetActive(enabled); mobileControl:SetActive(enabled)
	end))
end
if UserInputService.TouchEnabled then MobileMode:SetEnabled(true) end

overviewText:SetText(string.format("%d modules across 11 categories. Every toggle owns cleanup, search, favorites, and a module-local keybind.", catalogSize))

scope:Track(Updates:Register("Universal:StatusBar", "Stats", function(dt)
	if frameElapsed > 0 then currentFPS = math.floor(frameCount / frameElapsed + 0.5) end
	frameCount, frameElapsed = 0, 0
	local active = activeCount(); local ping = readPing(); local elapsed = math.floor(os.clock() - startedAt)
	local footer = string.format("FPS %d  |  Ping %dms  |  %d Modules Active", currentFPS, ping, active)
	statusText:SetText(string.format("Game  %s\nServer  %d / %d  |  FPS  %d  |  Ping  %d ms\nModules  %d Active  |  Session  %02d:%02d:%02d",
		gameName, #Players:GetPlayers(), Players.MaxPlayers, currentFPS, ping, active,
		math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60))
	Home:SetStatusBar(footer)
end))

Interface:SelectTab(Home)

local Suite = { Window = Interface, Interface = Interface, Features = features, Modules = modulesByName,
	UpdateManager = Updates, CharacterManager = Character, RunCommand = runCommand }
function Suite:Unload()
	if self.Unloaded then return end; self.Unloaded = true
	for _, feature in ipairs(features) do feature:Destroy() end
	scope:Destroy(); Interface:Destroy()
	if env.FrostScriptsUniversal == self then env.FrostScriptsUniversal = nil end
end

env.FrostScriptsUniversal = Suite
session:AddButton("Unload FrostScripts", function() Suite:Unload() end, { Danger = true })
return Suite
