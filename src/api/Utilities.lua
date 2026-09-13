local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

function API.GetCharacter(player)
	player = player or Players.LocalPlayer
	local character = player and player.Character
	return character,
		character and character:FindFirstChildOfClass("Humanoid"),
		character and character:FindFirstChild("HumanoidRootPart")
end

function API.GetPosition(object)
	if not object then return nil end
	if typeof(object) == "Vector3" then return object end
	if object:IsA("BasePart") then return object.Position end
	if object:IsA("Attachment") then return object.WorldPosition end
	if object:IsA("Model") then
		local ok, pivot = pcall(function() return object:GetPivot() end)
		if ok then return pivot.Position end
	end
	local part = object:FindFirstChildWhichIsA("BasePart", true)
	if part then return part.Position end
	local ancestor = object:FindFirstAncestorWhichIsA("BasePart") or object:FindFirstAncestorWhichIsA("Model")
	if ancestor then return API.GetPosition(ancestor) end
	return nil
end

function API.DistanceToPlayer(target, player)
	local _, _, root = API.GetCharacter(player)
	local position = API.GetPosition(target)
	return root and position and (root.Position - position).Magnitude or math.huge
end

function API.FormatNumber(value, compact)
	value = tonumber(value) or 0
	if value ~= value or math.abs(value) == math.huge then return "—" end
	if compact then
		for _, unit in ipairs({ { 1e15, "Q" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
			if math.abs(value) >= unit[1] then
				local number = string.format("%.2f", value / unit[1]):gsub("0+$", ""):gsub("%.$", "")
				return number .. unit[2]
			end
		end
	end
	local sign = value < 0 and "-" or ""
	local digits = tostring(math.floor(math.abs(value) + 0.5))
	return sign .. (compact and digits or digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function API.FormatDistance(value)
	if not value or value == math.huge then return "far" end
	return tostring(math.floor(value + 0.5)) .. " studs"
end

function API.CreateScope()
	local scope = { Closed = false, _items = {} }
	local function clean(item)
		if type(item) == "function" then item()
		elseif typeof(item) == "RBXScriptConnection" then item:Disconnect()
		elseif type(item.Destroy) == "function" then item:Destroy()
		elseif type(item.Disconnect) == "function" then item:Disconnect() end
	end
	function scope:Track(item)
		if item then
			if self.Closed then pcall(clean, item) else table.insert(self._items, item) end
		end
		return item
	end
	function scope:Destroy()
		if self.Closed then return end
		self.Closed = true
		for index = #self._items, 1, -1 do pcall(clean, self._items[index]) end
		table.clear(self._items)
	end
	return scope
end

-- One scheduler can service an entire suite. Modules register work instead of
-- each owning another RenderStepped or Heartbeat connection.
function API.CreateUpdateManager(options)
	options = options or {}
	local manager = {
		Destroyed = false,
		Jobs = { Render = {}, Heartbeat = {}, Slow = {}, Stats = {} },
		Errors = {},
		_slowElapsed = 0,
		_statsElapsed = 0,
		_connections = {},
	}

	local function run(bucket, deltaTime)
		for name, job in pairs(manager.Jobs[bucket]) do
			local ok, err = pcall(job.Callback, deltaTime)
			if not ok then
				job.Failures += 1
				manager.Errors[name] = tostring(err)
				if options.OnError then pcall(options.OnError, name, err) end
				if job.Failures >= 3 then manager.Jobs[bucket][name] = nil end
			else
				job.Failures = 0
			end
		end
	end

	function manager:Register(name, bucket, callback)
		assert(not self.Destroyed, "Update manager is destroyed")
		assert(type(name) == "string" and name ~= "", "Update job needs a name")
		assert(self.Jobs[bucket], "Unknown update bucket: " .. tostring(bucket))
		assert(type(callback) == "function", "Update callback must be a function")
		for _, jobs in pairs(self.Jobs) do
			assert(jobs[name] == nil, "Duplicate update job: " .. name)
		end
		local job = { Callback = callback, Failures = 0 }
		self.Jobs[bucket][name] = job
		local registration = { Connected = true }
		function registration:Disconnect()
			if not self.Connected then return end
			self.Connected = false
			if manager.Jobs[bucket][name] == job then manager.Jobs[bucket][name] = nil end
		end
		return registration
	end

	function manager:Count()
		local count = 0
		for _, jobs in pairs(self.Jobs) do for _ in pairs(jobs) do count += 1 end end
		return count
	end

	function manager:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		for _, connection in ipairs(self._connections) do connection:Disconnect() end
		table.clear(self._connections)
		for _, jobs in pairs(self.Jobs) do table.clear(jobs) end
	end

	table.insert(manager._connections, RunService.RenderStepped:Connect(function(deltaTime)
		if not manager.Destroyed then run("Render", deltaTime) end
	end))
	table.insert(manager._connections, RunService.Heartbeat:Connect(function(deltaTime)
		if manager.Destroyed then return end
		run("Heartbeat", deltaTime)
		manager._slowElapsed += deltaTime
		manager._statsElapsed += deltaTime
		if manager._slowElapsed >= (options.SlowInterval or 0.1) then
			local elapsed = manager._slowElapsed
			manager._slowElapsed = 0
			run("Slow", elapsed)
		end
		if manager._statsElapsed >= (options.StatsInterval or 0.75) then
			local elapsed = manager._statsElapsed
			manager._statsElapsed = 0
			run("Stats", elapsed)
		end
	end))
	return manager
end

function API.CreateCharacterManager(player)
	player = player or Players.LocalPlayer
	local manager = {
		Player = player,
		Character = nil,
		Humanoid = nil,
		Root = nil,
		Destroyed = false,
		_added = {},
		_removing = {},
		_connections = {},
	}

	local function refresh(character)
		manager.Character = character
		manager.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
		manager.Root = character and character:FindFirstChild("HumanoidRootPart") or nil
	end
	local function subscribe(list, callback, immediate)
		assert(type(callback) == "function", "Character callback must be a function")
		local entry = { Callback = callback, Connected = true }
		table.insert(list, entry)
		function entry:Disconnect() self.Connected = false end
		if immediate and manager.Character then task.defer(callback, manager.Character, manager.Humanoid, manager.Root) end
		return entry
	end

	function manager:Get()
		if self.Character ~= self.Player.Character then refresh(self.Player.Character) end
		if self.Character then
			if not self.Humanoid or not self.Humanoid.Parent then self.Humanoid = self.Character:FindFirstChildOfClass("Humanoid") end
			if not self.Root or not self.Root.Parent then self.Root = self.Character:FindFirstChild("HumanoidRootPart") end
		end
		return self.Character, self.Humanoid, self.Root
	end
	function manager:OnAdded(callback, immediate) return subscribe(self._added, callback, immediate ~= false) end
	function manager:OnRemoving(callback) return subscribe(self._removing, callback, false) end
	function manager:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		for _, connection in ipairs(self._connections) do connection:Disconnect() end
		table.clear(self._connections)
		table.clear(self._added)
		table.clear(self._removing)
		refresh(nil)
	end

	refresh(player.Character)
	table.insert(manager._connections, player.CharacterAdded:Connect(function(character)
		refresh(character)
		for _, entry in ipairs(manager._added) do if entry.Connected then task.defer(entry.Callback, character, manager.Humanoid, manager.Root) end end
	end))
	table.insert(manager._connections, player.CharacterRemoving:Connect(function(character)
		for _, entry in ipairs(manager._removing) do if entry.Connected then pcall(entry.Callback, character) end end
		refresh(nil)
	end))
	return manager
end
