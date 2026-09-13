local API = ...
assert(type(API) == "table", "Start with dist/launchers/Loader.lua")
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.FrostScriptsLauncher then env.FrostScriptsLauncher:Unload() end
if type(env.FrostScriptsUIPreferences) == "table" then
	local persistent = { Sounds = true, SoundVolume = true, NotificationsEnabled = true,
		ModuleNotificationsEnabled = true, NotificationPosition = true,
		CustomCursorEnabled = true, VisibilityKey = true }
	for key in pairs(API.UIState) do
		local old = env.FrostScriptsUIPreferences
		local currentDesign = old.DesignRevision == API.UIState.DesignRevision
		if key ~= "DesignRevision" and (currentDesign or persistent[key]) and old[key] ~= nil then
			API.UIState[key] = old[key]
		end
	end
end
env.FrostScriptsUIPreferences = API.UIState
local UI = API.LoadUI()
local window = UI.new({
	Name = "FrostScripts", Game = "YOUR SCRIPT LIBRARY", IsLauncher = true,
	GuiName = "FrostScriptsLibrary", OverlayName = "FrostScriptsLibraryOverlays",
})
local launcher = { Window = window, Cards = {}, Busy = false, Unloaded = false }
local library = window:AddTab("Library", "library", "Pick your world. Make it yours.")
library.ItemNoun = "scripts"
local settings = window:AddTab("UI Settings", "settings", "The look, motion, and sound of FrostScripts")
window:AddClientSettings(settings)

function launcher:Launch(id)
	if self.Busy or self.Unloaded then return false end
	self.Busy = true
	local card = assert(self.Cards[id], "Unknown script card")
	card:SetLaunchState("Loading", "Preparing your workspace…")
	for _, item in pairs(self.Cards) do item:SetLaunchEnabled(false) end
	local ok, result = pcall(API.RunGame, id)
	self.Busy = false
	if self.Unloaded then
		if ok then API.UnloadGame() end
		return false
	end
	for _, item in pairs(self.Cards) do item:SetLaunchEnabled(true) end
	if ok then
		card:SetLaunchState("Ready", "Workspace opened")
		window:SetVisible(false)
		-- The game window owns visibility shortcuts and the floating reopen button.
		window.InputEnabled = false
		window.Launcher.Visible = false
	else
		card:SetLaunchState("Retry", tostring(result))
		window:Notify({ Title = "Script could not start", Text = tostring(result), Type = "Error", Duration = 8 })
	end
	return ok, result
end

for _, entry in ipairs(API.GetCatalog()) do
	launcher.Cards[entry.Id] = library:AddScriptCard(entry, function()
		task.spawn(function() launcher:Launch(entry.Id) end)
	end)
end

API.ReturnToLauncher = function()
	if launcher.Unloaded or launcher.Busy then return end
	API.UnloadGame()
	window.InputEnabled = true
	window:ApplyPreferences()
	window:SetVisible(true)
	for _, card in pairs(launcher.Cards) do card:SetLaunchState("Launch") end
end

function launcher:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	API.UnloadGame()
	window:Destroy()
	if env.FrostScriptsLauncher == self then env.FrostScriptsLauncher = nil end
end

env.FrostScriptsLauncher = launcher
window:SelectTab(library)
return launcher
