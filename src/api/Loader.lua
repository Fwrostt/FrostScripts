-- Each API instance owns its configuration and module cache.
local settings = { BaseUrl = "https://raw.githubusercontent.com/Fwrostt/FrostScripts/main" }
local cache, loading = {}, {}
local games = {}
for _, entry in ipairs(API.Catalog) do
	assert(type(entry.Id) == "string" and not games[entry.Id], "Catalog IDs must be unique strings")
	assert(type(entry.Name) == "string" and type(entry.Description) == "string", "Catalog entries need a name and description")
	assert(type(entry.EntryPoint) == "string" and entry.EntryPoint:match("^games/[%w_/-]+%.lua$"), "EntryPoint must be a Lua file under games/")
	games[entry.Id] = entry
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end

function API.Configure(options)
	options = options or {}
	local base = options.BaseUrl or settings.BaseUrl
	assert(options.Mode == nil or options.Mode == "http", "FrostScripts loads only from GitHub over HTTPS")
	assert(type(base) == "string", "BaseUrl must be a string")
	base = base:gsub("/+$", "")
	assert(base:match("^https://raw%.githubusercontent%.com/Fwrostt/FrostScripts/[%w%._/%-]+$"),
		"Use a raw.githubusercontent.com/Fwrostt/FrostScripts branch or commit URL")
	assert(next(loading) == nil, "Cannot change configuration while a module is loading")
	settings = { BaseUrl = base }
	table.clear(cache)
	return API
end

function API.GetConfig()
	return table.clone(settings)
end

function API.LoadModule(path, expectedMethod, fresh, ...)
	assert(type(path) == "string" and path:match("^[%w_/%-%.]+%.lua$")
		and not path:find("..", 1, true) and path:sub(1, 1) ~= "/", "Invalid module path")
	if not fresh and cache[path] ~= nil then
		assert(not expectedMethod or type(cache[path][expectedMethod]) == "function", path .. " has an incompatible interface")
		return cache[path]
	end
	assert(not loading[path], "Circular module load: " .. path)
	assert(type(loadstring) == "function", "FrostScripts requires loadstring")
	loading[path] = true
	local args = table.pack(...)
	local ok, result = pcall(function()
		local source = game:HttpGet(settings.BaseUrl .. "/" .. path)
		assert(type(source) == "string" and #source > 0, "Empty source for " .. path)
		local chunk, compileError = loadstring(source, "@FrostScripts/" .. path)
		assert(chunk, compileError)
		local value = chunk(table.unpack(args, 1, args.n))
		assert(type(value) == "table", path .. " must return a table")
		assert(not expectedMethod or type(value[expectedMethod]) == "function", path .. " has an incompatible interface")
		return value
	end)
	loading[path] = nil
	assert(ok, "FrostScripts could not load " .. path .. ": " .. tostring(result))
	if not fresh then cache[path] = result end
	return result
end

function API.LoadUI()
	-- Fresh UI factories isolate window theme state between game suites.
	local library = API.LoadModule("dist/ui/UI.lua", "new", true)
	local createWindow = library.CreateWindow
	if type(createWindow) == "function" then
		library.CreateWindow = function(self, options)
			options = table.clone(options or {})
			options.UIState = API.UIState
			options.ResolveCover = API.ResolveCover
			if not options.IsLauncher then options.OnReturnToLibrary = API.ReturnToLauncher end
			return createWindow(self, options)
		end
	end
	return library
end

function API.UnloadGame()
	if API.ActiveSuite then
		API.ActiveSuite:Unload()
		API.ActiveSuite, API.ActiveGame = nil, nil
	end
end

function API.RunGame(name)
	local entry = games[name]
	assert(entry, "Unsupported script: " .. tostring(name))
	assert(not API._gameLoading, "Another script is still loading")
	assert(#(entry.PlaceIds or {}) == 0 or table.find(entry.PlaceIds, game.PlaceId), "Open " .. entry.Name .. " in its supported game first")
	API._gameLoading = true
	local ok, suite = pcall(function()
		API.UnloadGame()
		return API.LoadModule(entry.EntryPoint, "Unload", true, API)
	end)
	API._gameLoading = false
	assert(ok, suite)
	API.ActiveSuite, API.ActiveGame = suite, name
	return suite
end

function API.GetGames()
	local names = {}
	for _, entry in ipairs(API.Catalog) do table.insert(names, entry.Id) end
	return names
end

function API.GetCatalog()
	return copy(API.Catalog)
end

function API.OpenLauncher()
	return API.LoadModule("dist/launcher/App.lua", "Unload", true, API)
end
