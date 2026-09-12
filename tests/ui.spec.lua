local chunk = assert(loadstring(UI_SOURCE, "@FrostScripts/UI"))
setfenv(chunk, Mock.Env)
local UI = chunk()
local window = UI.new({ Animations = false })
local home = window:AddTab("Home", "H", "Overview")
local modules = window:AddTab("Modules", "M", "Features")
local alpha = modules:AddModule({ Name = "Flight", Description = "Movement", Toggleable = true })
local beta = modules:AddModule({ Name = "Harvest", Description = "Collect resources" })
local slider = alpha:AddSlider("Vertical speed", 5, 25, 5, function() end, { Step = 3 })
local dropdown = beta:AddDropdown("Priority", { "Nearest", "Farthest", "Largest" }, "Nearest", function() end)
local empty = beta:AddDropdown("Empty", {}, nil, function() end)
local chips = beta:AddMultiDropdown("Colors", { "Blue", "Red" }, { Blue = true }, function() end)
beta:AddNumberInput("Budget", 20, function() end, { Min = 1, Max = 100 })
beta:AddButton("Run", function() end)
beta:AddParagraph("Details", "Description")
beta:AddColorPicker("Accent", UI.Theme.Accent, function() end)
Mock.Flush()
local passed = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1; print("PASS " .. name)
end

