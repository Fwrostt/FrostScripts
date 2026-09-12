-- Geometry is compiled from assets/icons/*.svg; no font glyphs or raster scaling.
function Window:_attachIcon(host, name)
	host.Text = ""
	local root = create("Frame", { Name = "VectorIcon_" .. name, Size = UDim2.fromOffset(24, 24),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1, Parent = host })
	create("UIScale", { Scale = 0.92, Parent = root })
	local objects = {}
	for _, shape in ipairs(SVG_ICONS[name] or SVG_ICONS.controls) do
		local frame
		if shape[1] == "line" then
			local dx, dy = shape[4] - shape[2], shape[5] - shape[3]
			frame = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset((shape[2] + shape[4]) / 2, (shape[3] + shape[5]) / 2),
				Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), shape[6]),
				Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = host.TextColor3,
				BorderSizePixel = 0, Parent = root }, { corner(shape[6]) })
			table.insert(objects, { frame, "BackgroundColor3" })
		else
			local circle = shape[1] == "circle"
			local outline = stroke(host.TextColor3, 0)
			outline.Thickness = circle and shape[5] or shape[7]
			frame = create("Frame", {
				Position = UDim2.fromOffset(circle and shape[2] - shape[4] or shape[2], circle and shape[3] - shape[4] or shape[3]),
				Size = UDim2.fromOffset(circle and shape[4] * 2 or shape[4], circle and shape[4] * 2 or shape[5]),
				BackgroundTransparency = 1, Parent = root,
			}, { corner(circle and shape[4] or shape[6]), outline })
			table.insert(objects, { outline, "Color" })
		end
	end
	local function tint()
		for _, item in ipairs(objects) do
			item[1][item[2]] = host.TextColor3
			item[1]:SetAttribute("FrostTheme_" .. item[2], host:GetAttribute("FrostTheme_TextColor3") or "Muted")
		end
	end
	self:_connect(host:GetPropertyChangedSignal("TextColor3"), tint)
	tint()
	return root
end
