-- Game-specific entry; invoked by FrostScriptsAPI.RunGame.
local API = ...
assert(type(API) == "table" and type(API.CreateFeature) == "function", "Launch this game through its dist/launchers entry point")

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")



local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Interface

local scope = API.CreateScope()
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.FrostScriptsGrassCutter then env.FrostScriptsGrassCutter:Unload() end
local Fly = API.UniversalModules.CreateFlight({
	Name = "Fly", Speed = 60, VerticalSpeed = 45,
	IsInputCaptured = function() return Interface and Interface:IsCapturingInput() end,
})
local AutoStrengthFarm = API.UniversalModules.CreateAutoClicker({
	Name = "Auto Strength Farm", ClicksPerSecond = 8,
	IsInputCaptured = function() return Interface and Interface:IsCapturingInput() end,
})
scope:Track(player.CharacterAdded:Connect(function() Fly:Disable() end))

local Runtime = {
	MainGui = nil,
	MoveTween = nil,
	NavigationOwner = nil,
	NavigationPriority = 0,
	NavigationExpires = 0,
	NavigationSerial = 0,
	LootCatalog = nil,
	LootCatalogAt = 0,
	LootInfo = {},
	CapacityRemotes = nil,
	CapacityCache = nil,
}

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Celestial", "Eternal", "Secret" }
local RARITY_RANK = {}
local RARITY_TAG_NAMES = {
	Mythical = { "Mythical", "Mythic" },
	Eternal = { "Eternal", "Ethernal" },
}
local RARITY_COLORS = {
	Common = Color3.fromRGB(184, 189, 198),
	Uncommon = Color3.fromRGB(92, 196, 146),
	Rare = Color3.fromRGB(88, 155, 255),
	Epic = Color3.fromRGB(170, 103, 255),
	Legendary = Color3.fromRGB(255, 188, 74),
	Mythical = Color3.fromRGB(255, 92, 118),
	Celestial = Color3.fromRGB(101, 229, 238),
	Eternal = Color3.fromRGB(240, 240, 255),
	Secret = Color3.fromRGB(255, 92, 214),
}
for index, rarity in ipairs(RARITIES) do
	RARITY_RANK[rarity] = index
end

local newFeature = API.CreateFeature

local getCharacter = API.GetCharacter

local getPosition = API.GetPosition

local function formatNumber(value) return API.FormatNumber(value, true) end

local function parseGameNumber(text)
	if type(text) == "number" then return text end
	if type(text) ~= "string" then return nil end
	local cleaned = text:gsub("[%s,$]", "")
	local number, suffix = cleaned:match("([%d%.]+)([KkMmBbTtQq]?)")
	number = tonumber(number)
	if not number then return nil end
	local multipliers = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, Q = 1e15 }
	return number * (multipliers[suffix:upper()] or 1)
end

local function readNumber(names)
	for _, name in ipairs(names) do
		local attribute = player:GetAttribute(name)
		if tonumber(attribute) then return tonumber(attribute), "@" .. name end
	end
	for _, descendant in ipairs(player:GetDescendants()) do
		if descendant:IsA("ValueBase") then
			for _, name in ipairs(names) do
				if descendant.Name == name and tonumber(descendant.Value) then
					return tonumber(descendant.Value), descendant:GetFullName()
				end
			end
		end
	end
	return nil
end

local function findRemoteFunction(serviceName, functionName)
	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("RemoteFunction") and descendant.Name == functionName then
			local service = descendant:FindFirstAncestor(serviceName)
			if service then return descendant end
		end
	end
	return nil
end

local function capacityFromState(state)
	if type(state) ~= "table" then return nil end
	local currentKeys = { "UsedSlots", "CurrentSlots", "OccupiedSlots", "Used", "Current", "Count", "Load" }
	local maximumKeys = { "MaxSlots", "TotalSlots", "Capacity", "Maximum", "Max" }
	local current, maximum, remaining
	for _, key in ipairs(currentKeys) do
		if tonumber(state[key]) then
			current = tonumber(state[key])
			break
		end
	end
	for _, key in ipairs(maximumKeys) do
		if tonumber(state[key]) then
			maximum = tonumber(state[key])
			break
		end
	end
	for key, value in pairs(state) do
		if type(key) == "string" and type(value) == "table" and key:lower():find("slot") and not current then
			current = 0
			for _, slot in pairs(value) do if slot ~= nil and slot ~= false then current += 1 end end
		elseif type(key) == "string" and tonumber(value) then
			local lower, numeric = key:lower(), tonumber(value)
			if (lower:find("slot") or lower:find("capacity")) and (lower:find("max") or lower:find("total") or lower == "capacity") then
				maximum = maximum or numeric
			elseif lower:find("slot") and (lower:find("used") or lower:find("occupied") or lower:find("current") or lower:find("filled")) then
				current = current or numeric
			elseif lower == "slots" or lower == "slotcount" then
				current = current or numeric
			elseif lower:find("slot") and (lower:find("free") or lower:find("available") or lower:find("remaining")) then
				remaining = remaining or numeric
			end
		end
	end
	if not current and maximum and remaining then current = math.max(0, maximum - remaining) end
	if not current and type(state.Slots) == "table" then
		current = 0
		for _, slot in pairs(state.Slots) do
			if slot ~= nil and slot ~= false then current += 1 end
		end
	end
	if current and maximum and maximum > 0 then return current, maximum, current / maximum * 100 end
	for _, child in pairs(state) do
		if type(child) == "table" then
			local nestedCurrent, nestedMaximum, nestedPercent = capacityFromState(child)
			if nestedPercent then return nestedCurrent, nestedMaximum, nestedPercent end
		end
	end
	return nil
end

local function readCapacity()
	if Runtime.CapacityCache and os.clock() - Runtime.CapacityCache.time < 0.65 then
		return Runtime.CapacityCache.current, Runtime.CapacityCache.maximum, Runtime.CapacityCache.percent
	end
	if not Runtime.CapacityRemotes then
		Runtime.CapacityRemotes = {}
		for _, remoteName in ipairs({ "GetBackpackSlotsState", "GetBackpackSlotsSummary" }) do
			local remote = findRemoteFunction("DataService", remoteName)
			if remote then table.insert(Runtime.CapacityRemotes, remote) end
		end
	end
	for _, remote in ipairs(Runtime.CapacityRemotes) do
		if remote and remote.Parent then
			local ok, state = pcall(function() return remote:InvokeServer() end)
			if ok then
				local current, maximum, percent = capacityFromState(state)
				if percent then
					Runtime.CapacityCache = { current = current, maximum = maximum, percent = percent, time = os.clock() }
					return current, maximum, percent
				end
			end
		end
	end
	local current = readNumber({ "BackpackLoadRaw", "BackpackLoad", "CurrentCarry", "Carry", "InventoryLoad", "Load" })
	local maximum = readNumber({ "MaxCarryRaw", "MaxCarry", "CarryCapacity", "InventoryCapacity", "Capacity" })
	if not current or not maximum then
		for name, value in pairs(player:GetAttributes()) do
			local lower = name:lower()
			local numeric = tonumber(value)
			if numeric and (lower:find("carry") or lower:find("backpack") or lower:find("inventory") or lower:find("load")) then
				if lower:find("max") or lower:find("capacity") then
					maximum = maximum or numeric
				else
					current = current or numeric
				end
			end
		end
	end
	if not current or not maximum then
		for _, descendant in ipairs(playerGui:GetDescendants()) do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				local context = (descendant:GetFullName() .. " " .. descendant.Text):lower()
				if context:find("carry") or context:find("backpack") or context:find("inventory") or context:find("loot") then
					local left, right = descendant.Text:match("([^/]+)%s*/%s*([^/]+)")
					local parsedCurrent, parsedMaximum = parseGameNumber(left), parseGameNumber(right)
					if parsedCurrent and parsedMaximum and parsedMaximum > 0 then
						current, maximum = parsedCurrent, parsedMaximum
						break
					end
				end
			end
		end
	end
	if current and maximum and maximum > 0 then
		return current, maximum, current / maximum * 100
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local toolCount = 0
	if backpack then toolCount += #backpack:GetChildren() end
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then toolCount += 1 end
		end
	end
	if toolCount > 0 then return toolCount, nil, nil end
	return nil
end

local function findNamedDescendant(root, className, name)
	if not root then return nil end
	for _, descendant in ipairs(root:GetDescendants()) do
		if (not className or descendant:IsA(className)) and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function findServiceFolder(serviceName)
	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("Folder") and descendant.Name == serviceName then
			return descendant
		end
	end
	return nil
end

