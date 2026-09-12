local Players = game:GetService("Players")

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
