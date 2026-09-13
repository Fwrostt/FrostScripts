-- Purpose-built solid navigation badges. They are drawn with native Roblox Frames,
-- so no SVG paths, font glyphs, or third-party image assets are involved.
local function badgePiece(parent, name, position, size, transparency, rotation)
	return create("Frame", {
		Name = name,
		Position = position,
		Size = size,
		Rotation = rotation or 0,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(math.max(2, math.floor(math.min(size.X.Offset, size.Y.Offset) / 3))) })
end

local function makeLibrary(root)
	badgePiece(root, "ScriptPage", UDim2.fromOffset(3, 1), UDim2.fromOffset(14, 18), 0.5)
	badgePiece(root, "ScriptBinding", UDim2.fromOffset(3, 1), UDim2.fromOffset(4, 18), 0.04)
	badgePiece(root, "ScriptLine", UDim2.fromOffset(9, 5), UDim2.fromOffset(6, 2), 0.08)
	badgePiece(root, "ScriptLine", UDim2.fromOffset(9, 9), UDim2.fromOffset(5, 2), 0.22)
	badgePiece(root, "ScriptLine", UDim2.fromOffset(9, 13), UDim2.fromOffset(7, 2), 0.38)
end

local function makeSliders(root)
	for index, x in ipairs({ 11, 6, 13 }) do
		local y = 3 + (index - 1) * 7
		badgePiece(root, "Track", UDim2.fromOffset(2, y + 2), UDim2.fromOffset(16, 2), 0.62)
		badgePiece(root, "Knob", UDim2.fromOffset(x, y), UDim2.fromOffset(5, 5), index == 2 and 0.02 or 0.14)
	end
end

local function makeModules(root)
	for index = 0, 2 do
		badgePiece(root, "ModuleBar", UDim2.fromOffset(2, 2 + index * 7), UDim2.fromOffset(16, 3), index == 1 and 0.08 or 0.3)
	end
end

local function makeMark(root)
	for _, rotation in ipairs({ 0, 60, -60 }) do
		badgePiece(root, "CrystalArm", UDim2.fromOffset(2, 9), UDim2.fromOffset(16, 2), 0.1, rotation)
	end
	badgePiece(root, "CrystalCenter", UDim2.fromOffset(7, 7), UDim2.fromOffset(6, 6), 0.02, 45)
end

local ICON_BUILDERS = {
	library = makeLibrary,
	modules = makeModules,
	settings = makeSliders,
	controls = makeSliders,
	snowflake = makeMark,
}

function Window:_attachIcon(host, name)
	host.Text = ""
	if name == "home" then
		local image = create("ImageLabel", {
			Name = "NavigationHome",
			Size = UDim2.fromOffset(20, 20),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://7733960981",
			ImageColor3 = host.TextColor3,
			ScaleType = Enum.ScaleType.Fit,
			Parent = host,
		})
		self:_connect(host:GetPropertyChangedSignal("TextColor3"), function()
			image.ImageColor3 = host.TextColor3
		end)
		return image
	end
	local root = create("Frame", {
		Name = "NavigationBadge_" .. name,
		Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = host,
	})
	local buildBadge = ICON_BUILDERS[name] or makeSliders
	buildBadge(root)

	local function tint()
		for _, piece in ipairs(root:GetDescendants()) do
			if piece:IsA("Frame") then piece.BackgroundColor3 = host.TextColor3 end
		end
	end
	self:_connect(host:GetPropertyChangedSignal("TextColor3"), tint)
	tint()
	return root
end