local function navigateTo(target, mode, owner, priority, claimDuration, options)
	options = options or {}
	local position = typeof(target) == "Vector3" and target or getPosition(target)
	local _, humanoid, root = getCharacter()
	if not position or not humanoid or not root then return false end
	local now = os.clock()
	priority = priority or 50
	if Runtime.NavigationOwner == owner and now < Runtime.NavigationExpires then return true end
	if Runtime.NavigationOwner and Runtime.NavigationOwner ~= owner and now < Runtime.NavigationExpires
		and priority < Runtime.NavigationPriority then
		return false
	end
	Runtime.NavigationOwner = owner
	Runtime.NavigationPriority = priority
	local travelDistance = (root.Position - position).Magnitude
	local reservation = (mode == "Fly" or mode == "Tween")
		and math.max(claimDuration or 1, travelDistance / 80 + 2) or (claimDuration or 1)
	Runtime.NavigationExpires = now + reservation
	Runtime.NavigationSerial += 1
	local navigationSerial = Runtime.NavigationSerial
	local destination = options.ExactDestination and position
		or position + Vector3.new(0, options.HeightOffset or 3, 0)
	if Runtime.MoveTween then
		Runtime.MoveTween:Cancel()
		Runtime.MoveTween = nil
	end
	if mode == "Teleport" then
		root.CFrame = CFrame.new(destination)
	elseif mode == "Fly" then
		local cruiseY = math.max(root.Position.Y, destination.Y) + (options.CruiseHeight or 14)
		task.spawn(function()
			local waypoints = {
				Vector3.new(root.Position.X, cruiseY, root.Position.Z),
				Vector3.new(destination.X, cruiseY, destination.Z),
				destination,
			}
			for _, waypoint in ipairs(waypoints) do
				if Runtime.NavigationSerial ~= navigationSerial or not root.Parent then return end
				local distance = (root.Position - waypoint).Magnitude
				local tween = TweenService:Create(root, TweenInfo.new(math.clamp(distance / 100, 0.12, 3), Enum.EasingStyle.Linear), {
					CFrame = CFrame.new(waypoint),
				})
				Runtime.MoveTween = tween
				tween:Play()
				tween.Completed:Wait()
			end
			if Runtime.NavigationSerial == navigationSerial then
				Runtime.NavigationOwner, Runtime.NavigationPriority, Runtime.NavigationExpires = nil, 0, 0
			end
		end)
	elseif mode == "Tween" then
		local distance = (root.Position - destination).Magnitude
		Runtime.MoveTween = TweenService:Create(root, TweenInfo.new(math.clamp(distance / 90, 0.15, 4), Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(destination),
		})
		Runtime.MoveTween:Play()
	else
		humanoid:MoveTo(destination)
	end
	if mode ~= "Fly" then
		task.delay(claimDuration or 1, function()
			if Runtime.NavigationSerial == navigationSerial then
				Runtime.NavigationOwner, Runtime.NavigationPriority, Runtime.NavigationExpires = nil, 0, 0
			end
		end)
	end
	return true
end

local function getPromptApproachPosition(prompt, root)
	local position = prompt and getPosition(prompt.Parent)
	if not position then return nil end
	local offsetDirection = root and Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
	if not offsetDirection or offsetDirection.Magnitude < 0.01 then
		local camera = workspace.CurrentCamera
		local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
		offsetDirection = Vector3.new(-look.X, 0, -look.Z)
	end
	offsetDirection = offsetDirection.Magnitude > 0.01 and offsetDirection.Unit or Vector3.new(0, 0, 1)
	local activationDistance = math.max(1, tonumber(prompt.MaxActivationDistance) or 10)
	local horizontalOffset = math.clamp(activationDistance * 0.18, 0.6, 1.6)
	local verticalOffset = math.clamp(activationDistance * 0.08, 0.25, 0.65)
	return position + offsetDirection * horizontalOffset + Vector3.new(0, verticalOffset, 0)
end

local function triggerPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
	local previousLineOfSight = prompt.RequiresLineOfSight
	prompt.RequiresLineOfSight = false
	if type(fireproximityprompt) == "function" then
		local fired = pcall(fireproximityprompt, prompt, math.max(0.08, prompt.HoldDuration))
		task.delay(0.35, function()
			if prompt.Parent then prompt.RequiresLineOfSight = previousLineOfSight end
		end)
		return fired
	end
	local ok = pcall(function()
		prompt:InputHoldBegin()
		task.wait(math.max(0.08, prompt.HoldDuration) + 0.08)
		if prompt.Parent then prompt:InputHoldEnd() end
	end)
	if prompt.Parent then prompt.RequiresLineOfSight = previousLineOfSight end
	return ok
end

local function approachPrompt(prompt, mode, onTriggered, owner, priority)
	if not prompt then return false end
	local _, _, root = getCharacter()
	local destination = getPromptApproachPosition(prompt, root)
	if not destination or not navigateTo(destination, mode, owner, priority, 10, {
		ExactDestination = true,
		CruiseHeight = 10,
	}) then return false end
	task.spawn(function()
		local deadline = os.clock() + 10
		while prompt.Parent and os.clock() < deadline do
			local _, _, root = getCharacter()
			local position = getPosition(prompt.Parent)
			local activationDistance = math.max(0.75, prompt.MaxActivationDistance - 0.35)
			if root and position and (root.Position - position).Magnitude <= activationDistance then
				if triggerPrompt(prompt) and onTriggered then task.delay(0.4, onTriggered) end
				return
			end
			task.wait(0.15)
		end
	end)
	return true
end

local function isGuiVisible(object)
	local current = object
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then return false end
		current = current.Parent
	end
	return object.AbsoluteSize.X > 0 and object.AbsoluteSize.Y > 0
end

local function activateVisibleButton(labels)
	if type(firesignal) ~= "function" then return false end
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiButton") and isGuiVisible(descendant)
			and (not Runtime.MainGui or not descendant:IsDescendantOf(Runtime.MainGui)) then
			local text = descendant:IsA("TextButton") and descendant.Text or descendant.Name
			local normalized = (descendant.Name .. " " .. text):lower()
			for _, label in ipairs(labels) do
				if normalized:find(label:lower(), 1, true) then
					if type(getconnections) == "function" and #getconnections(descendant.Activated) == 0 then
						firesignal(descendant.MouseButton1Click)
					else
						firesignal(descendant.Activated)
					end
					return true
				end
			end
		end
	end
	return false
end

local function clickGuiButton(button)
	if not button or not button:IsA("GuiButton") or type(firesignal) ~= "function" then return false end
	if type(getconnections) == "function" and #getconnections(button.Activated) == 0 then
		firesignal(button.MouseButton1Click)
	else
		firesignal(button.Activated)
	end
	return true
end

local function activateSellAllButton()
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiButton") and isGuiVisible(descendant)
			and descendant:GetFullName():lower():gsub("[^%w]", ""):find("sellall", 1, true) then
			return clickGuiButton(descendant)
		end
	end
	return false
end

local function scanUpgradeAffordability()
	local money = readNumber({ "MoneyRaw", "Money" }) or 0
	local total, affordable = 0, 0
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiButton") and isGuiVisible(descendant)
			and (not Runtime.MainGui or not descendant:IsDescendantOf(Runtime.MainGui))
			and descendant:GetFullName():lower():find("upgrade", 1, true) then
			local price
			if descendant:IsA("TextButton") then price = parseGameNumber(descendant.Text) end
			for _, child in ipairs(descendant:GetDescendants()) do
				if child:IsA("TextLabel") and (child.Name:lower():find("price") or child.Text:find("$", 1, true)) then
					price = parseGameNumber(child.Text) or price
				end
			end
			if price and price > 0 then
				total += 1
				if money >= price then affordable += 1 end
			end
		end
	end
	return affordable, total, money
end

local function normalizeLootName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function rarityFromValue(value)
	local normalized = tostring(value or ""):lower()
	if normalized:find("ethernal", 1, true) or normalized:find("eternal", 1, true) then return "Eternal" end
	if normalized:find("mythical", 1, true) or normalized:find("mythic", 1, true) then return "Mythical" end
	for _, rarity in ipairs(RARITIES) do
		if normalized:find(rarity:lower(), 1, true) then return rarity end
	end
	return nil
end

