-- Executed by tools/check.py with the built API and a mocked Roblox boundary.
local requests, sources = {}, {}
local focused, clicks = false, 0
local services = { Players = {}, RunService = {},
	UserInputService = { GetFocusedTextBox = function() return focused end, IsMouseButtonPressed = function() return false end },
	VirtualInputManager = { SendMouseButtonEvent = function() clicks += 1 end },
}
local sandbox = setmetatable({
	Enum = { KeyCode = { V = "V" }, UserInputType = { MouseButton1 = "MouseButton1" } },
	game = {
		GetService = function(_, name) return services[name] end,
		HttpGet = function(_, url)
			requests[url] = (requests[url] or 0) + 1
			assert(sources[url], "test download failure")
			return sources[url]
		end,
	},
}, { __index = getfenv() })
local apiChunk = assert(loadstring(API_SOURCE, "@FrostScriptsAPI"))
setfenv(apiChunk, sandbox)
local API = apiChunk()
local passed = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end

test("feature start failure rolls back and preserves reason", function()
	local f = API.CreateFeature("Failure", { Rate = 1 })
	local disconnected, cleaned = false, false
	function f:OnEnable()
		self:Track({ Disconnect = function() disconnected = true end })
		error("start failed")
	end
	function f:OnDisable() cleaned = true end
	assert(f:Enable() == false)
	assert(not f.Enabled and disconnected and cleaned)
	assert(f.Status:find("start failed", 1, true))
end)

test("control binding preserves lifecycle callbacks and false settings", function()
	local f = API.CreateFeature("Bound", { Flag = false })
	local state, status, calls = nil, nil, 0
	local control = {
		SetEnabled = function(_, value) state = value end,
		SetStatus = function(_, value) status = value end,
		Toggle = { SetValue = function() end },
	}
	f.OnStateChanged = function() calls += 1 end
	f:BindControl(control)
	assert(f:AddSetting("Flag", true) == false)
	f:SetSetting("Flag", true)
	assert(f:Enable() and state == true and calls == 1)
	local token = f._token
	f:Enable()
	assert(f._token == token and calls == 1)
	f:SetStatus("Working")
	assert(status == "Working")
	f:Disable()
	f:Disable()
	assert(state == false and calls == 2 and f._token > token)
end)

test("disable errors still disconnect and synchronize", function()
	local f = API.CreateFeature("Stop", {})
	local disconnected = false
	f:Enable()
	f:Track({ Disconnect = function() disconnected = true end })
	function f:OnDisable() error("cleanup failed") end
	f:Disable()
	assert(disconnected and not f.Enabled and f.Status:find("cleanup failed", 1, true))
end)

test("formatting handles decimals, negatives, compact suffixes", function()
	assert(API.FormatNumber(1234567) == "1,234,567")
	assert(API.FormatNumber(-1250, true) == "-1.25K")
	assert(API.FormatNumber(1000000, true) == "1M")
	assert(API.FormatNumber(0) == "0")
	assert(API.FormatDistance(math.huge) == "far")
end)

test("scope cleans once and immediately handles late resources", function()
	local scope, calls = API.CreateScope(), 0
	scope:Track(function() calls += 1 end)
	scope:Destroy()
	scope:Destroy()
	scope:Track(function() calls += 1 end)
	assert(calls == 2)
end)

test("HTTP loader caches and fresh loads bypass cache", function()
	API.Configure({ BaseUrl = "https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/" })
	sources["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/sample.lua"] = "return { new = function() end }"
	local a = API.LoadModule("sample.lua", "new")
	assert(a == API.LoadModule("sample.lua", "new"))
	assert(a ~= API.LoadModule("sample.lua", "new", true))
	assert(requests["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/sample.lua"] == 2)
	assert(not pcall(API.LoadModule, "sample.lua", "missingMethod"))
	local config = API.GetConfig()
	config.BaseUrl = "changed"
	assert(API.GetConfig().BaseUrl == "https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref")
end)

test("shared click method preserves direct game calls and respects typing", function()
	local clicker = API.UniversalModules.CreateAutoClicker()
	assert(clicker:Click() and clicks == 2)
	focused = true
	assert(clicker:Click() and clicks == 2)
	focused = false
end)

test("failed downloads and compile errors can be retried", function()
	assert(not pcall(API.LoadModule, "retry.lua"))
	sources["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/retry.lua"] = "invalid code !"
	assert(not pcall(API.LoadModule, "retry.lua"))
	sources["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/retry.lua"] = "return { ready = true }"
	assert(API.LoadModule("retry.lua").ready)
end)

test("invalid exports, paths, protocols and games fail clearly", function()
	sources["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/bad.lua"] = "return nil"
	assert(not pcall(API.LoadModule, "bad.lua"))
	sources["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/bad.lua"] = "return {}"
	assert(not pcall(API.LoadModule, "bad.lua", "new"))
	assert(not pcall(API.LoadModule, "../secret.lua"))
	assert(not pcall(API.LoadModule, "/secret.lua"))
	assert(not pcall(API.Configure, { BaseUrl = "http://example.test" }))
	assert(not pcall(API.RunGame, "Unknown"))
end)

test("GitHub UI and game selection load exactly one game", function()
	API.Configure({ BaseUrl = "https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref" })
	sources["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/dist/ui/UI.lua"] = "return { new = function() end }"
	assert(type(API.LoadUI().new) == "function")
	assert(API.LoadUI() ~= API.LoadUI(), "UI loads must remain isolated after relocation")
	sources["https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref/games/GrassCutter/main.lua"] = "local api = ...; return { Version = api.Version, Unload = function() end }"
	assert(API.RunGame("GrassCutter").Version == API.Version)
	assert(API.GetConfig().BaseUrl == "https://raw.githubusercontent.com/Fwrostt/FrostScripts/test-ref")
	assert(#API.GetGames() == 2)
end)
print(string.format("%d API tests passed", passed))
