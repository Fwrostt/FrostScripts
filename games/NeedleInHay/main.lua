-- Game-specific entry; invoked by FrostScriptsAPI.RunGame.
local API = ...
assert(type(API) == "table" and type(API.CreateFeature) == "function", "Launch this game through its dist/launchers entry point")

-- FrostScripts - NeedleInHay

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")


local player = Players.LocalPlayer
local env = (type(getgenv) == "function" and getgenv()) or _G

if env.FrostScriptsNeedleInHay and type(env.FrostScriptsNeedleInHay.Unload) == "function" then
	pcall(function() env.FrostScriptsNeedleInHay:Unload() end)
end

local NeedleHaystack = ReplicatedStorage:WaitForChild("NeedleHaystack", 20)
assert(NeedleHaystack, "NeedleHaystack folder was not found in ReplicatedStorage.")

local ConfigModule = NeedleHaystack:FindFirstChild("Config")
local GameConfig = {}
if ConfigModule then
	pcall(function()
		GameConfig = require(ConfigModule)
	end)
end

local Remotes = {
	PickHay = NeedleHaystack:WaitForChild("PickHay", 20),
	PickDroppedHay = NeedleHaystack:WaitForChild("PickDroppedHay", 20),
	DropHay = NeedleHaystack:FindFirstChild("DropHay"),
	HeldToolState = NeedleHaystack:FindFirstChild("HeldToolState"),
	PitchforkDig = NeedleHaystack:FindFirstChild("PitchforkDig"),
	TntExploded = NeedleHaystack:FindFirstChild("TntExploded"),
	PitchforkDug = NeedleHaystack:FindFirstChild("PitchforkDug"),
	DroneHarvested = NeedleHaystack:FindFirstChild("DroneHarvested"),
	VacuumHarvested = NeedleHaystack:FindFirstChild("VacuumHarvested"),
	GetHayState = NeedleHaystack:WaitForChild("GetHayState", 20),
	SellHay = NeedleHaystack:WaitForChild("SellHay", 20),
	HaySold = NeedleHaystack:FindFirstChild("HaySold"),
	BuyUpgrade = NeedleHaystack:FindFirstChild("BuyUpgrade"),
	UpgradeChanged = NeedleHaystack:FindFirstChild("UpgradeChanged"),
	NeedleTargetChanged = NeedleHaystack:FindFirstChild("NeedleTargetChanged"),
	NeedleFound = NeedleHaystack:FindFirstChild("NeedleFound"),
	NeedleRoundCompleted = NeedleHaystack:FindFirstChild("NeedleRoundCompleted"),
}

assert(Remotes.PickHay, "PickHay remote was not found.")
assert(Remotes.PickDroppedHay, "PickDroppedHay remote was not found.")
assert(Remotes.GetHayState, "GetHayState remote was not found.")
assert(Remotes.SellHay, "SellHay remote was not found.")

local Client = {
	StatusMonitor = true,
	MarkerColor = "Amber",
	NeedleColor = "Cyan",
	SellColor = "Green",
}

local PALETTE = {
	Amber = Color3.fromRGB(255, 192, 82),
	Cyan = Color3.fromRGB(82, 211, 255),
	Green = Color3.fromRGB(85, 222, 145),
	Purple = Color3.fromRGB(122, 118, 255),
	Red = Color3.fromRGB(255, 92, 112),
	White = Color3.fromRGB(242, 245, 252),
}

local RGB_TARGETS = {
	Cyan = Color3.fromRGB(0, 255, 255),
	Green = Color3.fromRGB(0, 255, 0),
	Yellow = Color3.fromRGB(255, 255, 0),
	Red = Color3.fromRGB(255, 0, 0),
	Blue = Color3.fromRGB(0, 90, 255),
	Magenta = Color3.fromRGB(255, 0, 255),
	White = Color3.fromRGB(255, 255, 255),
}

local RGB_OPTIONS = { "Cyan", "Green", "Yellow", "Red", "Blue", "Magenta", "White" }

local Runtime = {
	Active = true,
	Interface = nil,
	Connections = {},
	Features = {},
	Controls = {},
	LastState = nil,
	LastStateAt = 0,
	LastPickAt = 0,
	LastDroppedAt = 0,
	LastSellAt = 0,
	LastDropAt = 0,
	LastPitchforkAt = 0,
	LastNeedleAt = 0,
	LastUiAt = 0,
	PendingHay = {},
	HayCache = {},
	DroppedCache = {},
	SellCache = {},
	NeedleObjectiveCache = nil,
	LastHayCacheAt = 0,
	LastDroppedCacheAt = 0,
	LastSellCacheAt = 0,
	LastNeedleCacheAt = 0,
	HayScanCursor = 1,
	DroppedScanCursor = 1,
	Highlights = {},
	Markers = {},
	MoveTween = nil,
	NavigationOwner = nil,
	NavigationPriority = 0,
	NavigationExpires = 0,
	NavigationSerial = 0,
	GrabOverlapParams = nil,
	ToolStateLastTool = nil,
	ToolStateLastPhase = nil,
	ToolStateNextTool = nil,
	ToolStateNextPhase = nil,
	ToolStateQueued = false,
	NeedleTarget = nil,
	EventCounters = {
		Tnt = 0,
		Pitchfork = 0,
		Drone = 0,
		Vacuum = 0,
		Sold = 0,
		Needles = 0,
		Rounds = 0,
	},
	Status = "Loaded",
	Stats = {
		Picked = 0,
		Dropped = 0,
		Sold = 0,
		DroppedHeld = 0,
		PitchforkDigs = 0,
		NeedleAttempts = 0,
	},
}

local function track(connection)
	if connection then
		table.insert(Runtime.Connections, connection)
	end
	return connection
end

local function notify(title, text, kind)
	if Runtime.Interface then
		Runtime.Interface:Notify({
			Title = title,
			Text = text,
			Type = kind,
			Duration = 4,
		})
		return
	end

	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 4,
		})
	end)
end


local getCharacter = API.GetCharacter

local getPosition = API.GetPosition

local distanceToPlayer = API.DistanceToPlayer

local formatNumber = API.FormatNumber

local formatDistance = API.FormatDistance

local function colorDistance(left, right)
	return math.sqrt(
		((left.R - right.R) * 255) ^ 2
		+ ((left.G - right.G) * 255) ^ 2
		+ ((left.B - right.B) * 255) ^ 2
	)
end

local function closestRgbName(color)
	local bestName, bestDistance
	for name, targetColor in pairs(RGB_TARGETS) do
		local distance = colorDistance(color, targetColor)
		if not bestDistance or distance < bestDistance then
			bestName, bestDistance = name, distance
		end
	end
	return bestName, bestDistance or math.huge
end

local function colorSaturation(color)
	local high = math.max(color.R, color.G, color.B)
	local low = math.min(color.R, color.G, color.B)
	return high - low
end

local function selectedColorSet(selection)
	local set = {}
	if type(selection) ~= "table" then return set end
	for key, value in pairs(selection) do
		if type(key) == "number" then
			set[value] = true
		elseif value == true then
			set[key] = true
		end
	end
	return set
end

local function hayMatchesColor(part, settings)
	settings = settings or {}
	if not (part and part:IsA("BasePart")) then
		return false, nil, math.huge
	end
	local colorName, distance = closestRgbName(part.Color)
	local tolerance = tonumber(settings.ColorTolerance) or 72
	local selected = selectedColorSet(settings.TargetColors)
	local selectedAny = false
	for _ in pairs(selected) do
		selectedAny = true
		break
	end
	local accepted = (not selectedAny or selected[colorName]) and distance <= tolerance
	return accepted, colorName, distance
end

local function hayHeld()
	return tonumber(player:GetAttribute("HayHeld")) or 0
end

local function vacuumLoad()
	return tonumber(player:GetAttribute("VacuumLoad")) or 0
end

local function hayCapacity()
	return tonumber(player:GetAttribute("HayCapacity")) or 25
end

local function hasHeldHay()
	return hayHeld() > 0 or vacuumLoad() > 0
end

local function bagFull()
	local capacity = hayCapacity()
	return capacity > 0 and hayHeld() >= capacity
end

local getHayFolder

local function canPick()
	local cooldown = tonumber(player:GetAttribute("HayPickCooldown")) or GameConfig.PICK_COOLDOWN or 0.12
	return os.clock() - Runtime.LastPickAt >= cooldown
end

local function inputLocked()
	return player:GetAttribute("NeedleInputLocked") == true
		or player:GetAttribute("HoveredShopItem") ~= nil
		or UserInputService:GetFocusedTextBox() ~= nil
end

local function distanceFromPointToPart(point, part)
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -halfSize.X, halfSize.X),
		math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
	)
	return (part.CFrame:PointToWorldSpace(clamped) - point).Magnitude
end