local function buildLootCatalog()
	local catalog, seen = {}, {}
	local function add(key, record)
		if type(record) ~= "table" then return end
		local name = record.DisplayName or record.Name or record.ItemName or record.LootName or key
		local rarity = rarityFromValue(record.Rarity or record.Tier or record.Grade)
		local rawValue = record.SellPrice or record.SalePrice or record.SellValue or record.CashValue
			or record.Worth or record.Value or record.BaseValue or record.Price or record.Money
		local value = tonumber(rawValue) or parseGameNumber(rawValue)
		if name and (rarity or value) then catalog[normalizeLootName(name)] = { name = tostring(name), rarity = rarity, value = value } end
	end
	local function walk(value, key, depth)
		if type(value) ~= "table" or seen[value] or depth > 6 then return end
		seen[value] = true
		add(key, value)
		for childKey, child in pairs(value) do walk(child, childKey, depth + 1) end
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configs = shared and shared:FindFirstChild("Configs")
	local lootConfig = configs and configs:FindFirstChild("Loot")
	if lootConfig and lootConfig:IsA("ModuleScript") then
		local ok, config = pcall(require, lootConfig)
		if ok then walk(config, nil, 0) end
	end
	local lootIndexRemote = findRemoteFunction("DataService", "GetLootIndexData")
	if lootIndexRemote then
		local ok, indexData = pcall(function() return lootIndexRemote:InvokeServer() end)
		if ok then walk(indexData, nil, 0) end
	end
	local indexGui = playerGui:FindFirstChild("IndexGUI")
	if indexGui then
		for _, entry in ipairs(indexGui:GetDescendants()) do
			local openFrame = entry:FindFirstChild("OpenFrame")
			if openFrame then
				local nameLabel = openFrame:FindFirstChild("Name")
				local rarityLabel = openFrame:FindFirstChild("Rarity")
				local displayName = nameLabel and nameLabel:IsA("TextLabel") and nameLabel.Text or entry.Name
				local rarity = rarityLabel and rarityLabel:IsA("TextLabel") and rarityFromValue(rarityLabel.Text)
				if rarity and displayName ~= "" then
					local existing = catalog[normalizeLootName(displayName)] or {}
					existing.name, existing.rarity = displayName, rarity
					catalog[normalizeLootName(displayName)] = existing
				end
			end
		end
	end
	Runtime.LootCatalog = catalog
	Runtime.LootCatalogAt = os.clock()
	return catalog
end

local function getLootInfo(object)
	local prompt = object:IsA("ProximityPrompt") and object or object:FindFirstChildWhichIsA("ProximityPrompt", true)
	local cached = prompt and Runtime.LootInfo[prompt]
	if cached then
		local cacheLifetime = cached.rarity == "Unknown" and 2 or 30
		if os.clock() - (cached._cachedAt or 0) < cacheLifetime then return cached end
	end
	local catalog = Runtime.LootCatalog
	if not catalog or os.clock() - Runtime.LootCatalogAt > 60 then catalog = buildLootCatalog() end
	local names, explicitRarity, explicitValue = {}, nil, nil
	if object:IsA("ProximityPrompt") then
		if object.ObjectText ~= "" then table.insert(names, object.ObjectText) end
		explicitRarity = rarityFromValue(object.ObjectText .. " " .. object.ActionText)
		explicitValue = parseGameNumber(object.ObjectText) or parseGameNumber(object.ActionText)
	end
	local current = object
	while current and current ~= workspace do
		table.insert(names, current.Name)
		for _, tag in ipairs(CollectionService:GetTags(current)) do
			explicitRarity = explicitRarity or rarityFromValue(tag)
		end
		for _, attributeName in ipairs({ "Rarity", "LootRarity", "Tier", "Grade" }) do
			explicitRarity = explicitRarity or rarityFromValue(current:GetAttribute(attributeName))
		end
		for _, attributeName in ipairs({ "SellPrice", "SalePrice", "Worth", "Value", "Price", "Money" }) do
			local attribute = current:GetAttribute(attributeName)
			explicitValue = explicitValue or tonumber(attribute) or parseGameNumber(attribute)
		end
		local rarityValue = current:FindFirstChild("Rarity") or current:FindFirstChild("Tier")
		if rarityValue and rarityValue:IsA("ValueBase") then explicitRarity = explicitRarity or rarityFromValue(rarityValue.Value) end
		for _, valueName in ipairs({ "SellPrice", "SalePrice", "SellValue", "Worth", "Value", "Price" }) do
			local valueObject = current:FindFirstChild(valueName)
			if valueObject and valueObject:IsA("ValueBase") then
				explicitValue = explicitValue or tonumber(valueObject.Value) or parseGameNumber(valueObject.Value)
			end
		end
		current = current.Parent
	end
	local model = object:FindFirstAncestorWhichIsA("Model")
	if model then
		for _, descendant in ipairs(model:GetDescendants()) do
			local lower = descendant.Name:lower()
			if descendant:IsA("ValueBase") then
				if lower:find("rarity") or lower == "tier" then explicitRarity = explicitRarity or rarityFromValue(descendant.Value) end
				if lower:find("price") or lower:find("worth") or lower:find("value") then
					explicitValue = explicitValue or tonumber(descendant.Value) or parseGameNumber(descendant.Value)
				end
			elseif descendant:IsA("TextLabel") then
				if lower:find("rarity") then explicitRarity = explicitRarity or rarityFromValue(descendant.Text) end
				if lower:find("price") or lower:find("worth") or descendant.Text:find("$", 1, true) then
					explicitValue = explicitValue or parseGameNumber(descendant.Text)
				end
			end
		end
	end
	local catalogEntry
	for _, name in ipairs(names) do
		local normalized = normalizeLootName(name:gsub("^%d+_", ""))
		catalogEntry = catalog[normalized]
		if not catalogEntry then
			for catalogName, entry in pairs(catalog) do
				if #catalogName >= 3 and normalized:find(catalogName, 1, true) then
					catalogEntry = entry
					break
				end
			end
		end
		if catalogEntry then break end
	end
	local fallbackName
	for _, name in ipairs(names) do
		local normalized = normalizeLootName(name)
		if normalized ~= "pickupprompt" and normalized ~= "spawnzone" and normalized ~= "loot" and not normalized:match("^zone%d*$") then
			fallbackName = name
			break
		end
	end
	local displayName = catalogEntry and catalogEntry.name or fallbackName or "Loot"
	local info = {
		name = tostring(displayName):gsub("^%d+_", ""):gsub("_", " "),
		rarity = explicitRarity or (catalogEntry and catalogEntry.rarity) or "Unknown",
		value = explicitValue or (catalogEntry and catalogEntry.value) or 0,
		_cachedAt = os.clock(),
	}
	if prompt then Runtime.LootInfo[prompt] = info end
	return info
end

local function rarityAllowed(rarity, minimum)
	return (RARITY_RANK[rarity] or 1) >= (RARITY_RANK[minimum] or 1)
end

local function getLootPrompts()
	if not Runtime.LootPrompts then
		Runtime.LootPrompts = {}
		local function track(instance)
			if not instance:IsA("ProximityPrompt") or instance.Name ~= "PickupPrompt" then return end
			local model = instance:FindFirstAncestorWhichIsA("Model")
			local owningPlayer = model and Players:GetPlayerFromCharacter(model)
			if not owningPlayer or owningPlayer == player then Runtime.LootPrompts[instance] = true end
		end
		for _, descendant in ipairs(workspace:GetDescendants()) do track(descendant) end
		scope:Track(workspace.DescendantAdded:Connect(track))
		scope:Track(workspace.DescendantRemoving:Connect(function(descendant)
			Runtime.LootPrompts[descendant] = nil
			Runtime.LootInfo[descendant] = nil
		end))
	end
	local prompts = {}
	for prompt in pairs(Runtime.LootPrompts) do
		if prompt.Parent then table.insert(prompts, prompt) end
	end
	return prompts
end

local function getGrassTargets(minimum)
	local seen, targets = {}, {}
	for _, rarity in ipairs(RARITIES) do
		if rarityAllowed(rarity, minimum) then
			for _, tagName in ipairs(RARITY_TAG_NAMES[rarity] or { rarity }) do
				for _, tagged in ipairs(CollectionService:GetTagged("Grass_" .. tagName)) do
					local target = tagged:FindFirstAncestorWhichIsA("Model") or tagged
					if not seen[target] then
						seen[target] = true
						table.insert(targets, { object = target, rarity = rarity })
					end
				end
			end
		end
	end
	return targets
end

local function nearest(entries, origin, radius)
	local best, bestDistance
	for _, entry in ipairs(entries) do
		local object = entry.object or entry
		local position = object:IsDescendantOf(workspace) and getPosition(object) or nil
		if position then
			local distance = (position - origin).Magnitude
			if distance <= radius and (not bestDistance or distance < bestDistance) then
				best, bestDistance = entry, distance
			end
		end
	end
	return best, bestDistance
end

local function clearInstances(instances)
	for instance in pairs(instances) do
		if instance.Parent then instance:Destroy() end
	end
	table.clear(instances)
end

local function addMarker(instances, object, title, color, detail, scale, options)
	if Interface then
		options = options or {}
		return Interface:AddWorldMarker(instances, object, {
			Title = title,
			Color = color,
			Detail = detail,
			Scale = scale,
			Highlight = options.Highlight,
			MaxDistance = options.MaxDistance,
		})
	end
	return nil
end

local function setOverlay(key, text)
	if Interface then Interface:SetMonitor(key, text) end
end

local function hideOverlay(key)
	if Interface then Interface:HideMonitor(key) end
end

local findShop
local sellInventory

local AutoLoot = newFeature("Auto Loot Farm", {
	Radius = 45,
	InfiniteRadius = true,
	Interval = 0.35,
	Rarities = {
		Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true,
		Mythical = true, Celestial = true, Eternal = true, Secret = true,
	},
	MinimumValuePower = 0,
	AutoMove = true,
	FlyToLoot = false,
	AutoSell = true,
	MovementMode = "Walk",
	ToggleKey = Enum.KeyCode.Unknown,
})

