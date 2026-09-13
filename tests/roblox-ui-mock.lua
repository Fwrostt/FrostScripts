-- Small service/instance boundary for UI behavior tests. This is not a renderer.
local Mock = { Deferred = {}, Delayed = {}, Viewport = { X = 1280, Y = 800 } }
local function signal()
	local result = { listeners = {} }
	function result:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, { connection, callback })
		return connection
	end
	function result:Fire(...)
		for _, entry in ipairs(table.clone(self.listeners)) do if entry[1].Connected then entry[2](...) end end
	end
	return result
end
local vectorMeta = {}
local function vector(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, _type = z and "Vector3" or "Vector2" }, vectorMeta) end
local function vectorOperation(a, b, operation)
	assert(a._type == b._type, "Vector2 and Vector3 cannot be combined")
	if a._type == "Vector3" then return vector(operation(a.X, b.X), operation(a.Y, b.Y), operation(a.Z, b.Z)) end
	return vector(operation(a.X, b.X), operation(a.Y, b.Y))
end
vectorMeta.__add = function(a, b) return vectorOperation(a, b, function(x, y) return x + y end) end
vectorMeta.__sub = function(a, b) return vectorOperation(a, b, function(x, y) return x - y end) end
vectorMeta.__div = function(a, b)
	if a._type == "Vector3" then return vector(a.X / b, a.Y / b, a.Z / b) end
	return vector(a.X / b, a.Y / b)
end
local function udim(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end
local function udim2(xs, xo, ys, yo) return { X = udim(xs, xo), Y = udim(ys, yo) } end
local colors = {}
local function color(r, g, b)
	local key = tostring(r) .. "," .. tostring(g) .. "," .. tostring(b)
	colors[key] = colors[key] or { R = r, G = g, B = b, _type = "Color3" }
	return colors[key]
end
local Enum = setmetatable({}, { __index = function(t, group)
	local values = setmetatable({}, { __index = function(items, name)
		local item = { Name = name }; rawset(items, name, item); return item
	end })
	rawset(t, group, values); return values
end })
local methods, meta = {}, {}
local function isGui(class) return class:find("Frame") or class:find("Label") or class:find("Button") or class == "TextBox" or class == "CanvasGroup" end
function methods:IsA(class)
	return self.ClassName == class or class == "Instance" or (class == "GuiObject" and isGui(self.ClassName))
		or (class == "GuiButton" and self.ClassName:find("Button") ~= nil)
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
	local result = {}
	for _, child in ipairs(self._children) do
		table.insert(result, child)
		for _, item in ipairs(child:GetDescendants()) do table.insert(result, item) end
	end
	return result
end
function methods:FindFirstChild(name)
	for _, child in ipairs(self._children) do if child.Name == name then return child end end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods:FindFirstChildWhichIsA(class, recursive)
	for _, child in ipairs(recursive and self:GetDescendants() or self._children) do if child:IsA(class) then return child end end
end
function methods:SetAttribute(key, value) self._attributes[key] = value end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:GetAttributes() return table.clone(self._attributes) end
function methods:GetPropertyChangedSignal(key)
	self._signals[key] = self._signals[key] or signal()
	return self._signals[key]
end
function methods:Destroy()
	if self._dead then return end
	self._dead = true
	self.Destroying:Fire()
	for _, child in ipairs(table.clone(self._children)) do child:Destroy() end
	self.Parent = nil
end
function methods:CaptureFocus() Mock.Focused = self end
function methods:ReleaseFocus() if Mock.Focused == self then Mock.Focused = nil end end
function methods:Play() self.Playing = true; self.PlayCount = (self.PlayCount or 0) + 1 end
function methods:Stop() self.Playing = false end
meta.__index = function(self, key)
	if methods[key] then return methods[key] end
	local props = rawget(self, "_props")
	if props[key] ~= nil then return props[key] end
	if key == "AbsoluteSize" then
		if self.ClassName == "ScreenGui" or self.ClassName == "PlayerGui" then return vector(Mock.Viewport.X, Mock.Viewport.Y) end
		local parent = self.Parent and self.Parent.AbsoluteSize or vector(Mock.Viewport.X, Mock.Viewport.Y)
		local size = self.Size
		return size and vector(parent.X * size.X.Scale + size.X.Offset, parent.Y * size.Y.Scale + size.Y.Offset) or vector(0, 0)
	end
	if key == "AbsolutePosition" then return vector(100, 100) end
	if key == "AbsoluteContentSize" then
		local height = 0
		for _, child in ipairs(self.Parent and self.Parent:GetChildren() or {}) do
			if isGui(child.ClassName) and child.Visible then height += child.Size.Y.Offset + (self.Padding and self.Padding.Offset or 0) end
		end
		return vector(0, height)
	end
	if key == "TextBounds" then return vector(100, 16) end
	return nil
end
meta.__newindex = function(self, key, value)
	if key:sub(1, 1) == "_" then rawset(self, key, value); return end
	local props = self._props
	if key == "Parent" and props.Parent ~= value then
		if props.Parent then
			local index = table.find(props.Parent._children, self)
			if index then table.remove(props.Parent._children, index) end
		end
		if value then table.insert(value._children, self) end
	end
	local old = props[key]
	props[key] = value
	if old ~= value and self._signals[key] then self._signals[key]:Fire() end
	if key == "Parent" and value then
		local ancestor = value
		while ancestor do ancestor.DescendantAdded:Fire(self); ancestor = ancestor.Parent end
	end
end
local function instance(class)
	local self = setmetatable({ _props = { ClassName = class, Name = class, Visible = true, Enabled = true,
		Size = udim2(), Position = udim2(), AnchorPoint = vector(0, 0), Scale = 1, Text = "" },
		_children = {}, _attributes = {}, _signals = {} }, meta)
	for _, name in ipairs({ "Destroying", "DescendantAdded", "Activated", "MouseEnter", "MouseLeave", "InputBegan", "InputChanged", "InputEnded", "FocusLost" }) do self[name] = signal() end
	return self
end
local player = instance("Player")
player.Name, player.DisplayName = "Frost", "Frost"
local playerGui = instance("PlayerGui"); playerGui.Parent = player
local camera = instance("Camera"); camera.ViewportSize = vector(1280, 800)
local workspaceMock = instance("Workspace"); workspaceMock.CurrentCamera = camera
local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal(),
	MouseEnabled = true, MouseIconEnabled = true }
