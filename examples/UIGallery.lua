-- A game-independent gallery for checking controls in a Roblox client.
local base = "https://raw.githubusercontent.com/Fwrostt/FrostScripts/main"
local API = loadstring(game:HttpGet(base .. "/dist/api/FrostScriptsAPI.lua"))()
API.Configure({ BaseUrl = base })
local UI = API.LoadUI()
local window = UI.new({ Name = "FrostScripts", Game = "UI Gallery", GuiName = "FrostGallery", OverlayName = "FrostGalleryOverlays" })
local home = window:AddTab("Overview", "H", "A quieter workspace. Everything within reach.")
home:AddModule({ Name = "Welcome to Frost", Accent = true, Collapsible = false })
	:AddParagraph("Made for your session", "Search controls with Ctrl K, filter active modules, or choose your own colors in Appearance.")
local controls = window:AddTab("Controls", "C", "Explore every control")
local feature = API.CreateFeature("Example feature", { Speed = 50 })
local module = controls:AddModule({ Name = "Example feature", Feature = feature, Toggleable = true,
	Callback = function(enabled) feature:SetEnabled(enabled) end, Expanded = true })
module:AddSlider("Speed", 0, 100, 50, function(value) feature:SetSetting("Speed", value) end)
module:AddDropdown("Priority", { "Nearest", "Farthest", "Highest value" }, "Nearest", function() end)
module:AddMultiDropdown("Colors", { "Cyan", "Rose", "Amber" }, { Cyan = true }, function() end)
module:AddNumberInput("Budget", 100, function() end, { Min = 0, Max = 1000 })
module:AddButton("Show notification", function()
	window:Notify({ Title = "All set", Text = "Your workspace is ready.", Type = "Success" })
end)
local settings = window:AddTab("Appearance", "S", "Choose your colors and layout")
window:AddClientSettings(settings)
local shortcuts = window:AddTab("Shortcuts", "K", "Make it feel familiar")
local toggleKey = Enum.KeyCode.RightShift
shortcuts:AddKeybind({ Name = "Show or hide", Get = function() return toggleKey end,
	Set = function(key) toggleKey = key end, OnPressed = function() window:Toggle() end, AllowClear = false })
window:SelectTab(home)
return window