local function lootMatchesSettings(info, settings)
	if not settings.Rarities[info.rarity] then return false end
	local minimumValue = settings.MinimumValuePower <= 0 and 0 or 10 ^ settings.MinimumValuePower
	return (tonumber(info.value) or 0) >= minimumValue
end

function AutoLoot:OnEnable(token)
	self._attempted = {}
	self._selling = false
	self._lineOfSight = {}
	task.spawn(function()
		while self.Enabled and self._token == token do
			local _, _, root = getCharacter()
			local current, maximum, percent = readCapacity()
			local isFull = (current and maximum and current >= maximum) or (percent and percent >= 99.5)
			if isFull then
				if self.Settings.AutoSell and sellInventory and not self._selling then
					self._selling = true
					self:SetStatus(string.format("Inventory full  •  returning to base (%s / %s)", formatNumber(current), formatNumber(maximum)))
					task.spawn(function()
						local sold = sellInventory(self, self.Settings.FlyToLoot and "Fly" or self.Settings.MovementMode)
						if not sold and self.Enabled then self:SetStatus("Sell attempt failed  •  retrying") end
						task.wait(0.5)
						self._selling = false
					end)
				elseif self._selling then
					self:SetStatus(string.format("Returning to base to sell  •  %s / %s", formatNumber(current), formatNumber(maximum)))
				else
					self:SetStatus(string.format("Inventory full  •  %s / %s", formatNumber(current), formatNumber(maximum)))
				end
				task.wait(math.max(0.5, self.Settings.Interval))
				continue
			end
			if root then
				local candidates = {}
				for _, prompt in ipairs(getLootPrompts()) do
					local position = getPosition(prompt.Parent)
					local info = getLootInfo(prompt)
					if position and lootMatchesSettings(info, self.Settings)
						and (not self._attempted[prompt] or os.clock() - self._attempted[prompt] > 2) then
						local distance = (position - root.Position).Magnitude
						if self.Settings.InfiniteRadius or distance <= self.Settings.Radius then
							table.insert(candidates, { prompt = prompt, distance = distance, info = info })
						end
					end
				end
				table.sort(candidates, function(a, b)
					local aValue = tonumber(a.info.value) or 0
					local bValue = tonumber(b.info.value) or 0
					if aValue ~= bValue then return aValue > bValue end
					return a.distance < b.distance
				end)
				local candidate = candidates[1]
				local pickupDistance = candidate
					and math.max(0.75, candidate.prompt.MaxActivationDistance - 0.35) or 0
				if candidate and candidate.distance <= pickupDistance then
					self._attempted[candidate.prompt] = os.clock()
					self:SetStatus(string.format("Holding E for %s  •  $%s", candidate.info.name, formatNumber(candidate.info.value)))
					if triggerPrompt(candidate.prompt) then
						self:SetStatus(string.format("Collected %s  •  %s", candidate.info.name,
							maximum and string.format("%s / %s slots", formatNumber(current or 0), formatNumber(maximum)) or "checking capacity"))
					end
				elseif candidate and self.Settings.AutoMove then
					local mode = self.Settings.FlyToLoot and "Fly" or self.Settings.MovementMode
					if self._lineOfSight[candidate.prompt] == nil then
						self._lineOfSight[candidate.prompt] = candidate.prompt.RequiresLineOfSight
					end
					candidate.prompt.RequiresLineOfSight = false
					local destination = getPromptApproachPosition(candidate.prompt, root)
					if destination then
						navigateTo(destination, mode, self, 20, 2, {
							ExactDestination = true,
							CruiseHeight = 10,
						})
					end
					self:SetStatus(string.format("Highest value: %s  •  $%s  •  %dm",
						candidate.info.name, formatNumber(candidate.info.value), candidate.distance))
				elseif #candidates == 0 then
					self:SetStatus(percent and string.format("Watching loot  •  inventory %.0f%%", percent) or "No matching loot found")
				end
			else
				self:SetStatus("Waiting for character")
			end
			task.wait(self.Settings.Interval)
		end
	end)
end

function AutoLoot:OnDisable()
	for prompt, required in pairs(self._lineOfSight or {}) do
		if prompt.Parent then prompt.RequiresLineOfSight = required end
	end
	self._lineOfSight = nil
end

local LootESP = newFeature("Loot ESP", {
	Radius = 250,
	MaxMarkers = 30,
	RefreshRate = 0.75,
	Rarities = {
		Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true,
		Mythical = true, Celestial = true, Eternal = true, Secret = true,
	},
	NameTagSize = 1,
	Highlights = false,
	ToggleKey = Enum.KeyCode.Unknown,
})
LootESP._markers = {}

local function destroyLootMarker(marker)
	if not marker then return end
	if type(marker.handle) == "table" and marker.handle.Destroy then
		marker.handle:Destroy()
	else
		clearInstances(marker.instances or {})
	end
end

