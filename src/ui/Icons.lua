-- Asset-free line icons with a shared stroke weight and explicit favorite state.
local function iconLine(root, x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	return create("Frame", {
		Name = "IconStroke", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 1.6),
		Rotation = math.deg(math.atan2(dy, dx)), BorderSizePixel = 0,
		ZIndex = root.ZIndex, Parent = root,
	}, { corner(1) })
end

local HEART_POINTS = {
	{10, 5}, {8, 3}, {5, 2.8}, {2.7, 4.2}, {2, 6.5}, {2.6, 9},
	{4.5, 11.5}, {10, 17}, {15.5, 11.5}, {17.4, 9}, {18, 6.5},
	{17.3, 4.2}, {15, 2.8}, {12, 3},
}

function Window:_attachIcon(host, name)
	host.Text = ""
	local root = create("Frame", {
		Name = "NavigationBadge_" .. name, Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = host.ZIndex, Parent = host,
	})
	local function path(points, closed)
		for index = 1, #points - (closed and 0 or 1) do
			local a, b = points[index], points[index % #points + 1]
			iconLine(root, a[1], a[2], b[1], b[2])
		end
	end
	if name == "favorites" then
		path(HEART_POINTS, true)
		local fill = create("Frame", { Name = "HeartFill", Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Visible = false, ZIndex = host.ZIndex, Parent = root })
		-- Interior shares the outline contour. Only saved favorites show the fill.
		for y = 3, 16 do
			local intersections = {}
			for index, a in ipairs(HEART_POINTS) do
				local b = HEART_POINTS[index % #HEART_POINTS + 1]
				if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
					table.insert(intersections, a[1] + (y - a[2]) * (b[1] - a[1]) / (b[2] - a[2]))
				end
			end
			table.sort(intersections)
			for index = 1, #intersections - 1, 2 do
				create("Frame", { Name = "HeartInterior", Position = UDim2.fromOffset(intersections[index], y),
					Size = UDim2.fromOffset(intersections[index + 1] - intersections[index], 1),
					BorderSizePixel = 0, ZIndex = host.ZIndex, Parent = fill })
			end
		end
	elseif name == "home" then
		path({{2, 9}, {10, 2}, {18, 9}})
		path({{4, 8}, {4, 18}, {8, 18}, {8, 12}, {12, 12}, {12, 18}, {16, 18}, {16, 8}})
	elseif name == "library" then
		path({{4, 2}, {16, 2}, {16, 18}, {4, 18}}, true)
		iconLine(root, 7, 2, 7, 18)
		iconLine(root, 10, 7, 13, 7); iconLine(root, 10, 11, 13, 11)
	elseif name == "modules" then
		for _, position in ipairs({{2, 2}, {12, 2}, {2, 12}, {12, 12}}) do
			local x, y = position[1], position[2]
			path({{x, y}, {x + 6, y}, {x + 6, y + 6}, {x, y + 6}}, true)
		end
	elseif name == "snowflake" then
		for _, rotation in ipairs({0, 60, 120}) do
			local arm = iconLine(root, 2, 10, 18, 10); arm.Rotation = rotation
		end
	else
		for index, x in ipairs({12, 6, 12}) do
			local y = 4 + (index - 1) * 6
			iconLine(root, 2, y, x - 2, y); iconLine(root, x + 2, y, 18, y)
			path({{x - 2, y - 2}, {x + 2, y - 2}, {x + 2, y + 2}, {x - 2, y + 2}}, true)
		end
	end
	local function tint()
		for _, piece in ipairs(root:GetDescendants()) do
			if piece:IsA("Frame") then piece.BackgroundColor3 = host.TextColor3 end
		end
	end
	self:_connect(host:GetPropertyChangedSignal("TextColor3"), tint)
	tint()
	return root
end
