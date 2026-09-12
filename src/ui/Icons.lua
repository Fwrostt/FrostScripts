-- Public LucideBlox raster assets. They render consistently in Roblox without custom SVG geometry.
local ICON_ASSETS = {
	home = "rbxassetid://7733960981",
	library = "rbxassetid://7743869054",
	modules = "rbxassetid://7733970318",
	settings = "rbxassetid://7734053495",
	controls = "rbxassetid://7734058803",
	snowflake = "rbxassetid://7733666258",
}

function Window:_attachIcon(host, name)
	host.Text = ""
	local image = create("ImageLabel", {
		Name = "NavigationIcon_" .. name,
		Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1,
		Image = ICON_ASSETS[name] or ICON_ASSETS.controls, ImageColor3 = host.TextColor3,
		ScaleType = Enum.ScaleType.Fit, Parent = host,
	})
	local function tint()
		image.ImageColor3 = host.TextColor3
		image:SetAttribute("FrostTheme_ImageColor3", host:GetAttribute("FrostTheme_TextColor3") or "Muted")
	end
	self:_connect(host:GetPropertyChangedSignal("TextColor3"), tint)
	tint()
	return image
end