function LootESP:OnEnable(token)
	task.spawn(function()
		while self.Enabled and self._token == token do
			local _, _, root = getCharacter()
			local entries = {}
			if root then
				for _, prompt in ipairs(getLootPrompts()) do
					local object = prompt:FindFirstAncestorWhichIsA("Model") or prompt.Parent
					local position = getPosition(object)
					local info = getLootInfo(prompt)
					if position and self.Settings.Rarities[info.rarity] then
						local distance = (position - root.Position).Magnitude
						if distance <= self.Settings.Radius then
							table.insert(entries, { prompt = prompt, object = object, distance = distance, info = info })
						end
					end
				end
				table.sort(entries, function(a, b) return a.distance < b.distance end)
				local visible, visibleCount = {}, math.min(#entries, self.Settings.MaxMarkers)
				for index = 1, visibleCount do
					local entry = entries[index]
					local prompt, color = entry.prompt, RARITY_COLORS[entry.info.rarity] or Color3.fromRGB(235, 238, 244)
					local detail = string.format("%s  •  $%s  •  %dm", entry.info.rarity, formatNumber(entry.info.value), entry.distance)
					visible[prompt] = true
					local marker = self._markers[prompt]
					local styleChanged = marker and marker.highlight ~= self.Settings.Highlights
					if marker and (styleChanged or marker.object ~= entry.object or not entry.object.Parent) then
						destroyLootMarker(marker)
						self._markers[prompt] = nil
						marker = nil
					end
					if not marker then
						local instances = {}
						local handle = addMarker(instances, entry.object, entry.info.name, color, detail,
							self.Settings.NameTagSize, {
								Highlight = self.Settings.Highlights,
								MaxDistance = self.Settings.Radius + 50,
							})
						if handle then
							self._markers[prompt] = {
								handle = handle,
								instances = instances,
								object = entry.object,
								highlight = self.Settings.Highlights,
							}
						end
					elseif type(marker.handle) == "table" and marker.handle.Update then
						marker.handle:Update({
							Title = entry.info.name,
							Color = color,
							Detail = detail,
							Scale = self.Settings.NameTagSize,
							MaxDistance = self.Settings.Radius + 50,
						})
					end
				end
				for prompt, marker in pairs(self._markers) do
					if not visible[prompt] or not prompt.Parent then
						destroyLootMarker(marker)
						self._markers[prompt] = nil
					end
				end
				self:SetStatus(string.format("Showing %d cached loot marker%s", visibleCount, visibleCount == 1 and "" or "s"))
			else
				self:SetStatus("Waiting for character")
			end
			task.wait(math.max(0.35, self.Settings.RefreshRate))
		end
	end)
	return true
end

function LootESP:OnDisable()
	for prompt, marker in pairs(self._markers) do
		destroyLootMarker(marker)
		self._markers[prompt] = nil
	end
end

local SmartGrassFarm = newFeature("Smart Grass Farm", {
	SearchRadius = 350,
	AttackRange = 8,
	Interval = 0.14,
	MinimumRarity = "Uncommon",
	MovementMode = "Walk",
	ToggleKey = Enum.KeyCode.Unknown,
})

function SmartGrassFarm:OnEnable(token)
	task.spawn(function()
		local targets, refreshedAt = {}, 0
		while self.Enabled and self._token == token do
			local _, _, root = getCharacter()
			if root then
				if os.clock() - refreshedAt > 1.25 then
					targets = getGrassTargets(self.Settings.MinimumRarity)
					refreshedAt = os.clock()
				end
				local target, distance = nearest(targets, root.Position, self.Settings.SearchRadius)
				if target then
					local position = getPosition(target.object)
					self:SetStatus(string.format("Targeting %s grass  •  %dm", target.rarity, distance))
					if distance > self.Settings.AttackRange then
						navigateTo(position, self.Settings.MovementMode, self, 40, 1)
					else
						root.CFrame = CFrame.lookAt(root.Position, Vector3.new(position.X, root.Position.Y, position.Z))
						if not AutoStrengthFarm.Enabled
							and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							AutoStrengthFarm:Click()
						end
					end
				else
					self:SetStatus("No matching grass found nearby")
				end
			else
				self:SetStatus("Waiting for character")
			end
			task.wait(self.Settings.Interval)
		end
	end)
end

local ZoneNavigator = newFeature("Zone Navigator", {
	World = 1,
	Zone = 1,
	MovementMode = "Tween",
})

local function findZone(worldNumber, zoneNumber)
	local zones = workspace:FindFirstChild("Zones")
	local world = zones and (zones:FindFirstChild("W" .. tostring(worldNumber)) or zones:FindFirstChild("World_" .. tostring(worldNumber)))
	if not world then return nil end
	return world:FindFirstChild("Zone_" .. tostring(zoneNumber)) or world:FindFirstChild("Zone" .. tostring(zoneNumber))
end

local function getCurrentWorldNumber()
	local world = readNumber({ "CurrentWorld", "WorldIndex", "WorldNumber" })
	return tonumber(world)
end

local function requestWorldTravel(worldNumber, onLoaded, attempts)
	attempts = attempts or 0
	local worldsGui = playerGui:FindFirstChild("WorldsGUI")
	local targetContainer = worldsGui and worldsGui:FindFirstChild("World" .. tostring(worldNumber), true)
	local targetButton = targetContainer and (targetContainer:IsA("GuiButton") and targetContainer or targetContainer:FindFirstChildWhichIsA("GuiButton", true))
	if not targetButton then
		for _, descendant in ipairs(playerGui:GetDescendants()) do
			if descendant:IsA("GuiButton") then
				local text = descendant:IsA("TextButton") and descendant.Text or ""
				if (descendant.Name .. text):lower():gsub("[^%w]", "") == "world" .. tostring(worldNumber) then
					targetButton = descendant
					break
				end
			end
		end
	end
	if not targetButton then
		if attempts >= 2 then return false end
		activateVisibleButton({ "worlds", "world" })
		task.delay(0.35, function() requestWorldTravel(worldNumber, onLoaded, attempts + 1) end)
		return true
	end
	if not clickGuiButton(targetButton) then return false end
	task.spawn(function()
		local deadline = os.clock() + 15
		repeat
			local currentWorld = getCurrentWorldNumber()
			local loadedWithoutState = not currentWorld and workspace:FindFirstChild("Zones")
				and (workspace.Zones:FindFirstChild("W" .. tostring(worldNumber))
					or workspace.Zones:FindFirstChild("World_" .. tostring(worldNumber)))
			if currentWorld == worldNumber or loadedWithoutState then
				if onLoaded then onLoaded() end
				return
			end
			task.wait(0.35)
		until os.clock() >= deadline
	end)
	return true
end

function ZoneNavigator:Run()
	local currentWorld = getCurrentWorldNumber()
	if currentWorld and currentWorld ~= self.Settings.World then
		self:SetStatus(string.format("Travelling from World %d to World %d", currentWorld, self.Settings.World))
		return requestWorldTravel(self.Settings.World, function() self:Run() end)
	end
	local zone = findZone(self.Settings.World, self.Settings.Zone)
	if not zone then
		local zones = workspace:FindFirstChild("Zones")
		local loadedWorld = zones and (zones:FindFirstChild("W" .. tostring(self.Settings.World))
			or zones:FindFirstChild("World_" .. tostring(self.Settings.World)))
		if loadedWorld then
			self:SetStatus(string.format("Zone %d does not exist in World %d", self.Settings.Zone, self.Settings.World))
			return false
		end
		self:SetStatus(string.format("Travelling to World %d", self.Settings.World))
		return requestWorldTravel(self.Settings.World, function() self:Run() end)
	end
	local target = zone:FindFirstChild("SpawnZone", true) or zone
	local moved = navigateTo(target, self.Settings.MovementMode, self, 100, 10)
	self:SetStatus(moved and string.format("Navigating to W%d Zone %d", self.Settings.World, self.Settings.Zone)
		or "Character is not ready")
	return moved
end

local SHOP_DESTINATIONS = { "Sell", "Upgrade Shop", "Cutter Shop", "Aura Shop", "Craft Table", "OP Cutter", "Frog Shop" }
local ShopNavigator = newFeature("Shop Navigator", {
	Destination = "Sell",
	World = 1,
	MovementMode = "Tween",
	AutoOpen = true,
})

findShop = function(destination, worldNumber)
	local aliases = {
		["Sell"] = { "sell", "sellshop", "sellloot" },
		["Upgrade Shop"] = { "upgradeshop", "upgrade", "upgrades" },
		["Cutter Shop"] = { "marketcutters", "cuttershop", "cutters" },
		["Aura Shop"] = { "aurashop", "auras" },
		["Craft Table"] = { "crafttable", "crafting" },
		["OP Cutter"] = { "opcutter", "opcuttershop" },
		["Frog Shop"] = { "frogshop", "pondw" .. tostring(worldNumber or "") },
	}
	local wanted = aliases[destination] or { normalizeLootName(destination) }
	local _, _, root = getCharacter()
	local best, bestScore
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("Model") or object:IsA("Folder") or object:IsA("BasePart") then
			local normalized = normalizeLootName(object.Name)
			local matches = false
			for _, alias in ipairs(wanted) do
				if normalized == alias or (#alias >= 5 and normalized:find(alias, 1, true)) then
					matches = true
					break
				end
			end
			if matches then
				local fullName = object:GetFullName():lower()
				local score = worldNumber and (fullName:find("world_" .. worldNumber, 1, true)
					or fullName:find("w" .. worldNumber, 1, true)) and 1000 or 0
				local position = getPosition(object)
				if root and position then score -= (root.Position - position).Magnitude / 1000 end
				if not bestScore or score > bestScore then best, bestScore = object, score end
			end
		end
	end
	if not best then
		for _, prompt in ipairs(workspace:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				local descriptor = normalizeLootName(prompt.Name .. prompt.ActionText .. prompt.ObjectText .. prompt.Parent.Name)
				for _, alias in ipairs(wanted) do
					if descriptor:find(alias, 1, true) then
						best = prompt.Parent
						break
					end
				end
				if best then break end
			end
		end
	end
	return best
end

local function findCurrentBase()
	local zones = workspace:FindFirstChild("Zones")
	if not zones then return nil end
	local worldNumber = getCurrentWorldNumber() or tonumber(player:GetAttribute("CurrentWorld")) or 1
	local world = zones:FindFirstChild("W" .. tostring(worldNumber))
		or zones:FindFirstChild("World_" .. tostring(worldNumber))
	if world then
		local direct = world:FindFirstChild("Base_Zone") or world:FindFirstChild("BaseZone") or world:FindFirstChild("Base")
		if direct then return direct end
	end
	local best, bestScore
	local _, _, root = getCharacter()
	for _, object in ipairs(zones:GetDescendants()) do
		local normalized = normalizeLootName(object.Name)
		if normalized == "basezone" or normalized == "sellzone" or normalized == "spawnzone" then
			local score = object:GetFullName():lower():find("w" .. tostring(worldNumber), 1, true) and 1000 or 0
			local position = getPosition(object)
			if root and position then score -= (root.Position - position).Magnitude / 1000 end
			if not bestScore or score > bestScore then best, bestScore = object, score end
		end
	end
	return best
end

sellInventory = function(feature, movementMode)
	local startingCurrent, _, startingPercent = readCapacity()
	local sell = findShop("Sell")
	local base = findCurrentBase()
	local target = sell or base
	if not target then
		feature:SetStatus("Base and sell shop were not found in the loaded world")
		return false
	end
	local promptRoot = sell or base
	local prompt = findNamedDescendant(promptRoot, "ProximityPrompt", "ShopOpenPrompt")
		or promptRoot:FindFirstChildWhichIsA("ProximityPrompt", true)
	local deadline = os.clock() + 20
	local nextMove, lastPrompt, lastButton, clickedAt = 0, 0, 0, nil
	feature:SetStatus("Inventory full  •  returning to base to sell")
	while feature.Enabled and os.clock() < deadline do
		local now = os.clock()
		local _, _, root = getCharacter()
		local destination = prompt and getPromptApproachPosition(prompt, root) or getPosition(target)
		if destination and now >= nextMove then
			navigateTo(destination, movementMode, feature, 95, 4, {
				ExactDestination = prompt ~= nil,
				CruiseHeight = 10,
			})
			nextMove = now + 1.5
		end
		if prompt and root and prompt.Parent then
			local promptPosition = getPosition(prompt.Parent)
			local activationDistance = math.max(0.75, prompt.MaxActivationDistance - 0.35)
			if promptPosition and (root.Position - promptPosition).Magnitude <= activationDistance
				and now - lastPrompt >= 1.25 then
				lastPrompt = now
				triggerPrompt(prompt)
			end
		end
		if now - lastButton >= 0.4 then
			lastButton = now
			if activateSellAllButton() then clickedAt = clickedAt or now end
		end
		Runtime.CapacityCache = nil
		local current, _, percent = readCapacity()
		local countDropped = startingCurrent and current and current < startingCurrent
		local percentDropped = startingPercent and percent and percent < math.max(5, startingPercent - 2)
		if countDropped or percentDropped then
			feature:SetStatus(string.format("Sold loot  •  inventory %.0f%%", percent or 0))
			return true
		end
		if clickedAt and not startingPercent and now - clickedAt >= 1 then
			feature:SetStatus("Sell All activated")
			return true
		end
		task.wait(0.2)
	end
	feature:SetStatus(clickedAt and "Sell clicked, but capacity did not update" or "Reached base, but Sell All was not available")
	return clickedAt ~= nil
end

function ShopNavigator:Run()
	local currentWorld = getCurrentWorldNumber()
	if currentWorld and currentWorld ~= self.Settings.World then
		self:SetStatus(string.format("Travelling to World %d", tonumber(self.Settings.World) or 1))
		return requestWorldTravel(self.Settings.World, function() self:Run() end)
	end
	local shop = findShop(self.Settings.Destination, self.Settings.World)
	if not shop then
		self:SetStatus("That shop is not currently loaded")
		return false
	end
	local prompt = findNamedDescendant(shop, "ProximityPrompt", "ShopOpenPrompt") or shop:FindFirstChildWhichIsA("ProximityPrompt", true)
	local moved = prompt and self.Settings.AutoOpen and approachPrompt(prompt, self.Settings.MovementMode, nil, self, 100)
		or navigateTo(prompt and prompt.Parent or shop, self.Settings.MovementMode, self, 100, 10)
	self:SetStatus(moved and "Navigating to " .. self.Settings.Destination or "Character is not ready")
	return moved
end

local AutoSell = newFeature("Auto Sell Assistant", {
	Threshold = 90,
	CheckInterval = 1,
	MovementMode = "Walk",
	ToggleKey = Enum.KeyCode.Unknown,
})

function AutoSell:OnEnable(token)
	task.spawn(function()
		while self.Enabled and self._token == token do
			local current, maximum, percent = readCapacity()
			if not percent then
				self:SetStatus("Capacity data has not appeared yet")
			elseif percent >= self.Settings.Threshold then
				self:SetStatus(string.format("Returning to base  •  %.0f%% full", percent))
				sellInventory(self, self.Settings.MovementMode)
			else
				self:SetStatus(string.format("Inventory %.0f%% full  •  %s / %s", percent, formatNumber(current), formatNumber(maximum)))
			end
			task.wait(self.Settings.CheckInterval)
		end
	end)
	return true
end

local InventoryManager = newFeature("Inventory Manager", {
	ReturnThreshold = 85,
	CheckInterval = 1,
	MovementMode = "Walk",
	ToggleKey = Enum.KeyCode.Unknown,
})

function InventoryManager:OnEnable(token)
	task.spawn(function()
		while self.Enabled and self._token == token do
			local current, maximum, percent = readCapacity()
			if percent then
				if percent >= self.Settings.ReturnThreshold then
					local currentWorld = tonumber(player:GetAttribute("CurrentWorld")) or 1
					local zones = workspace:FindFirstChild("Zones")
					local world = zones and zones:FindFirstChild("W" .. tostring(currentWorld))
					local base = world and world:FindFirstChild("Base_Zone")
					if base then navigateTo(base, self.Settings.MovementMode, self, 70, 3) end
					self:SetStatus(string.format("Returning to base  •  %.0f%% full", percent))
				else
					self:SetStatus(string.format("%s / %s carried  •  %.0f%%", formatNumber(current), formatNumber(maximum), percent))
				end
			else
				self:SetStatus("Watching for inventory capacity data")
			end
			task.wait(self.Settings.CheckInterval)
		end
	end)
end

local StrengthDashboard = newFeature("Strength Dashboard", {
	UpdateInterval = 0.5,
	ShowOverlay = true,
	ToggleKey = Enum.KeyCode.Unknown,
})

function StrengthDashboard:OnEnable(token)
	task.spawn(function()
		local lastStrength, lastTime
		while self.Enabled and self._token == token do
			local strength = readNumber({ "StrengthRaw", "Strength" }) or 0
			local level = tonumber(player:GetAttribute("StrengthLevel")) or 0
			local progress = tonumber(player:GetAttribute("StrengthLevelProgressRaw")) or 0
			local requirement = tonumber(player:GetAttribute("StrengthLevelRequirementRaw")) or 0
			local now = os.clock()
			local rate = lastStrength and math.max(0, (strength - lastStrength) / math.max(0.01, now - lastTime)) or 0
			local remaining = math.max(0, requirement - progress)
			local eta = rate > 0 and remaining / rate or math.huge
			local etaText = eta < math.huge and string.format("%dm %02ds", math.floor(eta / 60), math.floor(eta % 60)) or "--"
			local text = string.format("Strength %s  •  Level %d  •  +%s/s  •  ETA %s",
				formatNumber(strength), level, formatNumber(rate), etaText)
			self:SetStatus(text)
			if self.Settings.ShowOverlay then setOverlay("Strength", text) else hideOverlay("Strength") end
			lastStrength, lastTime = strength, now
			task.wait(self.Settings.UpdateInterval)
		end
	end)
end

function StrengthDashboard:OnDisable()
	hideOverlay("Strength")
end

local ProgressDashboard = newFeature("Progress Dashboard", {
	UpdateInterval = 1,
	ShowOverlay = true,
	ToggleKey = Enum.KeyCode.Unknown,
})

function ProgressDashboard:OnEnable(token)
	task.spawn(function()
		while self.Enabled and self._token == token do
			local money = readNumber({ "MoneyRaw", "Money" }) or 0
			local rebirth = tonumber(player:GetAttribute("RebirthLevel")) or 0
			local world = tonumber(player:GetAttribute("CurrentWorld")) or 1
			local frogs = tonumber(player:GetAttribute("Frogs")) or 0
			local relics = player:GetAttribute("RelicsUnlocked") == true
			local text = string.format("Money %s  •  Rebirth %d  •  World %d  •  Frogs %d  •  Relics %s",
				formatNumber(money), rebirth, world, frogs, relics and "Unlocked" or "Locked")
			self:SetStatus(text)
			if self.Settings.ShowOverlay then setOverlay("Progress", text) else hideOverlay("Progress") end
			task.wait(self.Settings.UpdateInterval)
		end
	end)
end

function ProgressDashboard:OnDisable()
	hideOverlay("Progress")
end

local StrengthBoostMonitor = newFeature("Strength Boost Monitor", {
	UpdateInterval = 2,
	ShowOverlay = true,
	ToggleKey = Enum.KeyCode.Unknown,
})

local function summarizeBoost(state)
	if type(state) ~= "table" then return tostring(state or "No active boost") end
	local multiplier = state.Multiplier or state.multiplier or state.Boost or state.boost or 1
	local expires = state.ExpiresAt or state.expiresAt or state.EndTime or state.endTime
	local remaining = tonumber(expires) and math.max(0, tonumber(expires) - os.time()) or nil
	return remaining and string.format("Strength boost x%s  •  %dm %02ds remaining", tostring(multiplier), math.floor(remaining / 60), remaining % 60)
		or string.format("Strength boost x%s", tostring(multiplier))
end

function StrengthBoostMonitor:OnEnable(token)
	local service = findServiceFolder("StrengthBoostService")
	local getState = service and findNamedDescendant(service, "RemoteFunction", "GetState")
	local changed = service and findNamedDescendant(service, "RemoteEvent", "StateChanged")
	local announcement = service and findNamedDescendant(service, "RemoteEvent", "BoostAnnouncement")
	if changed then
		self:Track(changed.OnClientEvent:Connect(function(state)
			local text = summarizeBoost(state)
			self:SetStatus(text)
			if self.Settings.ShowOverlay then setOverlay("Boost", text) end
		end))
	end
	if announcement then
		self:Track(announcement.OnClientEvent:Connect(function(message)
			self:SetStatus(tostring(message))
		end))
	end
	task.spawn(function()
		while self.Enabled and self._token == token do
			if getState then
				local ok, state = pcall(function() return getState:InvokeServer() end)
				local text = ok and summarizeBoost(state) or "Boost state temporarily unavailable"
				self:SetStatus(text)
				if self.Settings.ShowOverlay then setOverlay("Boost", text) else hideOverlay("Boost") end
			else
				self:SetStatus("Strength boost service is not loaded")
			end
			task.wait(self.Settings.UpdateInterval)
		end
	end)
end

function StrengthBoostMonitor:OnDisable()
	hideOverlay("Boost")
end

local AFKManager = newFeature("AFK & Auto Rejoin", {
	AutoRejoin = true,
	Notifications = true,
	CheckInterval = 1,
	ToggleKey = Enum.KeyCode.Unknown,
})

function AFKManager:OnEnable(token)
	task.spawn(function()
		local notified, rejoining = false, false
		while self.Enabled and self._token == token do
			local active = player:GetAttribute("AFKActive") == true
			local rejoinAt = tonumber(player:GetAttribute("AFKRejoinAt")) or 0
			local remaining = rejoinAt > 0 and math.max(0, rejoinAt - os.time()) or 0
			if active then
				self:SetStatus(rejoinAt > 0 and string.format("AFK active  •  Rejoin in %dm %02ds", math.floor(remaining / 60), remaining % 60)
					or "AFK mode is active")
				if self.Settings.Notifications and not notified then
					notified = true
					pcall(function() StarterGui:SetCore("SendNotification", { Title = "FrostScripts", Text = "AFK mode detected", Duration = 4 }) end)
				end
				if self.Settings.AutoRejoin and rejoinAt > 0 and remaining <= 0 and not rejoining then
					rejoining = true
					pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
				end
			else
				notified = false
				self:SetStatus("Monitoring AFK and rejoin state")
			end
			task.wait(self.Settings.CheckInterval)
		end
	end)
end

local PerformanceMode = newFeature("Performance Mode", {
	Particles = true,
	Trails = true,
	Beams = true,
	ToggleKey = Enum.KeyCode.Unknown,
})
PerformanceMode._states = {}

function PerformanceMode:_optimize(instance)
	local shouldDisable = (self.Settings.Particles and instance:IsA("ParticleEmitter"))
		or (self.Settings.Trails and instance:IsA("Trail"))
		or (self.Settings.Beams and instance:IsA("Beam"))
	if shouldDisable and self._states[instance] == nil then
		self._states[instance] = instance.Enabled
		instance.Enabled = false
	end
end

function PerformanceMode:OnEnable()
	local optimized = 0
	for _, descendant in ipairs(workspace:GetDescendants()) do
		self:_optimize(descendant)
		if self._states[descendant] ~= nil then optimized += 1 end
	end
	self:SetStatus(string.format("Disabled %d expensive effects locally", optimized))
	self:Track(workspace.DescendantAdded:Connect(function(descendant)
		self:_optimize(descendant)
	end))
end

function PerformanceMode:OnDisable()
	for instance, enabled in pairs(self._states) do
		if instance.Parent then instance.Enabled = enabled end
	end
	table.clear(self._states)
	self:SetStatus("Visual effects restored")
end

function PerformanceMode:OnSettingChanged()
	if self.Enabled then
		task.defer(function()
			if self.Enabled then
				self:Disable()
				self:Enable()
			end
		end)
	end
end

local UpgradeAssistant = newFeature("Upgrade Assistant", {
	Notifications = true,
	UpdateInterval = 1.5,
	MovementMode = "Tween",
	ToggleKey = Enum.KeyCode.Unknown,
})

function UpgradeAssistant:OpenShop()
	local shop = findShop("Upgrade Shop")
	if not shop then
		self:SetStatus("Upgrade shop is not loaded")
		return false
	end
	local prompt = findNamedDescendant(shop, "ProximityPrompt", "ShopOpenPrompt")
	navigateTo(prompt and prompt.Parent or shop, self.Settings.MovementMode, self, 100, 10)
	self:SetStatus("Navigating to Upgrade Shop")
	return true
end

function UpgradeAssistant:OnEnable(token)
	local service = findServiceFolder("UpgradesService")
	if not service then
		self:SetStatus("Upgrade service is not loaded")
		return true
	end
	local watched = 0
	for _, remote in ipairs(service:GetDescendants()) do
		if remote:IsA("RemoteEvent") and (remote.Name:find("Updated") or remote.Name == "UpgradeAll" or remote.Name == "NotEnoughMoney") then
			watched += 1
			self:Track(remote.OnClientEvent:Connect(function(...)
				local text = remote.Name:gsub("UpgradeUpdated", " upgraded"):gsub("Updated", " updated")
				self:SetStatus(text)
				if self.Settings.Notifications then
					pcall(function() StarterGui:SetCore("SendNotification", { Title = "Upgrade Assistant", Text = text, Duration = 3 }) end)
				end
			end))
		end
	end
	self:SetStatus(string.format("Monitoring %d upgrade signal%s", watched, watched == 1 and "" or "s"))
	task.spawn(function()
		while self.Enabled and self._token == token do
			local affordable, total, money = scanUpgradeAffordability()
			if total > 0 then
				self:SetStatus(string.format("%d / %d visible upgrades affordable  •  Money %s", affordable, total, formatNumber(money)))
			end
			task.wait(self.Settings.UpdateInterval)
		end
	end)
	return true
end

-- UI binding only. All construction and control behavior lives in UI.lua.

local Library = API.LoadUI()
Interface = Library.new({
	TextScope = "GrassCutter",
	Name = "FrostScripts",
	Game = "Grass Cutter",
	GuiName = "GrassCutterUI",
	OverlayName = "FrostScriptsGrassCutterOverlays",
})
Runtime.MainGui = Interface:GetRoot()

local Home = Interface:AddTab("Home", "H", "Overview and quick access")
local Modules = Interface:AddTab("Modules", "M", "Configure automation and utility modules")
local Settings = Interface:AddTab("UI Settings", "S", "Appearance, motion, and sound")
Home:SetDashboardLayout()

local welcome = Home:AddModule({
	Name = "Welcome back",
	Description = "15 modules ready",
	Accent = true,
	Collapsible = false,
	HeaderHeight = 56,
})
welcome:AddParagraph(
	"Grass Cutter suite",
	"A complete automation and utility suite for Grass Cutter. Open Modules to configure farming, navigation, ESP, dashboards, and performance.",
	{ Height = 66 }
)

local quickAccess = Home:AddModule({
	Name = "Quick access",
	Description = "Common actions without leaving the overview",
	Collapsible = false,
	Expanded = true,
})
quickAccess:AddButton("Open Modules", function() Interface:SelectTab(Modules) end)
quickAccess:AddButton("Customize interface", function() Interface:SelectTab(Settings) end)

local moduleControls = {}

local function addFeatureModule(feature, options)
	options = options or {}
	local module
	module = Modules:AddModule({
		Name = options.Name or feature.Name,
		Description = options.Description or feature.Status,
		Feature = feature,
		Toggleable = options.Toggleable ~= false,
		Default = feature.Enabled,
		Callback = function(enabled)
			local changed = feature:SetEnabled(enabled)
			if enabled and changed == false then
				module.Toggle:SetValue(false, true)
				module:SetStatus("Your character is not ready yet.")
			end
		end,
	})
	moduleControls[feature] = module
	if options.Toggleable ~= false then
		feature:AddSetting("ToggleKey", Enum.KeyCode.Unknown)
		module:AddKeybind({ Name = "Toggle " .. feature.Name,
			Get = function() return feature.Settings.ToggleKey end,
			Set = function(key) feature:SetSetting("ToggleKey", key) end,
			OnPressed = function() feature:SetEnabled(not feature.Enabled) end })
	end
	return module
end

local function addSlider(module, feature, label, key, minimum, maximum, step, formatter, description)
	return module:AddSlider(label, minimum, maximum, feature.Settings[key], function(value)
		feature:SetSetting(key, value)
	end, {
		Step = step,
		Formatter = formatter,
		Description = description,
	})
end

local function addDropdown(module, feature, label, key, options)
	return module:AddDropdown(label, options, feature.Settings[key], function(value)
		feature:SetSetting(key, value)
	end)
end

local function addMultiDropdown(module, feature, label, key, options, colors)
	return module:AddMultiDropdown(label, options, feature.Settings[key], function(selected)
		feature:SetSetting(key, selected)
	end, colors)
end

local ON_OFF = {
	{ Label = "On", Value = true },
	{ Label = "Off", Value = false },
}
local MOVEMENT_MODES = { "Walk", "Fly", "Tween", "Teleport" }

local flyModule = addFeatureModule(Fly, {
	Name = "Fly",
	Description = "WASD move   |   Space up   |   LeftCtrl down",
})
addSlider(flyModule, Fly, "Flight speed", "Speed", 10, 150, 5, nil, "Horizontal movement speed")
addSlider(flyModule, Fly, "Vertical speed", "VerticalSpeed", 10, 150, 5, nil, "Ascending and descending speed")

local strengthFarmModule = addFeatureModule(AutoStrengthFarm, {
	Name = "Auto Strength Farm",
	Description = "Game click system   |   Manual clicks stay available",
})
addSlider(strengthFarmModule, AutoStrengthFarm, "Clicks per second", "ClicksPerSecond", 1, 25, 1)

local autoLootModule = addFeatureModule(AutoLoot)
addDropdown(autoLootModule, AutoLoot, "Collection range", "InfiniteRadius", {
	{ Label = "Infinite", Value = true },
	{ Label = "Use radius", Value = false },
})
addSlider(autoLootModule, AutoLoot, "Collection radius", "Radius", 10, 1000, 10)
addSlider(autoLootModule, AutoLoot, "Collection interval", "Interval", 0.1, 1, 0.05)
addMultiDropdown(autoLootModule, AutoLoot, "Accepted rarities", "Rarities", RARITIES, RARITY_COLORS)
addSlider(autoLootModule, AutoLoot, "Minimum loot money", "MinimumValuePower", 0, 15, 1, function(value)
	return value <= 0 and "Any" or "$" .. formatNumber(10 ^ value)
end)
addDropdown(autoLootModule, AutoLoot, "Move to distant loot", "AutoMove", ON_OFF)
addDropdown(autoLootModule, AutoLoot, "Fly above obstacles", "FlyToLoot", ON_OFF)
addDropdown(autoLootModule, AutoLoot, "Auto sell when full", "AutoSell", ON_OFF)
addDropdown(autoLootModule, AutoLoot, "Movement mode", "MovementMode", MOVEMENT_MODES)

local lootESPModule = addFeatureModule(LootESP)
addSlider(lootESPModule, LootESP, "Display radius", "Radius", 50, 600, 25)
addSlider(lootESPModule, LootESP, "Maximum markers", "MaxMarkers", 5, 60, 5)
addSlider(lootESPModule, LootESP, "Refresh interval", "RefreshRate", 0.35, 2, 0.05, function(value)
	return string.format("%.2fs", value)
end)
addMultiDropdown(lootESPModule, LootESP, "Visible rarities", "Rarities", RARITIES, RARITY_COLORS)
addSlider(lootESPModule, LootESP, "Nametag size", "NameTagSize", 0.7, 1.8, 0.1)
addDropdown(lootESPModule, LootESP, "Object glow", "Highlights", ON_OFF)

local grassModule = addFeatureModule(SmartGrassFarm)
addSlider(grassModule, SmartGrassFarm, "Search radius", "SearchRadius", 50, 800, 25)
addSlider(grassModule, SmartGrassFarm, "Attack range", "AttackRange", 4, 30, 1)
addDropdown(grassModule, SmartGrassFarm, "Minimum rarity", "MinimumRarity", RARITIES)
addDropdown(grassModule, SmartGrassFarm, "Movement mode", "MovementMode", MOVEMENT_MODES)

local autoSellModule = addFeatureModule(AutoSell)
addSlider(autoSellModule, AutoSell, "Sell threshold", "Threshold", 25, 100, 5)
addSlider(autoSellModule, AutoSell, "Check interval", "CheckInterval", 0.5, 5, 0.5)
addDropdown(autoSellModule, AutoSell, "Movement mode", "MovementMode", MOVEMENT_MODES)

local zoneModule = addFeatureModule(ZoneNavigator, { Toggleable = false })
addSlider(zoneModule, ZoneNavigator, "World", "World", 1, 5, 1)
addSlider(zoneModule, ZoneNavigator, "Zone", "Zone", 1, 13, 1)
addDropdown(zoneModule, ZoneNavigator, "Movement mode", "MovementMode", MOVEMENT_MODES)
zoneModule:AddButton("Navigate to zone", function() ZoneNavigator:Run() end)

local shopModule = addFeatureModule(ShopNavigator, { Toggleable = false })
addDropdown(shopModule, ShopNavigator, "Destination", "Destination", SHOP_DESTINATIONS)
addSlider(shopModule, ShopNavigator, "World", "World", 1, 5, 1)
addDropdown(shopModule, ShopNavigator, "Movement mode", "MovementMode", MOVEMENT_MODES)
addDropdown(shopModule, ShopNavigator, "Open shop on arrival", "AutoOpen", ON_OFF)
shopModule:AddButton("Navigate to shop", function() ShopNavigator:Run() end)

local strengthModule = addFeatureModule(StrengthDashboard)
addSlider(strengthModule, StrengthDashboard, "Update interval", "UpdateInterval", 0.25, 3, 0.25)
addDropdown(strengthModule, StrengthDashboard, "Overlay", "ShowOverlay", ON_OFF)

local progressModule = addFeatureModule(ProgressDashboard)
addSlider(progressModule, ProgressDashboard, "Update interval", "UpdateInterval", 0.5, 5, 0.5)
addDropdown(progressModule, ProgressDashboard, "Overlay", "ShowOverlay", ON_OFF)

local boostModule = addFeatureModule(StrengthBoostMonitor)
addSlider(boostModule, StrengthBoostMonitor, "Update interval", "UpdateInterval", 1, 10, 1)
addDropdown(boostModule, StrengthBoostMonitor, "Overlay", "ShowOverlay", ON_OFF)

local afkModule = addFeatureModule(AFKManager)
addDropdown(afkModule, AFKManager, "Automatic rejoin", "AutoRejoin", ON_OFF)
addDropdown(afkModule, AFKManager, "Notifications", "Notifications", ON_OFF)
addSlider(afkModule, AFKManager, "Check interval", "CheckInterval", 0.5, 5, 0.5)

local performanceModule = addFeatureModule(PerformanceMode)
addDropdown(performanceModule, PerformanceMode, "Particles", "Particles", ON_OFF)
addDropdown(performanceModule, PerformanceMode, "Trails", "Trails", ON_OFF)
addDropdown(performanceModule, PerformanceMode, "Beams", "Beams", ON_OFF)

local upgradeModule = addFeatureModule(UpgradeAssistant)
addDropdown(upgradeModule, UpgradeAssistant, "Notifications", "Notifications", ON_OFF)
addSlider(upgradeModule, UpgradeAssistant, "Affordability refresh", "UpdateInterval", 0.5, 5, 0.5)
addDropdown(upgradeModule, UpgradeAssistant, "Movement mode", "MovementMode", MOVEMENT_MODES)
upgradeModule:AddButton("Open Upgrade Shop", function() UpgradeAssistant:OpenShop() end)

local inventoryModule = addFeatureModule(InventoryManager)
addSlider(inventoryModule, InventoryManager, "Return threshold", "ReturnThreshold", 25, 100, 5)
addSlider(inventoryModule, InventoryManager, "Check interval", "CheckInterval", 0.5, 5, 0.5)
addDropdown(inventoryModule, InventoryManager, "Movement mode", "MovementMode", MOVEMENT_MODES)

local TOGGLE_FEATURES = {
	AutoLoot,
	LootESP,
	SmartGrassFarm,
	AutoSell,
	InventoryManager,
	StrengthDashboard,
	ProgressDashboard,
	StrengthBoostMonitor,
	AFKManager,
	PerformanceMode,
	UpgradeAssistant,
}

Interface:AddClientSettings(Settings)

local safety = Home:AddModule({
	Name = "Emergency stop",
	Description = "Disable every running module immediately",
	Collapsible = false,
})
safety:AddButton("STOP ALL", function()
	Fly:SetEnabled(false)
	AutoStrengthFarm:SetEnabled(false)
	for _, feature in ipairs(TOGGLE_FEATURES) do feature:SetEnabled(false) end
	Runtime.NavigationSerial += 1
	Runtime.NavigationOwner, Runtime.NavigationPriority, Runtime.NavigationExpires = nil, 0, 0
	if Runtime.MoveTween then
		Runtime.MoveTween:Cancel()
		Runtime.MoveTween = nil
	end
	local _, humanoid, root = getCharacter()
	if humanoid and root then humanoid:MoveTo(root.Position) end
	Interface:Notify({ Title = "Emergency stop", Text = "All running modules were disabled." })
end, { Danger = true })

local diagnostics = Modules:AddModule({
	Name = "Game compatibility",
	Description = "Run an in-game scan after the world finishes loading.",
	Collapsible = false,
})
local diagnosticsText = diagnostics:AddParagraph(
	"Discovery status",
	"Loot —  |  Grass —  |  Sell —  |  Capacity —  |  Boost —",
	{ Height = 80 }
)
diagnostics:AddButton("RUN SCAN", function()
	local lootCount = #getLootPrompts()
	local grassCount = 0
	for _, rarity in ipairs(RARITIES) do
		grassCount += #CollectionService:GetTagged("Grass_" .. rarity)
	end
	local sellReady = findShop("Sell") ~= nil
	local capacityReady = readCapacity() ~= nil
	local boostReady = findServiceFolder("StrengthBoostService") ~= nil
	diagnosticsText:SetText(string.format(
		"Loot %d  |  Grass %d  |  Sell %s  |  Capacity %s  |  Boost %s",
		lootCount,
		grassCount,
		sellReady and "OK" or "Missing",
		capacityReady and "OK" or "Waiting",
		boostReady and "OK" or "Missing"
	))
	diagnosticsText:SetColor(lootCount > 0 and grassCount > 0
		and Library.Theme.Success or Library.Theme.Muted)
end)

Interface:SelectTab(Home)

local Suite = { Interface = Interface, Runtime = Runtime, Features = TOGGLE_FEATURES }
function Suite:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	Fly:Destroy()
	AutoStrengthFarm:Destroy()
	for _, feature in ipairs(TOGGLE_FEATURES) do feature:Destroy() end
	Runtime.NavigationSerial += 1
	if Runtime.MoveTween then Runtime.MoveTween:Cancel() end
	scope:Destroy()
	local _, humanoid, root = getCharacter()
	if humanoid and root then humanoid:MoveTo(root.Position) end
	Interface:Destroy()
	if env.FrostScriptsGrassCutter == self then env.FrostScriptsGrassCutter = nil end
end
env.FrostScriptsGrassCutter = Suite
safety:AddButton("Unload FrostScripts", function() Suite:Unload() end, { Danger = true })
return Suite