test("tabs and controls construct without gameplay dependencies", function()
	assert(window.ActiveTab == home and #modules.Modules == 2)
	assert(window.ThemeName == "Black" and UI.Theme.Background.R < 0.04)
	assert(empty.Value == nil and dropdown.Value == "Nearest")
	slider:SetValue(9, true)
	assert(slider.Value == 8, "slider step must be relative to minimum")
end)
test("search matches control names and supports active filtering", function()
	window:SelectTab(modules)
	window:SetSearch("vertical speed")
	assert(alpha.Card.Visible and not beta.Card.Visible)
	window:SetSearch("unmatched")
	assert(window.Empty.Visible and not alpha.Card.Visible)
	window:SetSearch("")
	alpha:SetEnabled(true)
	window:SetActiveOnly(true)
	assert(alpha.Card.Visible and not beta.Card.Visible)
	alpha:SetEnabled(false)
	assert(window.Empty.Visible)
	window:SetActiveOnly(false)
end)
test("phone and landscape viewports fit the window", function()
	for _, size in ipairs({ { 390, 844 }, { 844, 390 }, { 320, 568 }, { 1280, 800 } }) do
		Mock.Resize(size[1], size[2])
		assert(window.TargetSize.X * window.Scale.Scale <= size[1] - 23.9)
		assert(window.TargetSize.Y * window.Scale.Scale <= size[2] - 23.9)
	end
	Mock.Resize(390, 844)
	assert(window._compact and not modules.Label.Visible)
	local added = window:AddTab("Settings", "S", "Appearance")
	assert(not added.Label.Visible)
	Mock.Resize(1280, 800)
	assert(not window._compact and modules.Label.Visible)
end)
test("rapid hide and reopen ignores old delayed work", function()
	window:SetVisible(false)
	assert(window.Launcher.Visible)
	window:SetVisible(true)
	Mock.FlushDelayed()
	assert(window.Gui.Enabled and not window.Launcher.Visible)
end)
test("window drag follows the pointer without a render-step delay", function()
	local header = window.Main:FindFirstChild("Header")
	local input = Mock.Env.game:GetService("UserInputService")
	local down = { UserInputType = Mock.Env.Enum.UserInputType.MouseButton1, Position = Mock.Env.Vector2.new(200, 180) }
	header.InputBegan:Fire(down)
	input.InputChanged:Fire({ UserInputType = Mock.Env.Enum.UserInputType.MouseMovement, Position = Mock.Env.Vector2.new(245, 210) })
	assert(window.Frame.Position.X.Offset > 0 and window.Frame.Position.Y.Offset > 0)
	input.InputEnded:Fire(down)
end)
test("dropdown chooses arbitrary options and disconnects popup events", function()
	window:_openDropdown(dropdown, "Priority", { "Nearest", "Farthest", "Largest" }, beta.Card)
	local popup = window._dropdown
	for _, object in ipairs(popup.Root:GetDescendants()) do
		if object:IsA("TextButton") and object.Text:find("Largest", 1, true) then object.Activated:Fire(); break end
	end
	assert(dropdown.Value == "Largest" and window._dropdown == nil)
	for _, connection in ipairs(popup.Connections) do assert(not connection.Connected) end
end)
test("theme changes preserve selected chips and update hover colors", function()
	window:SetTheme("Rose")
	assert(chips.Buttons.Blue.BackgroundColor3 == UI.Theme.AccentSoft)
	chips:SetValue({ Red = true }, true)
	window:SetTheme("Frost")
	assert(chips.Buttons.Red.BackgroundColor3 == UI.Theme.AccentSoft)
	assert(chips.Buttons.Blue.BackgroundColor3 == UI.Theme.PanelRaised)
end)
test("notifications are bounded, dismissible, and fit narrow viewports", function()
	Mock.Resize(320, 568)
	for index = 1, 5 do window:Notify({ Text = "Message " .. index }) end
	assert(#window.Notifications == 3)
	local frame = window.Notifications[3]
	assert(frame.Size.X.Offset <= 288 and frame.Parent == window.NotificationGui)
	for _, object in ipairs(frame:GetChildren()) do
		if object:IsA("TextButton") then object.Activated:Fire(); break end
	end
	assert(#window.Notifications == 2)
	Mock.FlushDelayed(); Mock.FlushDelayed()
	assert(#window.Notifications == 0)
end)
test("module keybinds stay in their module and reject reserved keys", function()
	local key, calls = Mock.Env.Enum.KeyCode.F, 0
	local binding = alpha:AddKeybind({ Name = "Toggle flight", Get = function() return key end,
		Set = function(value) key = value end, OnPressed = function() calls += 1 end })
	assert(binding.Button.Parent.Parent == alpha.Body)
	window:_handleKeyboard({ UserInputType = Mock.Env.Enum.UserInputType.Keyboard, KeyCode = key }, false)
	assert(calls == 1)
	binding.Button.Activated:Fire()
	window:_handleKeyboard({ UserInputType = Mock.Env.Enum.UserInputType.Keyboard, KeyCode = Mock.Env.Enum.KeyCode.W }, false)
	assert(key == Mock.Env.Enum.KeyCode.F)
end)
test("background motion, decoration, sound and notifications can be disabled", function()
	window:SetBackgroundEffects(true)
	window:SetBackgroundAnimations(true)
	window:SetAnimations(true)
	assert(window._ambientConnection and window._ambientConnection.Connected)
	window:SetBackgroundAnimations(false)
	assert(not window._ambientConnection and window.Ambient.Visible)
	window:SetBackgroundAnimations(true)
	window:SetAnimations(false)
	assert(not window._ambientConnection)
	window:SetBackgroundEffects(false)
	assert(not window.Ambient.Visible)
	window:SetSounds(false)
	local count = window.UISound.PlayCount or 0
	window:PlaySound("Click")
	assert((window.UISound.PlayCount or 0) == count and not window.UISound.Playing)
	window:SetNotifications(false)
	assert(window:Notify("hidden") == nil)
	window:SetNotifications(true)
end)
test("catalog cards normalize optional images and adapt their grid", function()
	assert(UI.ImageContent({ AssetId = "12345" }) == "rbxassetid://12345")
	assert(UI.ImageContent({ AssetId = "https://example.test/picture.png" }) == "")
	local library = window:AddTab("Library", "L")
	local card = library:AddScriptCard({ Name = "Sample", Description = "A custom script", Image = { AssetId = "" } }, function() end)
	assert(not card.Image.Visible)
	card.Module.Card.MouseEnter:Fire()
	assert(card.Module.Card.BackgroundColor3 == UI.Theme.Surface)
	assert(card.Cover:FindFirstChild("CardHoverWash").BackgroundTransparency < 1)
	assert(not card.Cover:FindFirstChild("CoverFallback").Visible)
	card.Module.Card.MouseLeave:Fire()
	assert(card.Cover:FindFirstChild("CardHoverWash").BackgroundTransparency == 1)
	assert(card.Cover:FindFirstChild("CoverFallback").Visible)
	Mock.Resize(1280, 800)
	assert(library.CardLayout.CellSize.X.Scale == 0.5)
	Mock.Resize(390, 844)
	assert(library.CardLayout.CellSize.X.Scale == 1)
end)
test("dashboard cards use two columns on a normal workspace", function()
	Mock.Resize(1280, 800)
	local dashboard = window:AddTab("Dashboard", "home")
	dashboard:SetDashboardLayout()
	dashboard:AddModule({ Name = "Overview", Collapsible = false })
	dashboard:AddModule({ Name = "Actions", Collapsible = false })
	assert(dashboard.DashboardGrid.CellSize.X.Scale == 0.5)
	assert(dashboard.DashboardGrid.CellSize.Y.Offset == 174)
	assert(window.Sidebar:FindFirstChildWhichIsA("UICorner"))
end)
test("two script cards fit without scrolling across supported viewports", function()
	local library = window._tabsByName.Library
	library:AddScriptCard({ Name = "Second script", Description = "A second game with a longer description", Image = { AssetId = "12345" } }, function() end)
	window:SelectTab(library)
	for _, preset in ipairs({ "Comfortable", "Large", "Extra Large" }) do
		window:SetSizePreset(preset)
		for _, textScale in ipairs({ 1, 1.3 }) do
		window:SetTextScale(textScale)
		for _, size in ipairs({ { 1064, 678 }, { 1280, 720 }, { 1920, 1080 }, { 390, 844 }, { 844, 390 }, { 320, 568 } }) do
			Mock.Resize(size[1], size[2])
			local cell = library.CardLayout.CellSize
			local columns = cell.X.Scale == 0.5 and 2 or 1
			local height = cell.Y.Offset
			local content = window.Content.AbsoluteSize
			assert(height * math.ceil(2 / columns) + (columns == 1 and 12 or 0) + 8 <= content.Y + 0.01,
				"both complete cards must fit without scrolling at " .. size[1] .. "x" .. size[2])
			for _, card in ipairs(library.ScriptCards) do
				local function top(obj) return height * obj.Position.Y.Scale + obj.Position.Y.Offset end
				assert(top(card.Title) + card.Title.Size.Y.Offset <= top(card.Description), "title and description must not overlap")
				assert(top(card.Description) + card.Description.Size.Y.Offset <= top(card.Button), "description must not overlap launch")
				for _, child in ipairs({ card.Cover, card.Title, card.Description, card.Button, card.Status }) do
					if child.Visible then
						local top = height * child.Position.Y.Scale + child.Position.Y.Offset
						local bottom = top + height * child.Size.Y.Scale + child.Size.Y.Offset
						assert(top >= 0 and bottom <= height, child.Name .. " must stay inside its card")
					end
				end
			end
		end
	end
	end
	window:SetTextScale(1)
	Mock.Resize(1280, 800)
end)
test("search belongs to searchable pages and restores each query", function()
	window:SelectTab(modules)
	window:SetSearch("flight")
	local settings = window._tabsByName.Settings
	local item = settings:AddModule({ Name = "Appearance" })
	window:SelectTab(settings)
	assert(not window.Toolbar.Visible and not window.SearchHint.Visible and item.Card.Visible)
	assert(window.Search.Text == "" and not Mock.Focused)
	window:SelectTab(modules)
	assert(window.Toolbar.Visible and window.Search.Text == "flight")
	assert(window.Search.PlaceholderText == "Search modules...")
	window:SelectTab(window._tabsByName.Library)
	assert(window.Search.PlaceholderText == "Find a script..." and not window.ActiveFilter.Visible)
end)
test("controls use border strokes, drawn disclosures, SVG navigation and avatar thumbnails", function()
	assert(window.Avatar:IsA("ImageLabel") and window.Avatar.Image:find("AvatarHeadShot", 1, true))
	assert(window._tabsByName.Library.Icon == "library" and window._tabsByName.Settings.Icon == "settings")
	assert(alpha.Chevron:IsA("Frame"))
	assert(window._tabsByName.Library.IconLabel.Text == "")
	assert(window._tabsByName.Library.IconLabel:FindFirstChild("VectorIcon_library"))
	for _, object in ipairs(window.Gui:GetDescendants()) do
		assert(object.Name ~= "AmbientDot", "dots were removed")
		if object:IsA("UIStroke") then assert(object.ApplyStrokeMode == Mock.Env.Enum.ApplyStrokeMode.Border) end
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			assert(object.Text ~= "⌃" and object.Text ~= "⌄" and not object.Text:find("▾", 1, true))
		end
	end
	local binding = window.Keybinds[1]
	assert(binding.Button.Size.X.Offset == 136 and binding.Button.Parent.Size.Y.Offset == 60)
	binding.Button.MouseLeave:Fire()
	assert(binding.Button.BackgroundColor3 ~= binding.Button.Parent.BackgroundColor3, "keycap must stand out from its row")
end)
test("all theme previews apply complete palettes with distinct hover and selection", function()
	local gallery = window:AddThemeGallery(window._tabsByName.Settings)
	assert(#gallery.Tiles == 10 and gallery.Tiles[1].Name == "Black" and gallery.Tiles[2].Name == "Graphite")
	for _, tile in ipairs(gallery.Tiles) do
		tile.Button.Activated:Fire()
		assert(window.ThemeName == tile.Name and window.UIState.ThemeName == tile.Name)
		assert(window.Frame.BackgroundColor3 == UI.Themes[tile.Name].Background)
		assert(window.PlayerName.TextColor3 == UI.Theme.Text and window.BrandName.TextColor3 == UI.Theme.Text)
		assert(window.Avatar.BackgroundColor3 == UI.Theme.Surface)
		for _, other in ipairs(gallery.Tiles) do
			assert(other.Preview.BackgroundColor3 == UI.Themes[other.Name].Background, "previews must not inherit selected theme colors")
			assert(other.Selected.Visible == (other == tile))
			if other ~= tile then
				other.Button.MouseEnter:Fire()
				assert(other.Button.BackgroundColor3 ~= tile.Button.BackgroundColor3)
				other.Button.MouseLeave:Fire()
			end
		end
		window:SelectTab(modules)
		local selected = modules.Button.BackgroundColor3
		home.Button.MouseEnter:Fire()
		assert(home.Button.BackgroundColor3 ~= selected)
		home.Button.MouseLeave:Fire()
	end
	window:SetTheme("Black")
end)
test("editable copy changes presentation without changing tab or option IDs", function()
	local data = { Shared = { Library = "My collection", ["Find a script..."] = "Find my tools", Flight = "Air movement",
		["Movement"] = "Movement tools", ["%d scripts in your collection"] = "%d available tools", ["Current palette: %s"] = "Palette: %s",
		Nearest = "Closest", ["Toggle %s"] = "Shortcut for %s" }, GrassCutter = { Flight = "Grass flight" } }
	local custom = UI.new({ GuiName = "CopyTest", TextData = data, TextScope = "GrassCutter", Animations = false })
	local library = custom:AddTab("Library", "library", "Movement")
	library:AddScriptCard({ Name = "Flight", Description = "Movement" }, function() end)
	custom:SelectTab(library)
	assert(custom.PageTitle.Text == "My collection" and library.Name == "Library")
	assert(custom.Search.PlaceholderText == "Find my tools" and custom.Footer.Text == "1 available tools")
	assert(library.ScriptCards[1].Title.Text == "Grass flight")
	local mods = custom:AddTab("Modules", "modules")
	local feature = mods:AddModule({ Name = "Flight", Description = "Movement" })
	local choice = feature:AddDropdown("Priority", { "Nearest", "Farthest" }, "Nearest", function() end)
	assert(choice.Value == "Nearest", "translated labels must not change option values")
	custom:SelectTab(mods); custom:SetSearch("grass flight"); assert(feature.Card.Visible)
	feature:SetStatus("Toggle Flight"); assert(feature.Status.Text == "Shortcut for Grass flight")
	local second = UI.new({ GuiName = "OtherCopyTest", TextData = { Shared = { Flight = "Other window" } }, Animations = false })
	local oldButton = feature:AddButton("Flight", function() end)
	assert(oldButton.Text == "Grass flight", "windows must retain their own text scopes")
	second:Destroy(); custom:Destroy()
end)
test("destroy disconnects listeners and is safe to repeat", function()
	local connections = table.clone(window._connections)
	window:Destroy(); window:Destroy()
	Mock.Flush()
	assert(window.Gui.Parent == nil and window.OverlayGui.Parent == nil)
	for _, connection in ipairs(connections) do assert(not connection.Connected) end
end)
print(string.format("%d UI behavior tests passed (mock services, no visual rendering)", passed))