local function getGrabOverlapParams()
	local folder = getHayFolder()
	if not Runtime.GrabOverlapParams then
		Runtime.GrabOverlapParams = OverlapParams.new()
		Runtime.GrabOverlapParams.FilterType = Enum.RaycastFilterType.Include
	end
	Runtime.GrabOverlapParams.FilterDescendantsInstances = folder and { folder } or {}
	return Runtime.GrabOverlapParams
end

local function getGrabCandidates(part, settings)
	settings = settings or {}
	if not (part and part.Parent and workspace.GetPartBoundsInRadius) then
		return {}
	end

	local grabCount = tonumber(player:GetAttribute("HayGrabCount")) or 1
	local grabRadius = tonumber(player:GetAttribute("HayGrabRadius")) or 0
	if grabCount <= 1 or grabRadius <= 0 then
		return {}
	end

	local origin = part.Position
	local candidates = {}
	for _, nearby in ipairs(workspace:GetPartBoundsInRadius(origin, grabRadius, getGrabOverlapParams())) do
		local hayId = nearby:GetAttribute("HayId")
		local rgbMatch = hayMatchesColor(nearby, settings)
		if hayId and nearby ~= part and nearby.Parent == getHayFolder() and not Runtime.PendingHay[hayId]
			and (not settings.RgbOnly or rgbMatch) then
			local distance = distanceFromPointToPart(origin, nearby)
			if distance <= grabRadius then
				table.insert(candidates, {
					id = hayId,
					distance = distance,
				})
			end
		end
	end

	table.sort(candidates, function(left, right)
		if left.distance == right.distance then
			return tostring(left.id) < tostring(right.id)
		end
		return left.distance < right.distance
	end)

	local extraIds = {}
	for index = 1, math.min(grabCount - 1, #candidates) do
		table.insert(extraIds, candidates[index].id)
	end
	return extraIds
end

function getHayFolder()
	return workspace:FindFirstChild("HaystackClient")
end

local function getDroppedFolder()
	return workspace:FindFirstChild("DroppedHay")
end

local function getNeedleServer()
	return workspace:FindFirstChild("NeedleObjectiveServer")
end

local function collectParts(folder, matcher)
	local parts = {}
	if not folder then return parts end
	for _, object in ipairs(folder:GetDescendants()) do
		if object:IsA("BasePart") and matcher(object) then
			table.insert(parts, object)
		end
	end
	return parts
end

local function compactCache(cache, matcher)
	local writeIndex = 1
	for readIndex = 1, #cache do
		local object = cache[readIndex]
		if object and object.Parent and object:IsDescendantOf(workspace) and matcher(object) then
			cache[writeIndex] = object
			writeIndex += 1
		end
	end
	for index = writeIndex, #cache do
		cache[index] = nil
	end
	return cache
end

local function getHayCache(force)
	local now = os.clock()
	if force or now - Runtime.LastHayCacheAt > 5 then
		Runtime.HayCache = collectParts(getHayFolder(), function(object)
			return object:GetAttribute("HayId") ~= nil
		end)
		Runtime.LastHayCacheAt = now
	end
	return Runtime.HayCache
end

local function getDroppedCache(force)
	local now = os.clock()
	if force or now - Runtime.LastDroppedCacheAt > 5 then
		Runtime.DroppedCache = collectParts(getDroppedFolder(), function(object)
			return object:GetAttribute("IsDroppedHay") == true
		end)
		Runtime.LastDroppedCacheAt = now
	end
	return Runtime.DroppedCache
end

local function getHayState(force)
	if not force and Runtime.LastState and os.clock() - Runtime.LastStateAt < 1.5 then
		return Runtime.LastState
	end

	local ok, state = pcall(function()
		return Remotes.GetHayState:InvokeServer()
	end)

	if ok and type(state) == "table" then
		Runtime.LastState = state
		Runtime.LastStateAt = os.clock()
		return state
	end

	return Runtime.LastState
end

local function setStatus(text)
	local nextStatus = tostring(text or "")
	if Runtime.Status == nextStatus then return end
	Runtime.Status = nextStatus
end

local function getHayCandidates(range, settings)
	settings = settings or {}
	range = tonumber(range) or math.huge
	local folder = getHayFolder()
	local candidates = {}
	if not folder then return candidates end
	local _, _, root = getCharacter()
	if not root then return candidates end
	local rootPosition = root.Position

	local cache = getHayCache(false)
	local scanBudget = math.clamp(math.floor(tonumber(settings.ScanBudget) or 450), 50, math.max(50, #cache))
	local scanned = 0
	while scanned < scanBudget and scanned < #cache do
		local index = Runtime.HayScanCursor
		local object = cache[index]
		Runtime.HayScanCursor = index >= #cache and 1 or index + 1
		scanned += 1
		local hayId = object and object:GetAttribute("HayId")
		if object and object.Parent and hayId and not Runtime.PendingHay[hayId] then
			local distance = (rootPosition - object.Position).Magnitude
			local rgbMatch, rgbName, rgbDistance = hayMatchesColor(object, settings)
			if distance <= range and (not settings.RgbOnly or rgbMatch) then
				table.insert(candidates, {
					id = hayId,
					part = object,
					distance = distance,
					rgbMatch = rgbMatch,
					rgbName = rgbName,
					rgbDistance = rgbDistance,
					saturation = colorSaturation(object.Color),
				})
			end
		end
	end

	table.sort(candidates, function(left, right)
		local mode = settings.Priority or "Nearest"
		if mode == "RGB first" and left.rgbMatch ~= right.rgbMatch then
			return left.rgbMatch
		end
		if mode == "Priority color" then
			local preferred = settings.PriorityColor or "Cyan"
			local leftPreferred = left.rgbName == preferred
			local rightPreferred = right.rgbName == preferred
			if leftPreferred ~= rightPreferred then
				return leftPreferred
			end
		elseif mode == "Most colorful" and left.saturation ~= right.saturation then
			return left.saturation > right.saturation
		elseif mode == "Farthest" and left.distance ~= right.distance then
			return left.distance > right.distance
		end
		return left.distance < right.distance
	end)

	return candidates
end

local function getDroppedCandidates(range, settings)
	settings = settings or {}
	range = tonumber(range) or math.huge
	local folder = getDroppedFolder()
	local candidates = {}
	if not folder then return candidates end
	local _, _, root = getCharacter()
	if not root then return candidates end
	local rootPosition = root.Position

	local cache = getDroppedCache(false)
	local scanBudget = math.clamp(math.floor(tonumber(settings.ScanBudget) or 250), 25, math.max(25, #cache))
	local scanned = 0
	while scanned < scanBudget and scanned < #cache do
		local index = Runtime.DroppedScanCursor
		local object = cache[index]
		Runtime.DroppedScanCursor = index >= #cache and 1 or index + 1
		scanned += 1
		if object and object.Parent then
			local distance = (rootPosition - object.Position).Magnitude
			if distance <= range then
				table.insert(candidates, {
					part = object,
					distance = distance,
				})
			end
		end
	end

	table.sort(candidates, function(left, right)
		return left.distance < right.distance
	end)

	return candidates
end

local function getNeedleObjective()
	local now = os.clock()
	if Runtime.NeedleObjectiveCache and Runtime.NeedleObjectiveCache.Parent
		and Runtime.NeedleObjectiveCache:IsDescendantOf(workspace)
		and now - Runtime.LastNeedleCacheAt < 1.5 then
		return Runtime.NeedleObjectiveCache
	end

	local server = getNeedleServer()
	if server then
		for _, object in ipairs(server:GetDescendants()) do
			if object:IsA("BasePart") and object:GetAttribute("IsNeedleObjective") then
				Runtime.NeedleObjectiveCache = object
				Runtime.LastNeedleCacheAt = now
				return object
			end
		end
		if server:IsA("BasePart") or server:IsA("Model") then
			Runtime.NeedleObjectiveCache = server
			Runtime.LastNeedleCacheAt = now
			return server
		end
	end

	for _, folderName in ipairs({ "HiddenNeedleClient", "HaystackClient" }) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			local source = folderName == "HaystackClient" and getHayCache(false) or folder:GetDescendants()
			for _, object in ipairs(source) do
				if object:IsA("BasePart") and object:GetAttribute("IsNeedleObjective") then
					Runtime.NeedleObjectiveCache = object
					Runtime.LastNeedleCacheAt = now
					return object
				end
			end
		end
	end

	Runtime.NeedleObjectiveCache = nil
	Runtime.LastNeedleCacheAt = now
	return nil
end

local function refreshSellParts()
	local parts = {}
	local tag = GameConfig.SELL_PART_NAME
	if type(tag) == "string" then
		for _, object in ipairs(CollectionService:GetTagged(tag)) do
			if object:IsA("BasePart") and object:IsDescendantOf(workspace) then
				table.insert(parts, object)
			end
		end
	end

	if #parts == 0 then
		local sellModel = workspace:FindFirstChild("SellModel", true)
		if sellModel then
			for _, object in ipairs(sellModel:GetDescendants()) do
				if object:IsA("BasePart") then
					table.insert(parts, object)
				end
			end
		end
	end

	return parts
end

local function getSellParts()
	local now = os.clock()
	if now - Runtime.LastSellCacheAt > 3 then
		Runtime.SellCache = refreshSellParts()
		Runtime.LastSellCacheAt = now
	else
		compactCache(Runtime.SellCache, function()
			return true
		end)
	end

	table.sort(Runtime.SellCache, function(left, right)
		return distanceToPlayer(left) < distanceToPlayer(right)
	end)

	return Runtime.SellCache
end

local function stopNavigation(owner)
	if owner and Runtime.NavigationOwner ~= owner then return end
	Runtime.NavigationSerial += 1
	Runtime.NavigationOwner = nil
	Runtime.NavigationPriority = 0
	Runtime.NavigationExpires = 0
	if Runtime.MoveTween then
		Runtime.MoveTween:Cancel()
		Runtime.MoveTween = nil
	end
	local _, humanoid, root = getCharacter()
	if humanoid and root then
		pcall(function() humanoid:MoveTo(root.Position) end)
	end
end

local function navigateTo(target, mode, owner, priority, holdSeconds, options)
	options = options or {}
	local position = typeof(target) == "Vector3" and target or getPosition(target)
	local _, humanoid, root = getCharacter()
	if not position or not humanoid or not root then return false, "Character not ready" end

	local now = os.clock()
	priority = priority or 50
	if Runtime.NavigationOwner and Runtime.NavigationOwner ~= owner and now < Runtime.NavigationExpires
		and priority < Runtime.NavigationPriority then
		return false, "Navigation reserved"
	end

	local destination = position + Vector3.new(0, tonumber(options.HeightOffset) or 3, 0)
	local arrivalDistance = tonumber(options.ArrivalDistance) or 8
	local distance = (root.Position - destination).Magnitude
	if distance <= arrivalDistance then
		return true, "Arrived"
	end

	Runtime.NavigationOwner = owner
	Runtime.NavigationPriority = priority
	Runtime.NavigationExpires = now + math.max(holdSeconds or 1, distance / 80 + 1)
	Runtime.NavigationSerial += 1
	local serial = Runtime.NavigationSerial
	if Runtime.MoveTween then
		Runtime.MoveTween:Cancel()
		Runtime.MoveTween = nil
	end

	if mode == "Teleport" then
		root.CFrame = CFrame.new(destination, destination + root.CFrame.LookVector)
	elseif mode == "Tween" then
		local speed = tonumber(options.Speed) or 85
		local duration = math.clamp(distance / math.max(1, speed), 0.08, 4)
		Runtime.MoveTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(destination, destination + root.CFrame.LookVector),
		})
		Runtime.MoveTween:Play()
		task.delay(duration + 0.05, function()
			if Runtime.NavigationSerial == serial then
				Runtime.MoveTween = nil
			end
		end)
	else
		humanoid:MoveTo(destination)
	end

	return true, "Moving " .. formatDistance(distance)
end

local playPickupFeedback

local function requestPickHay(hayId, sourcePart, options)
	options = options or {}
	if not hayId or not canPick() then return false end
	if options.RespectInputLocks and inputLocked() then return false end

	Runtime.LastPickAt = os.clock()
	Runtime.PendingHay[hayId] = true
	local extraIds = options.MultiGrab and getGrabCandidates(sourcePart, options) or {}
	for _, extraId in ipairs(extraIds) do
		Runtime.PendingHay[extraId] = true
	end
	Runtime.Stats.Picked += 1
	Remotes.PickHay:FireServer(hayId, extraIds)
	if options.PickupEffects then
		playPickupFeedback(sourcePart)
	end

	task.delay(1, function()
		Runtime.PendingHay[hayId] = nil
		for _, extraId in ipairs(extraIds) do
			Runtime.PendingHay[extraId] = nil
		end
	end)

	return true
end

local function requestPickDropped(part)
	if not part or not part.Parent then return false end
	Runtime.LastDroppedAt = os.clock()
	Runtime.Stats.Dropped += 1
	Remotes.PickDroppedHay:FireServer(part)
	return true
end

local function setHeldToolState(toolName, phase)
	if not Remotes.HeldToolState then return false end
	Runtime.ToolStateNextTool = toolName
	Runtime.ToolStateNextPhase = toolName and (phase or "idle") or nil
	if Runtime.ToolStateQueued then return true end

	Runtime.ToolStateQueued = true
	task.defer(function()
		Runtime.ToolStateQueued = false
		if Runtime.ToolStateNextTool ~= Runtime.ToolStateLastTool
			or Runtime.ToolStateNextPhase ~= Runtime.ToolStateLastPhase then
			Runtime.ToolStateLastTool = Runtime.ToolStateNextTool
			Runtime.ToolStateLastPhase = Runtime.ToolStateNextPhase
			Remotes.HeldToolState:FireServer(Runtime.ToolStateNextTool, Runtime.ToolStateNextPhase)
		end
	end)
	return true
end

local function clearHeldToolState(toolName)
	if Runtime.ToolStateNextTool == toolName or Runtime.ToolStateLastTool == toolName then
		return setHeldToolState(nil, nil)
	end
	return false
end

local function canUsePitchfork()
	if not Remotes.PitchforkDig then return false end
	local owned = player:GetAttribute("PitchforkOwned")
	return owned ~= false
end

local function requestPitchforkDig(hayId, sourcePart, options)
	options = options or {}
	if not hayId then return false, "No hay id" end
	if not Remotes.PitchforkDig then return false, "PitchforkDig remote missing" end
	if options.RespectInputLocks and inputLocked() then return false, "Input locked" end
	if player:GetAttribute("PitchforkOwned") == false then return false, "Pitchfork not owned" end

	local cooldown = tonumber(options.PitchforkInterval) or 0.08
	if os.clock() - Runtime.LastPitchforkAt < cooldown then
		return false, "Pitchfork cooldown"
	end

	Runtime.LastPitchforkAt = os.clock()
	Runtime.PendingHay[hayId] = true
	Runtime.Stats.PitchforkDigs += 1

	setHeldToolState("Pitchfork", "windup")
	task.delay(tonumber(options.WindupTime) or 0.025, function()
		if Runtime.PendingHay[hayId] then
			setHeldToolState("Pitchfork", "strike")
			Remotes.PitchforkDig:FireServer(hayId)
			if options.PickupEffects then
				playPickupFeedback(sourcePart)
			end
		end
	end)
	task.delay(tonumber(options.LiftTime) or 0.07, function()
		if Runtime.PendingHay[hayId] then
			setHeldToolState("Pitchfork", "lift")
		end
	end)
	task.delay(tonumber(options.IdleTime) or 0.12, function()
		if Runtime.PendingHay[hayId] then
			setHeldToolState("Pitchfork", "idle")
		end
	end)
	task.delay(0.9, function()
		Runtime.PendingHay[hayId] = nil
	end)

	return true, "PitchforkDig fired"
end

local function requestHarvest(candidate, settings)
	settings = settings or {}
	if not candidate then return false, "No hay candidate" end
	local method = settings.Method or "Best tool"
	if method == "Pitchfork" then
		return requestPitchforkDig(candidate.id, candidate.part, settings)
	elseif method == "Best tool" and canUsePitchfork() then
		return requestPitchforkDig(candidate.id, candidate.part, settings)
	end

	local ok = requestPickHay(candidate.id, candidate.part, {
		MultiGrab = settings.MultiGrab,
		RespectInputLocks = settings.RespectInputLocks,
		PickupEffects = settings.PickupEffects,
		RgbOnly = settings.RgbOnly,
		TargetColors = settings.TargetColors,
		ColorTolerance = settings.ColorTolerance,
	})
	return ok, ok and "PickHay fired" or "PickHay blocked"
end

local function requestNeedle()
	Runtime.LastNeedleAt = os.clock()
	Runtime.Stats.NeedleAttempts += 1
	Remotes.PickHay:FireServer("Objective")
	return true
end

local function requestSell()
	if os.clock() - Runtime.LastSellAt < 0.2 then return false end
	Runtime.LastSellAt = os.clock()
	Runtime.Stats.Sold += 1
	Remotes.SellHay:FireServer()
	return true
end

local function requestDropHeld(settings)
	settings = settings or {}
	if not Remotes.DropHay then return false, "DropHay remote missing" end
	if not hasHeldHay() then return false, "No held hay" end
	if os.clock() - Runtime.LastDropAt < (tonumber(settings.Interval) or 0.6) then
		return false, "Drop cooldown"
	end

	local _, _, root = getCharacter()
	local camera = workspace.CurrentCamera
	if not root then return false, "Character not ready" end

	local charge = math.clamp(tonumber(settings.Charge) or 0.65, 0, 1)
	local minSpeed = tonumber(GameConfig.MIN_THROW_SPEED) or 36
	local maxSpeed = tonumber(GameConfig.MAX_THROW_SPEED) or 90
	local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local velocity = look * (minSpeed + (maxSpeed - minSpeed) * charge ^ 1.3)
		+ Vector3.new(0, (tonumber(settings.UpBoost) or 4) * charge, 0)

	Runtime.LastDropAt = os.clock()
	Runtime.Stats.DroppedHeld += 1
	Remotes.DropHay:FireServer(root.CFrame, velocity, {})
	return true
end

local getUpgradeCandidates

local function runDiagnostics()
	local hayFolder = getHayFolder()
	local droppedFolder = getDroppedFolder()
	local state = getHayState(true)
	local hayCount = hayFolder and #getHayCache(true) or 0
	local droppedCount = droppedFolder and #getDroppedCache(true) or 0
	local sellCount = #getSellParts()
	local needleReady = getNeedleObjective() ~= nil
	local active = state and type(state.activeIds) == "table" and #state.activeIds or 0
	local upgradeCount = #getUpgradeCandidates({ Priority = "Cheapest" })

	return string.format(
		"Hay %s | Active %s | Dropped %s | Sell %s | Needle %s | Drop %s | Pitchfork %s | Upgrades %s",
		formatNumber(hayCount),
		formatNumber(active),
		formatNumber(droppedCount),
		formatNumber(sellCount),
		needleReady and "visible" or "hidden",
		Remotes.DropHay and "ready" or "missing",
		Remotes.PitchforkDig and "ready" or "missing",
		Remotes.BuyUpgrade and formatNumber(upgradeCount) .. " affordable" or "missing"
	)
end

local UPGRADE_UNLOCK_ATTRIBUTES = {
	TntLuck = "TntOwned",
	TntCooldown = "TntOwned",
	TntPower = "TntOwned",
	PitchforkCooldown = "PitchforkOwned",
	PitchforkHold = "PitchforkOwned",
	Pitchfork = "PitchforkOwned",
	DroneSpeed = "DroneOwned",
	DroneGrab = "DroneOwned",
	DroneCapacity = "DroneOwned",
	VacuumPower = "VacuumOwned",
	VacuumCooling = "VacuumOwned",
	VacuumRuntime = "VacuumOwned",
}

local function getCash()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return tonumber(cash and cash.Value) or 0
end

local function getUpgradeTracks()
	if type(GameConfig.UPGRADE_ORDER) == "table" and #GameConfig.UPGRADE_ORDER > 0 then
		return GameConfig.UPGRADE_ORDER
	end
	return {
		"Grab",
		"Capacity",
		"Speed",
		"HandHold",
		"TntLuck",
		"TntCooldown",
		"TntPower",
		"PitchforkCooldown",
		"PitchforkHold",
		"Pitchfork",
		"DroneSpeed",
		"DroneGrab",
		"DroneCapacity",
		"VacuumPower",
		"VacuumCooling",
		"VacuumRuntime",
	}
end

local function isUpgradeUnlocked(track)
	local attribute = UPGRADE_UNLOCK_ATTRIBUTES[track]
	return not attribute or player:GetAttribute(attribute) == true
end

local function getUpgradeInfo(track)
	local tracks = GameConfig.UPGRADE_TRACKS
	local config = type(tracks) == "table" and tracks[track]
	if type(config) ~= "table" or type(config.Levels) ~= "table" then
		return nil
	end
	local level = math.clamp(tonumber(player:GetAttribute("HayUpgrade" .. track)) or 1, 1, #config.Levels)
	local current = config.Levels[level]
	local nextLevel = config.Levels[level + 1]
	local cost = nextLevel and tonumber(nextLevel.Cost) or nil
	if cost and track:sub(1, 9) == "Pitchfork" then
		cost = math.round(cost * (tonumber(player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1) * 100) / 100
	end
	return {
		Track = track,
		DisplayName = config.DisplayName or track,
		Level = level,
		Current = current,
		Next = nextLevel,
		Cost = cost,
		Unlocked = isUpgradeUnlocked(track),
		Maxed = nextLevel == nil,
	}
end

function getUpgradeCandidates(settings)
	settings = settings or {}
	local candidates = {}
	local cash = getCash()
	for _, track in ipairs(getUpgradeTracks()) do
		local info = getUpgradeInfo(track)
		if info and info.Unlocked and not info.Maxed and info.Cost and info.Cost <= cash then
			table.insert(candidates, info)
		end
	end
	table.sort(candidates, function(left, right)
		local mode = settings.Priority or "Grab first"
		if mode == "Cheapest" and left.Cost ~= right.Cost then
			return left.Cost < right.Cost
		elseif mode == "Highest level" and left.Level ~= right.Level then
			return left.Level > right.Level
		elseif mode == "Capacity first" then
			local leftPreferred = left.Track == "Capacity"
			local rightPreferred = right.Track == "Capacity"
			if leftPreferred ~= rightPreferred then return leftPreferred end
		elseif mode == "Grab first" then
			local leftPreferred = left.Track == "Grab"
			local rightPreferred = right.Track == "Grab"
			if leftPreferred ~= rightPreferred then return leftPreferred end
		end
		if left.Cost == right.Cost then
			return left.Track < right.Track
		end
		return left.Cost < right.Cost
	end)
	return candidates
end

local function buyUpgrade(track)
	if not Remotes.BuyUpgrade then
		return false, "BuyUpgrade remote missing"
	end
	local info = getUpgradeInfo(track)
	if not info then return false, "Unknown upgrade track" end
	if not info.Unlocked then return false, "Upgrade locked" end
	if info.Maxed then return false, "Upgrade maxed" end
	if info.Cost and getCash() < info.Cost then
		return false, "Need " .. formatNumber(info.Cost - getCash()) .. " more cash"
	end
	Remotes.BuyUpgrade:FireServer(track)
	return true, "Buying " .. info.DisplayName
end

local function clearVisuals()
	for object in pairs(Runtime.Highlights) do
		if object and object.Parent then
			object:Destroy()
		end
	end
	for object in pairs(Runtime.Markers) do
		if object and object.Parent then
			object:Destroy()
		end
	end
	table.clear(Runtime.Highlights)
	table.clear(Runtime.Markers)
end

local function colorFor(name)
	return PALETTE[name] or PALETTE.Amber
end

function playPickupFeedback(part)
	if not (part and part.Parent and part:IsA("BasePart")) then return end

	local burst = Instance.new("Attachment")
	burst.Name = "NeedleInHayPickupBurst"
	burst.Parent = part

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(part.Color, Color3.fromRGB(255, 238, 151))
	particles.LightEmission = 0.7
	particles.Lifetime = NumberRange.new(0.18, 0.34)
	particles.Speed = NumberRange.new(0.8, 2.3)
	particles.Drag = 3
	particles.Acceleration = Vector3.new(0, 2.5, 0)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rate = 0
	particles.Rotation = NumberRange.new(-180, 180)
	particles.RotSpeed = NumberRange.new(-140, 140)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = burst
	particles:Emit(7)
	Debris:AddItem(burst, 0.55)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NeedleInHayPickupPlusOne"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(86, 46)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0.32, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "+1"
	label.TextColor3 = Color3.fromRGB(255, 237, 145)
	label.TextStrokeColor3 = Color3.fromRGB(62, 37, 16)
	label.TextStrokeTransparency = 0.1
	label.TextSize = 28
	label.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(billboard, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 0.95, 0),
	}):Play()
	task.delay(0.28, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.25), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)
	Debris:AddItem(billboard, 0.62)
end

local function addHighlight(adornee, color)
	if not adornee then return end
	local highlight = Instance.new("Highlight")
	highlight.Name = "NeedleInHayHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0.12
	highlight.Adornee = adornee
	highlight.Parent = Runtime.Interface and Runtime.Interface:GetRoot() or workspace
	Runtime.Highlights[highlight] = true
end

local function addWorldMarker(adornee, title, detail, color)
	if not Runtime.Interface or not adornee then return end
	Runtime.Interface:AddWorldMarker(Runtime.Markers, adornee, {
		Title = title,
		Detail = detail,
		Color = color,
		Width = 190,
		Height = 46,
		Scale = 0.9,
		Compact = true,
		MaxDistance = 2500,
		Offset = Vector3.new(0, 3, 0),
	})
end

local function newFeature(name, settings)
	local feature = API.CreateFeature(name, settings)
	feature:AddSetting("ToggleKey", name == "Assist Mode" and Enum.KeyCode.B or Enum.KeyCode.Unknown)
	table.insert(Runtime.Features, feature)
	return feature
end

local AutoPick = newFeature("Harvest Controller", {
	Method = "Best tool",
	PickRange = 40,
	SearchRange = 500,
	ScanBudget = 450,
	DroppedScanBudget = 160,
	PerCycle = 1,
	Interval = 0.24,
	PitchforkInterval = 0.12,
	WindupTime = 0.025,
	LiftTime = 0.07,
	IdleTime = 0.12,
	PauseWhenFull = true,
	CollectDropped = true,
	DroppedRange = 55,
	DroppedPerCycle = 3,
	MultiGrab = true,
	RespectInputLocks = true,
	PickupEffects = false,
	RgbOnly = false,
	TargetColors = {
		Cyan = true,
		Green = true,
		Yellow = true,
	},
	ColorTolerance = 72,
	Priority = "RGB first",
	PriorityColor = "Cyan",
	AutoMove = true,
	MovementMode = "Tween",
	MoveStopDistance = 32,
})

function AutoPick:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.Interval

	if self.Settings.PauseWhenFull and bagFull() then
		self:SetStatus("Bag full. Waiting for sell.")
		return
	end

	local picked = 0
	local candidates = getHayCandidates(self.Settings.SearchRange, self.Settings)
	local nearest = candidates[1]
	if nearest and self.Settings.AutoMove and nearest.distance > self.Settings.MoveStopDistance then
		local ok, reason = navigateTo(nearest.part, self.Settings.MovementMode, self, 70, 1.2, {
			ArrivalDistance = self.Settings.MoveStopDistance,
			HeightOffset = 3,
		})
		self:SetStatus(ok and ("Moving to " .. (nearest.rgbName or "hay") .. " hay") or reason)
		return
	end

	for _, candidate in ipairs(candidates) do
		if picked >= self.Settings.PerCycle then break end
		if candidate.distance > self.Settings.PickRange then break end
		if requestHarvest(candidate, self.Settings) then
			picked += 1
		end
	end

	local dropped = 0
	if self.Settings.CollectDropped then
		for _, candidate in ipairs(getDroppedCandidates(self.Settings.DroppedRange, {
			ScanBudget = self.Settings.DroppedScanBudget,
		})) do
			if dropped >= self.Settings.DroppedPerCycle then break end
			if requestPickDropped(candidate.part) then
				dropped += 1
			end
		end
	end

	if picked > 0 or dropped > 0 then
		self:SetStatus(string.format("Hay %s | Dropped %s", picked, dropped))
	elseif nearest then
		self:SetStatus("Nearest target: " .. formatDistance(nearest.distance))
	else
		self:SetStatus(self.Settings.RgbOnly and "No matching RGB hay" or "No hay found")
	end
end

function AutoPick:OnDisable()
	stopNavigation(self)
	clearHeldToolState("Pitchfork")
end

local AutoSell = newFeature("Haul & Sell", {
	Mode = "When full",
	Interval = 0.65,
	AutoMove = true,
	MovementMode = "Tween",
	NearDistance = 24,
})

function AutoSell:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.Interval

	local shouldSell = false
	if self.Settings.Mode == "Any hay" then
		shouldSell = hasHeldHay()
	elseif self.Settings.Mode == "When full" then
		shouldSell = bagFull()
	end

	if not shouldSell then
		self:SetStatus("Waiting for sell condition")
		return
	end

	local nearest = getSellParts()[1]
	if not nearest then
		self:SetStatus("No sell location found")
		return
	end

	local distance = distanceToPlayer(nearest)
	if distance > self.Settings.NearDistance then
		if self.Settings.AutoMove then
			local ok, reason = navigateTo(nearest, self.Settings.MovementMode, self, 80, 1.5, {
				ArrivalDistance = self.Settings.NearDistance,
				HeightOffset = 3,
			})
			self:SetStatus(ok and ("Moving to sell: " .. formatDistance(distance)) or reason)
			return
		end
		self:SetStatus("Sell is " .. formatDistance(distance) .. " away")
		return
	end

	if requestSell() then
		self:SetStatus("SellHay fired")
	end
end

function AutoSell:OnDisable()
	stopNavigation(self)
end

local AutoDrop = newFeature("Throw Assist", {
	Mode = "When full",
	Interval = 1.25,
	Charge = 0.65,
	UpBoost = 4,
	OnlyAwayFromSell = true,
	SellDistance = 28,
})

function AutoDrop:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.Interval

	if not Remotes.DropHay then
		self:SetStatus("DropHay remote is missing")
		return
	end

	local shouldDrop = false
	if self.Settings.Mode == "Any hay" then
		shouldDrop = hasHeldHay()
	elseif self.Settings.Mode == "When full" then
		shouldDrop = bagFull()
	end

	if not shouldDrop then
		self:SetStatus("Waiting for drop condition")
		return
	end

	if self.Settings.OnlyAwayFromSell then
		local nearest = getSellParts()[1]
		if nearest and distanceToPlayer(nearest) <= self.Settings.SellDistance then
			self:SetStatus("Near sell. Holding hay.")
			return
		end
	end

	local ok, reason = requestDropHeld(self.Settings)
	self:SetStatus(ok and "DropHay fired" or reason)
end

local NeedleClaim = newFeature("Needle Objective", {
	Interval = 0.9,
	RequireVisibleObjective = true,
	MaxDistance = 60,
})

function NeedleClaim:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.Interval

	local objective = getNeedleObjective()
	if self.Settings.RequireVisibleObjective then
		if not objective then
			self:SetStatus("Objective not visible")
			return
		end
		if distanceToPlayer(objective) > self.Settings.MaxDistance then
			self:SetStatus("Needle too far")
			return
		end
	end

	if requestNeedle() then
		self:SetStatus("PickHay Objective fired")
	end
end

local GameEvents = newFeature("Game Event Watch", {
	ShowNotifications = true,
	ShowOverlay = true,
	UpdateInterval = 2,
})

local function eventSummary()
	return string.format(
		"TNT %s | Pitchfork %s | Drone %s | Vacuum %s | Sold %s | Needles %s | Rounds %s",
		formatNumber(Runtime.EventCounters.Tnt),
		formatNumber(Runtime.EventCounters.Pitchfork),
		formatNumber(Runtime.EventCounters.Drone),
		formatNumber(Runtime.EventCounters.Vacuum),
		formatNumber(Runtime.EventCounters.Sold),
		formatNumber(Runtime.EventCounters.Needles),
		formatNumber(Runtime.EventCounters.Rounds)
	)
end

local function pushEventStatus(feature, title, text)
	feature:SetStatus(text)
	setStatus(text)
	if feature.Settings.ShowNotifications then
		notify(title, text, "Success")
	end
	if feature.Settings.ShowOverlay and Runtime.Interface then
		Runtime.Interface:SetMonitor("NeedleInHayEvents", eventSummary())
	end
end

function GameEvents:OnEnable()
	if Remotes.TntExploded then
		self:Track(Remotes.TntExploded.OnClientEvent:Connect(function()
			Runtime.EventCounters.Tnt += 1
			pushEventStatus(self, "FrostScripts", "TNT exploded")
		end))
	end
	if Remotes.PitchforkDug then
		self:Track(Remotes.PitchforkDug.OnClientEvent:Connect(function()
			Runtime.EventCounters.Pitchfork += 1
			pushEventStatus(self, "FrostScripts", "Pitchfork dug")
		end))
	end
	if Remotes.DroneHarvested then
		self:Track(Remotes.DroneHarvested.OnClientEvent:Connect(function()
			Runtime.EventCounters.Drone += 1
			pushEventStatus(self, "FrostScripts", "Drone harvested hay")
		end))
	end
	if Remotes.VacuumHarvested then
		self:Track(Remotes.VacuumHarvested.OnClientEvent:Connect(function()
			Runtime.EventCounters.Vacuum += 1
			pushEventStatus(self, "FrostScripts", "Vacuum harvested hay")
		end))
	end
	if Remotes.NeedleTargetChanged then
		self:Track(Remotes.NeedleTargetChanged.OnClientEvent:Connect(function(target)
			Runtime.NeedleTarget = target
			pushEventStatus(self, "FrostScripts", "Needle target changed")
		end))
	end
	self:SetStatus(eventSummary())
	return true
end

function GameEvents:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.UpdateInterval
	local summary = eventSummary()
	self:SetStatus(summary)
	if self.Settings.ShowOverlay and Runtime.Interface then
		Runtime.Interface:SetMonitor("NeedleInHayEvents", summary)
	end
end

function GameEvents:OnDisable()
	if Runtime.Interface then
		Runtime.Interface:HideMonitor("NeedleInHayEvents")
	end
end

local UpgradeManager = newFeature("Upgrade Manager", {
	Mode = "Best affordable",
	SelectedTrack = "Grab",
	Priority = "Grab first",
	Interval = 2.5,
	Notify = true,
})

function UpgradeManager:BuySelected()
	local ok, message = buyUpgrade(self.Settings.SelectedTrack)
	self:SetStatus(message)
	if self.Settings.Notify then
		notify("FrostScripts Upgrades", message, ok and "Success" or "Error")
	end
	return ok
end

function UpgradeManager:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.Interval

	if not Remotes.BuyUpgrade then
		self:SetStatus("BuyUpgrade remote missing")
		return
	end

	if self.Settings.Mode == "Selected only" then
		local info = getUpgradeInfo(self.Settings.SelectedTrack)
		if not info then
			self:SetStatus("Unknown selected upgrade")
		elseif info.Maxed then
			self:SetStatus(info.DisplayName .. " maxed")
		elseif not info.Unlocked then
			self:SetStatus(info.DisplayName .. " locked")
		elseif info.Cost and getCash() >= info.Cost then
			self:BuySelected()
		else
			self:SetStatus(info.DisplayName .. " needs " .. formatNumber((info.Cost or 0) - getCash()))
		end
		return
	end

	local candidate = getUpgradeCandidates(self.Settings)[1]
	if not candidate then
		self:SetStatus("No affordable upgrades")
		return
	end
	local ok, message = buyUpgrade(candidate.Track)
	self:SetStatus(message)
	if self.Settings.Notify then
		notify("FrostScripts Upgrades", message, ok and "Success" or "Error")
	end
end

local AssistMode = newFeature("Assist Mode", {
	AutoPick = true,
	AutoSell = true,
	AutoDrop = false,
	NeedleClaim = true,
	GameEvents = true,
	UpgradeManager = false,
})

function AssistMode.OnStateChanged(enabled)
	local self = AssistMode
	if self.Settings.AutoPick then AutoPick:SetEnabled(enabled) end
	if self.Settings.AutoSell then AutoSell:SetEnabled(enabled) end
	if self.Settings.AutoDrop then AutoDrop:SetEnabled(enabled) end
	if self.Settings.NeedleClaim then NeedleClaim:SetEnabled(enabled) end
	if self.Settings.GameEvents then GameEvents:SetEnabled(enabled) end
	if self.Settings.UpgradeManager then UpgradeManager:SetEnabled(enabled) end
	self:SetStatus(enabled and "Assist modules enabled" or "Assist modules disabled")
end

local Visuals = newFeature("ESP Markers", {
	Hay = true,
	Dropped = true,
	Needle = true,
	Sell = true,
	Range = 2500,
	ScanBudget = 220,
	MaxHayMarkers = 15,
	Interval = 2.5,
})

function Visuals:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.Interval
	clearVisuals()

	local marked = 0

	if self.Settings.Hay then
		for _, candidate in ipairs(getHayCandidates(self.Settings.Range, {
			ScanBudget = self.Settings.ScanBudget,
		})) do
			if marked >= self.Settings.MaxHayMarkers then break end
			addWorldMarker(candidate.part, "Hay", formatDistance(candidate.distance), colorFor(Client.MarkerColor))
			marked += 1
		end
	end

	if self.Settings.Dropped then
		for _, candidate in ipairs(getDroppedCandidates(self.Settings.Range, {
			ScanBudget = math.max(25, math.floor(self.Settings.ScanBudget * 0.5)),
		})) do
			addWorldMarker(candidate.part, "Dropped Hay", formatDistance(candidate.distance), colorFor(Client.MarkerColor))
		end
	end

	if self.Settings.Needle then
		local objective = getNeedleObjective()
		if objective then
			addHighlight(objective, colorFor(Client.NeedleColor))
			addWorldMarker(objective, "Needle", "Objective", colorFor(Client.NeedleColor))
		end
	end

	if self.Settings.Sell then
		for _, part in ipairs(getSellParts()) do
			addHighlight(part, colorFor(Client.SellColor))
			addWorldMarker(part, "Sell", formatDistance(distanceToPlayer(part)), colorFor(Client.SellColor))
		end
	end

	self:SetStatus("Visuals refreshed")
end

function Visuals.OnStateChanged(enabled)
	if not enabled then
		clearVisuals()
	end
end

local PerformanceMode = newFeature("Performance Mode", {
	Particles = true,
	Trails = true,
	Beams = true,
	ScanPerStep = 350,
})
PerformanceMode._states = {}

function PerformanceMode:_optimize(object)
	local shouldDisable = (self.Settings.Particles and object:IsA("ParticleEmitter"))
		or (self.Settings.Trails and object:IsA("Trail"))
		or (self.Settings.Beams and object:IsA("Beam"))
	if shouldDisable and self._states[object] == nil then
		self._states[object] = object.Enabled
		object.Enabled = false
	end
end

function PerformanceMode:OnEnable()
	local token = self._token
	task.spawn(function()
		local optimized = 0
		local objects = workspace:GetDescendants()
		local perStep = math.clamp(math.floor(tonumber(self.Settings.ScanPerStep) or 350), 50, 2000)
		for index, object in ipairs(objects) do
			if not self.Enabled or self._token ~= token then return end
			self:_optimize(object)
			if self._states[object] ~= nil then
				optimized += 1
			end
			if index % perStep == 0 then
				self:SetStatus("Optimizing effects: " .. formatNumber(index) .. "/" .. formatNumber(#objects))
				task.wait()
			end
		end
		if self.Enabled and self._token == token then
			self:SetStatus("Disabled " .. formatNumber(optimized) .. " local effects")
		end
	end)
	self:Track(workspace.DescendantAdded:Connect(function(object)
		self:_optimize(object)
	end))
	self:SetStatus("Optimizing effects")
	return true
end

function PerformanceMode:OnDisable()
	for object, enabled in pairs(self._states) do
		if object and object.Parent then
			object.Enabled = enabled
		end
	end
	table.clear(self._states)
	self:SetStatus("Effects restored")
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

local RoundState = newFeature("Round Monitor", {
	Interval = 2.5,
})

function RoundState:Tick(now)
	if now < self.NextRun then return end
	self.NextRun = now + self.Settings.Interval

	local state = getHayState(true)
	if not state then
		self:SetStatus("GetHayState failed")
		return
	end

	local active = type(state.activeIds) == "table" and #state.activeIds or 0
	local remaining = state.remaining or GameConfig.TOTAL_HAY or 0
	local needle = state.needleHayId and tostring(state.needleHayId) or "hidden"
	self:SetStatus(string.format("Active %s | Remaining %s | Needle %s", formatNumber(active), formatNumber(remaining), needle))
end

local Diagnostics = newFeature("Diagnostics", {})

local function addFeatureModule(tab, feature, options)
	options = options or {}
	local module = tab:AddModule({
		Name = options.Name or feature.Name,
		Description = options.Description or feature.Status,
		Accent = options.Accent == true,
		Toggleable = options.Toggleable ~= false,
		Default = feature.Enabled,
		Callback = function(enabled)
			feature:SetEnabled(enabled)
		end,
	})
	Runtime.Controls[feature] = module
	feature:BindControl(module)
	if options.Toggleable ~= false then
		module:AddKeybind({ Name = "Toggle " .. feature.Name,
			Get = function() return feature.Settings.ToggleKey end,
			Set = function(key) feature:SetSetting("ToggleKey", key) end,
			OnPressed = function() feature:SetEnabled(not feature.Enabled) end })
	end
	return module
end

local function addSlider(module, feature, label, key, min, max, step, formatter)
	return module:AddSlider(label, min, max, feature.Settings[key], function(value)
		feature:SetSetting(key, value)
	end, {
		Step = step,
		Formatter = formatter,
	})
end

local function addDropdown(module, feature, label, key, options)
	return module:AddDropdown(label, options, feature.Settings[key], function(value)
		feature:SetSetting(key, value)
	end)
end

local function addMultiDropdown(module, feature, label, key, options, colors)
	return module:AddMultiDropdown(label, options, feature.Settings[key], function(value)
		feature:SetSetting(key, value)
	end, colors)
end

local ON_OFF = {
	{ Label = "On", Value = true },
	{ Label = "Off", Value = false },
}

local MOVEMENT_MODES = { "Walk", "Tween", "Teleport" }
local HARVEST_METHODS = { "Best tool", "Pitchfork", "Hand" }
local HARVEST_PRIORITIES = { "Nearest", "RGB first", "Priority color", "Most colorful", "Farthest" }
local UPGRADE_PRIORITIES = { "Grab first", "Capacity first", "Cheapest", "Highest level" }

local Library = API.LoadUI()
local Interface = Library.new({
	Name = "FrostScripts",
	Game = "NeedleInHay",
	GuiName = "FrostScriptsNeedleInHayUI",
	OverlayName = "FrostScriptsNeedleInHayOverlays",
})

Runtime.Interface = Interface

local UniversalFlight = API.UniversalModules
	and API.UniversalModules.CreateFlight({
		Name = "Flight",
		Speed = 70,
		VerticalSpeed = 50,
		IsInputCaptured = function() return Interface:IsCapturingInput() end,
	})
local AutoClicker = API.UniversalModules
	and API.UniversalModules.CreateAutoClicker({
		Name = "Auto Clicker",
		ClicksPerSecond = 8,
		IsInputCaptured = function() return Interface:IsCapturingInput() end,
	})
if UniversalFlight then table.insert(Runtime.Features, UniversalFlight) end
if AutoClicker then table.insert(Runtime.Features, AutoClicker) end

local Home = Interface:AddTab("Home", "H", "FrostScripts NeedleInHay")
local Modules = Interface:AddTab("Modules", "M", "Game modules")
local Settings = Interface:AddTab("UI Settings", "S", "Appearance, motion, and sound")

local overview = Home:AddModule({
	Name = "FrostScripts NeedleInHay",
	Description = "Pick, sell, needle claim, and visuals",
	Accent = true,
	Collapsible = false,
})

local overviewText = overview:AddParagraph("Status", "Ready", { Height = 112 })

local assistModule = addFeatureModule(Modules, AssistMode, {
	Description = "One toggle for the main FrostScripts automation set",
	Accent = true,
})
assistModule:AddDropdown("Auto pick", ON_OFF, AssistMode.Settings.AutoPick, function(value)
	AssistMode:SetSetting("AutoPick", value)
end)
assistModule:AddDropdown("Auto sell", ON_OFF, AssistMode.Settings.AutoSell, function(value)
	AssistMode:SetSetting("AutoSell", value)
end)
assistModule:AddDropdown("Needle claim", ON_OFF, AssistMode.Settings.NeedleClaim, function(value)
	AssistMode:SetSetting("NeedleClaim", value)
end)
assistModule:AddDropdown("Game events", ON_OFF, AssistMode.Settings.GameEvents, function(value)
	AssistMode:SetSetting("GameEvents", value)
end)
assistModule:AddDropdown("Upgrades", ON_OFF, AssistMode.Settings.UpgradeManager, function(value)
	AssistMode:SetSetting("UpgradeManager", value)
end)

local pickModule = addFeatureModule(Modules, AutoPick, {
	Description = "Moves, filters RGB strands, collects hay, and grabs drops",
})
addSlider(pickModule, AutoPick, "Pick range", "PickRange", 5, 250, 5, function(value)
	return tostring(value) .. " studs"
end)
addSlider(pickModule, AutoPick, "Search range", "SearchRange", 50, 2500, 50, function(value)
	return tostring(value) .. " studs"
end)
addSlider(pickModule, AutoPick, "Hay scan budget", "ScanBudget", 50, 1600, 50)
addSlider(pickModule, AutoPick, "Picks per cycle", "PerCycle", 1, 8, 1)
addSlider(pickModule, AutoPick, "Pick interval", "Interval", 0.08, 1.5, 0.02, function(value)
	return string.format("%.2fs", value)
end)
addDropdown(pickModule, AutoPick, "Harvest method", "Method", HARVEST_METHODS)
addSlider(pickModule, AutoPick, "Pitchfork interval", "PitchforkInterval", 0.03, 0.5, 0.01, function(value)
	return string.format("%.2fs", value)
end)
addDropdown(pickModule, AutoPick, "Pause when full", "PauseWhenFull", ON_OFF)
addDropdown(pickModule, AutoPick, "Auto move", "AutoMove", ON_OFF)
addDropdown(pickModule, AutoPick, "Movement", "MovementMode", MOVEMENT_MODES)
addSlider(pickModule, AutoPick, "Move stop distance", "MoveStopDistance", 8, 120, 2, function(value)
	return tostring(value) .. " studs"
end)
addDropdown(pickModule, AutoPick, "Multi-grab bonus", "MultiGrab", ON_OFF)
addDropdown(pickModule, AutoPick, "Respect input locks", "RespectInputLocks", ON_OFF)
addDropdown(pickModule, AutoPick, "Pickup effects", "PickupEffects", ON_OFF)
addDropdown(pickModule, AutoPick, "RGB only", "RgbOnly", ON_OFF)
addMultiDropdown(pickModule, AutoPick, "RGB targets", "TargetColors", RGB_OPTIONS, RGB_TARGETS)
addSlider(pickModule, AutoPick, "RGB tolerance", "ColorTolerance", 10, 160, 1)
addDropdown(pickModule, AutoPick, "Priority", "Priority", HARVEST_PRIORITIES)
addDropdown(pickModule, AutoPick, "Priority color", "PriorityColor", RGB_OPTIONS)
addDropdown(pickModule, AutoPick, "Dropped hay", "CollectDropped", ON_OFF)
addSlider(pickModule, AutoPick, "Dropped range", "DroppedRange", 5, 250, 5, function(value)
	return tostring(value) .. " studs"
end)
addSlider(pickModule, AutoPick, "Dropped scan budget", "DroppedScanBudget", 25, 800, 25)
addSlider(pickModule, AutoPick, "Dropped per cycle", "DroppedPerCycle", 1, 12, 1)
pickModule:AddButton("Pick nearest once", function()
	local candidate = getHayCandidates(AutoPick.Settings.SearchRange, AutoPick.Settings)[1]
	if candidate then
		requestHarvest(candidate, AutoPick.Settings)
	end
end)

local sellModule = addFeatureModule(Modules, AutoSell, {
	Description = "Moves to the sell location and sells when ready",
})
addDropdown(sellModule, AutoSell, "Sell mode", "Mode", { "When full", "Any hay" })
addDropdown(sellModule, AutoSell, "Auto move to sell", "AutoMove", ON_OFF)
addDropdown(sellModule, AutoSell, "Movement", "MovementMode", MOVEMENT_MODES)
addSlider(sellModule, AutoSell, "Near distance", "NearDistance", 5, 80, 1, function(value)
	return tostring(value) .. " studs"
end)
addSlider(sellModule, AutoSell, "Sell interval", "Interval", 0.2, 3, 0.05, function(value)
	return string.format("%.2fs", value)
end)
sellModule:AddButton("Sell once", requestSell)

local needleModule = addFeatureModule(Modules, NeedleClaim, {
	Description = "Uses PickHay:FireServer(\"Objective\")",
})
addDropdown(needleModule, NeedleClaim, "Require objective visible", "RequireVisibleObjective", ON_OFF)
addSlider(needleModule, NeedleClaim, "Needle range", "MaxDistance", 5, 250, 5, function(value)
	return tostring(value) .. " studs"
end)
addSlider(needleModule, NeedleClaim, "Needle interval", "Interval", 0.15, 3, 0.05, function(value)
	return string.format("%.2fs", value)
end)
needleModule:AddButton("Claim once", requestNeedle)

local upgradeModule = addFeatureModule(Modules, UpgradeManager, {
	Description = "Buys affordable upgrades with a configurable priority",
})
addDropdown(upgradeModule, UpgradeManager, "Mode", "Mode", { "Best affordable", "Selected only" })
addDropdown(upgradeModule, UpgradeManager, "Selected track", "SelectedTrack", getUpgradeTracks())
addDropdown(upgradeModule, UpgradeManager, "Priority", "Priority", UPGRADE_PRIORITIES)
addSlider(upgradeModule, UpgradeManager, "Check interval", "Interval", 0.35, 5, 0.05, function(value)
	return string.format("%.2fs", value)
end)
addDropdown(upgradeModule, UpgradeManager, "Notifications", "Notify", ON_OFF)
upgradeModule:AddButton("Buy selected once", function()
	UpgradeManager:BuySelected()
end)

local eventsModule = addFeatureModule(Modules, GameEvents, {
	Description = "Watches TNT, pitchfork, drone, vacuum, sell, and needle events",
})
addDropdown(eventsModule, GameEvents, "Notifications", "ShowNotifications", ON_OFF)
addDropdown(eventsModule, GameEvents, "Overlay", "ShowOverlay", ON_OFF)
addSlider(eventsModule, GameEvents, "Overlay refresh", "UpdateInterval", 0.25, 5, 0.25, function(value)
	return string.format("%.2fs", value)
end)

local visualsModule = addFeatureModule(Modules, Visuals, {
	Description = "Client-only highlights and world labels",
})
addDropdown(visualsModule, Visuals, "Hay markers", "Hay", ON_OFF)
addDropdown(visualsModule, Visuals, "Dropped markers", "Dropped", ON_OFF)
addDropdown(visualsModule, Visuals, "Needle marker", "Needle", ON_OFF)
addDropdown(visualsModule, Visuals, "Sell markers", "Sell", ON_OFF)
addSlider(visualsModule, Visuals, "Marker range", "Range", 100, 5000, 100, function(value)
	return tostring(value) .. " studs"
end)
addSlider(visualsModule, Visuals, "Marker scan budget", "ScanBudget", 50, 1200, 50)
addSlider(visualsModule, Visuals, "Max hay markers", "MaxHayMarkers", 1, 100, 1)
addSlider(visualsModule, Visuals, "Visual refresh", "Interval", 0.25, 5, 0.25, function(value)
	return string.format("%.2fs", value)
end)
visualsModule:AddButton("Refresh visuals", function()
	Visuals.NextRun = 0
	Visuals:Tick(os.clock())
end)
visualsModule:AddButton("Clear visuals", clearVisuals)

local roundModule = addFeatureModule(Modules, RoundState, {
	Description = "Reads GetHayState for remaining hay and needle id",
	Toggleable = true,
})
roundModule:AddButton("Refresh state", function()
	RoundState.NextRun = 0
	RoundState:Tick(os.clock())
end)

local performanceModule = addFeatureModule(Modules, PerformanceMode, {
	Description = "Disables local particles, trails, and beams",
})
addDropdown(performanceModule, PerformanceMode, "Particles", "Particles", ON_OFF)
addDropdown(performanceModule, PerformanceMode, "Trails", "Trails", ON_OFF)
addDropdown(performanceModule, PerformanceMode, "Beams", "Beams", ON_OFF)
addSlider(performanceModule, PerformanceMode, "Scan per step", "ScanPerStep", 50, 2000, 50)

if UniversalFlight then
	local flightModule = addFeatureModule(Modules, UniversalFlight, {
		Description = "FrostScripts movement utility",
	})
	UniversalFlight.OnStatusChanged = function(status) flightModule:SetStatus(status) end
	UniversalFlight.OnStateChanged = function(enabled)
		if flightModule.Toggle then flightModule.Toggle:SetValue(enabled, true) end
		flightModule:SetEnabled(enabled)
	end
	addSlider(flightModule, UniversalFlight, "Flight speed", "Speed", 10, 180, 5)
	addSlider(flightModule, UniversalFlight, "Vertical speed", "VerticalSpeed", 10, 180, 5)
end

if AutoClicker then
	local clickModule = addFeatureModule(Modules, AutoClicker, {
		Description = "FrostScripts click utility",
	})
	AutoClicker.OnStatusChanged = function(status) clickModule:SetStatus(status) end
	AutoClicker.OnStateChanged = function(enabled)
		if clickModule.Toggle then clickModule.Toggle:SetValue(enabled, true) end
		clickModule:SetEnabled(enabled)
	end
	addSlider(clickModule, AutoClicker, "Clicks per second", "ClicksPerSecond", 1, 30, 1)
end

local dropModule = addFeatureModule(Modules, AutoDrop, {
	Description = "Throws held hay with the game's velocity shape",
})
addDropdown(dropModule, AutoDrop, "Drop mode", "Mode", { "When full", "Any hay" })
addDropdown(dropModule, AutoDrop, "Only away from sell", "OnlyAwayFromSell", ON_OFF)
addSlider(dropModule, AutoDrop, "Sell safe distance", "SellDistance", 5, 100, 1, function(value)
	return tostring(value) .. " studs"
end)
addSlider(dropModule, AutoDrop, "Throw charge", "Charge", 0, 1, 0.05, function(value)
	return string.format("%.2f", value)
end)
addSlider(dropModule, AutoDrop, "Up boost", "UpBoost", 0, 12, 1)
addSlider(dropModule, AutoDrop, "Drop interval", "Interval", 0.35, 4, 0.05, function(value)
	return string.format("%.2fs", value)
end)
dropModule:AddButton("Throw held hay once", function()
	local ok, reason = requestDropHeld(AutoDrop.Settings)
	notify("FrostScripts", ok and "DropHay fired." or tostring(reason), ok and "Success" or "Error")
end)

local diagnosticsModule = addFeatureModule(Modules, Diagnostics, {
	Description = "Scans folders, remotes, sell parts, upgrades, and state",
	Toggleable = false,
})
diagnosticsModule:AddButton("Run diagnostics", function()
	local text = runDiagnostics()
	Diagnostics:SetStatus(text)
	notify("FrostScripts", text, "Success")
end)
diagnosticsModule:AddButton("Unload FrostScripts", function()
	env.FrostScriptsNeedleInHay:Unload()
end, { Danger = true })

Interface:AddClientSettings(Settings)

roundModule:AddDropdown("Status monitor", ON_OFF, Client.StatusMonitor, function(value)
	Client.StatusMonitor = value
	if not value then Interface:HideMonitor("NeedleInHayStatus") end
end)
visualsModule:AddDropdown("Hay marker color", { "Amber", "Cyan", "Green", "Purple", "Red", "White" }, Client.MarkerColor, function(value)
	Client.MarkerColor = value
	Visuals.NextRun = 0
end)
visualsModule:AddDropdown("Needle marker color", { "Cyan", "Amber", "Green", "Purple", "Red", "White" }, Client.NeedleColor, function(value)
	Client.NeedleColor = value
	Visuals.NextRun = 0
end)
visualsModule:AddDropdown("Sell marker color", { "Green", "Amber", "Cyan", "Purple", "Red", "White" }, Client.SellColor, function(value)
	Client.SellColor = value
	Visuals.NextRun = 0
end)

AutoPick:AddSetting("ManualKey", Enum.KeyCode.N)
pickModule:AddKeybind({
	Name = "Pick nearest once",
	Get = function() return AutoPick.Settings.ManualKey end,
	Set = function(key) AutoPick:SetSetting("ManualKey", key) end,
	OnPressed = function()
		local candidate = getHayCandidates(2500, AutoPick.Settings)[1]
		if candidate then requestHarvest(candidate, AutoPick.Settings) end
	end,
})
AutoSell:AddSetting("ManualKey", Enum.KeyCode.G)
sellModule:AddKeybind({
	Name = "Sell hay once",
	Get = function() return AutoSell.Settings.ManualKey end,
	Set = function(key) AutoSell:SetSetting("ManualKey", key) end,
	OnPressed = requestSell,
})

track(player:GetAttributeChangedSignal("HayHeld"):Connect(function()
	setStatus("Hay held changed")
end))
track(player:GetAttributeChangedSignal("HayCapacity"):Connect(function()
	setStatus("Capacity changed")
end))
if Remotes.HaySold then
	track(Remotes.HaySold.OnClientEvent:Connect(function(_, _, _, userId)
		if userId == player.UserId then
			Runtime.EventCounters.Sold += 1
			setStatus("Hay sold")
		end
	end))
end
if Remotes.NeedleFound then
	track(Remotes.NeedleFound.OnClientEvent:Connect(function(userId)
		Runtime.EventCounters.Needles += 1
		setStatus(userId == player.UserId and "You found the needle" or "Needle found")
	end))
end
if Remotes.NeedleRoundCompleted then
	track(Remotes.NeedleRoundCompleted.OnClientEvent:Connect(function()
		Runtime.EventCounters.Rounds += 1
		setStatus("Round completed")
	end))
end
if Remotes.UpgradeChanged then
	track(Remotes.UpgradeChanged.OnClientEvent:Connect(function(success, trackName)
		local text = success and ("Upgraded " .. tostring(trackName)) or "Upgrade failed"
		UpgradeManager:SetStatus(text)
		setStatus(text)
	end))
end

local Suite = {
	Client = Client,
	Runtime = Runtime,
	Features = {
		AssistMode = AssistMode,
		AutoPick = AutoPick,
		AutoSell = AutoSell,
		AutoDrop = AutoDrop,
		NeedleClaim = NeedleClaim,
		UpgradeManager = UpgradeManager,
		GameEvents = GameEvents,
		Visuals = Visuals,
		PerformanceMode = PerformanceMode,
		RoundState = RoundState,
		Diagnostics = Diagnostics,
		Flight = UniversalFlight,
		AutoClicker = AutoClicker,
	},
}

function Suite:Unload()
	Runtime.Active = false
	for _, feature in ipairs(Runtime.Features) do
		if type(feature.Disable) == "function" then
			pcall(function() feature:Disable() end)
		else
			feature.Enabled = false
		end
	end
	clearVisuals()
	for _, connection in ipairs(Runtime.Connections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(Runtime.Connections)
	if Runtime.Interface then
		pcall(function() Runtime.Interface:HideMonitor("NeedleInHayStatus") end)
		pcall(function() Runtime.Interface:HideMonitor("NeedleInHayEvents") end)
		pcall(function() Runtime.Interface:Destroy() end)
		Runtime.Interface = nil
	end
	if env.FrostScriptsNeedleInHay == self then
		env.FrostScriptsNeedleInHay = nil
	end
end

env.FrostScriptsNeedleInHay = Suite

track(RunService.Heartbeat:Connect(function()
	if not Runtime.Active then return end
	local now = os.clock()
	for _, feature in ipairs(Runtime.Features) do
		if feature.Enabled and feature.Tick then
			local ok, err = pcall(function()
				feature:Tick(now)
			end)
			if not ok then
				feature:SetStatus(tostring(err))
				feature:SetEnabled(false)
			end
		end
	end
end))

track(RunService.Heartbeat:Connect(function()
	if not Runtime.Active or not Runtime.Interface then return end
	if os.clock() - Runtime.LastUiAt < 0.5 then return end
	Runtime.LastUiAt = os.clock()
	local state = getHayState(false)
	local remaining = state and state.remaining or GameConfig.TOTAL_HAY or 0
	local text = string.format(
		"Held %s/%s | Vacuum %s | Pitchfork %s | Remaining %s\n%s",
		formatNumber(hayHeld()),
		formatNumber(hayCapacity()),
		formatNumber(vacuumLoad()),
		formatNumber(Runtime.Stats.PitchforkDigs),
		formatNumber(remaining),
		Runtime.Status
	)
	overviewText:SetText(text)
	if Client.StatusMonitor then
		Runtime.Interface:SetMonitor("NeedleInHayStatus", text)
	end
end))

Interface:SelectTab(Home)
RoundState:SetEnabled(true)
notify("FrostScripts", "NeedleInHay loaded.", "Success")

return Suite
