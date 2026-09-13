-- Exercise the real entry point -> API -> launcher -> UI chain with mocked HTTPS.
local session, requests, requestedUrls = { FrostScriptsUIPreferences = {
	ThemeName = "Frost", Sounds = false, ModuleNotificationsEnabled = false, NotificationPosition = "Top Left",
} }, {}, {}
local prefix = "https://raw.githubusercontent.com/Fwrostt/FrostScripts/main/"
Mock.Env.getgenv = function() return session end
Mock.Env.loadstring = function(source, name)
	local fn, err = loadstring(source, name)
	if fn then setfenv(fn, Mock.Env) end
	return fn, err
end
Mock.Env.game.HttpGet = function(_, url)
	assert(url:sub(1, #prefix) == prefix, "Unexpected script host: " .. url)
	local path = url:sub(#prefix + 1):match("^[^?]+")
	requests[path] = (requests[path] or 0) + 1
	requestedUrls[path] = url
	return assert(SOURCES[path], "No mock source for " .. path)
end
local function suiteSource(name)
	return 'local API = ...; local UI = API.LoadUI(); local window = UI.new({ GuiName = "' .. name .. '" }); '
		.. 'return { Window = window, Unload = function(self) self.Stopped = true; window:Destroy() end }'
end
SOURCES["games/GrassCutter/main.lua"] = suiteSource("TestGrass")
SOURCES["games/NeedleInHay/main.lua"] = suiteSource("TestNeedle")
SOURCES["games/Universal/main.lua"] = suiteSource("TestUniversal")
local main = assert(Mock.Env.loadstring(SOURCES["dist/launchers/Loader.lua"]))
local launcher = main()
Mock.Flush()
assert(launcher.Window.ActiveTab.Name == "Library")
assert(launcher.Window.BrandSubtitle.Text == "Cheating is Fun")
assert(launcher.Window.PageSubtitle.Text == "Pick your script according to your game.")
assert(launcher.Cards.Universal.Status.Text == "Works in every game")
assert(not launcher.Window.ModuleNotificationsEnabled and launcher.Window.NotificationPosition == "Top Left")
assert(launcher.Window.ThemeName == "Black" and not launcher.Window.Sounds, "new design resets the legacy theme while preserving other preferences")
launcher.Window:SetTheme("Graphite")
assert(requests["config/Text.lua"] == 1, "main loader must fetch editable text from GitHub")
assert(requestedUrls["config/Text.lua"]:find("?frost=", 1, true), "editable text must bypass HTTP caches")
assert(requests["dist/api/FrostScriptsAPI.lua"] == 1)
assert(requests["dist/launcher/App.lua"] == 1)
assert(requests["dist/ui/UI.lua"] == 1)
assert(not requests["games/GrassCutter/main.lua"] and not requests["games/NeedleInHay/main.lua"]
	and not requests["games/Universal/main.lua"], "Opening the library must not run a game")
print("PASS single main entry fetches only API, launcher, and UI from GitHub")

launcher.Window:SetSounds(false)
launcher.Window:SetBackgroundAnimations(false)
local ok, grass = launcher:Launch("GrassCutter")
assert(ok and not launcher.Window.Visible and launcher.Window.InputEnabled == false)
assert(requests["games/GrassCutter/main.lua"] == 1 and not requests["games/NeedleInHay/main.lua"])
assert(grass.Window.Sounds == false and grass.Window.BackgroundAnimations == false and grass.Window.ThemeName == "Graphite")
assert(not grass.Window.ModuleNotificationsEnabled and grass.Window.NotificationPosition == "Top Left")
local back = grass.Window.Gui:FindFirstChildWhichIsA("TextButton", true)
for _, object in ipairs(grass.Window.Gui:GetDescendants()) do
	if object.Name == "ReturnToLibrary" then back = object; break end
end
assert(back.Name == "ReturnToLibrary")
back.Activated:Fire()
assert(grass.Stopped and launcher.Window.Visible and launcher.Window.InputEnabled)
print("PASS selected game loads alone and returns to library with UI preferences preserved")

SOURCES["games/NeedleInHay/main.lua"] = 'error("test startup failed")'
local failed = launcher:Launch("NeedleInHay")
assert(not failed and not launcher.Busy and launcher.Window.Visible)
assert(launcher.Cards.NeedleInHay.Button.Text == launcher.Window:Text("Try again"))
SOURCES["games/NeedleInHay/main.lua"] = suiteSource("TestNeedle")
local retried, needle = launcher:Launch("NeedleInHay")
assert(retried and requests["games/NeedleInHay/main.lua"] == 2)
print("PASS failed script startup keeps the launcher usable and supports retry")

local replacement = main()
assert(launcher.Unloaded and needle.Stopped)
assert(replacement ~= launcher and session.FrostScriptsLauncher == replacement)
assert(replacement.Window.Sounds == false and replacement.Window.ThemeName == "Graphite")
replacement:Unload()
assert(session.FrostScriptsLauncher == nil)
print("PASS rerunning the one loader unloads the prior session")
print("4 launcher integration tests passed (mock HTTPS and Roblox services)")