function input:GetFocusedTextBox() return Mock.Focused end
function input:IsKeyDown() return false end
function input:GetMouseLocation() return vector(320, 240) end
local services = { Players = { LocalPlayer = player }, UserInputService = input,
	RunService = { RenderStepped = signal() }, TweenService = { Create = function(_, object, _, properties)
		return { Play = function() for key, value in pairs(properties) do object[key] = value end end, Cancel = function() end }
	end } }
Mock.Env = setmetatable({
	game = { GetService = function(_, name) return assert(services[name], name) end },
	workspace = workspaceMock, Instance = { new = instance }, Enum = Enum,
	Vector2 = { new = vector, zero = vector(0, 0) }, Vector3 = { new = vector },
	UDim = { new = udim }, UDim2 = { new = udim2, fromOffset = function(x, y) return udim2(0, x, 0, y) end, fromScale = function(x, y) return udim2(x, 0, y, 0) end },
	Color3 = { new = color, fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end },
	TweenInfo = { new = function() return {} end },
	ColorSequence = { new = function(...) return { ... } end },
	NumberSequence = { new = function(...) return { ... } end },
	NumberSequenceKeypoint = { new = function(...) return { ... } end },
	typeof = function(value) return type(value) == "table" and (value._type or (getmetatable(value) == meta and "Instance")) or type(value) end,
	task = {
		defer = function(callback) table.insert(Mock.Deferred, callback) end,
		delay = function(_, callback) table.insert(Mock.Delayed, callback) end,
		spawn = function(callback) callback() end,
		wait = function() end,
	},
}, { __index = getfenv() })
function Mock.Flush()
	local attempts = 0
	while #Mock.Deferred > 0 do
		attempts += 1; assert(attempts < 100, "unbounded deferred UI work")
		local callbacks = Mock.Deferred; Mock.Deferred = {}
		for _, callback in ipairs(callbacks) do callback() end
	end
end
function Mock.FlushDelayed()
	local callbacks = Mock.Delayed; Mock.Delayed = {}
	for _, callback in ipairs(callbacks) do callback() end
end
function Mock.Resize(x, y)
	Mock.Viewport = vector(x, y)
	camera.ViewportSize = vector(x, y)
end
