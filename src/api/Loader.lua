-- Each API instance owns its configuration and module cache.
local settings = { Mode = "http", BaseUrl = "", LocalRoot = "FrostScripts" }
local cache, loading = {}, {}
local games = { GrassCutter = "games/GrassCutter/main.lua", NeedleInHay = "games/NeedleInHay/main.lua" }

function API.Configure(options)
	options = options or {}
	local mode = options.Mode or settings.Mode
	assert(mode == "http" or mode == "local", "Mode must be http or local")
	local base = options.BaseUrl or settings.BaseUrl
	local root = options.LocalRoot or settings.LocalRoot
	assert(type(base) == "string" and type(root) == "string", "Source paths must be strings")
	assert(mode ~= "http" or base:match("^https://"), "Set FrostScriptsConfig.BaseUrl to your HTTPS raw project URL")
	assert(next(loading) == nil, "Cannot change configuration while a module is loading")
	settings = { Mode = mode, BaseUrl = base:gsub("/+$", ""), LocalRoot = root:gsub("[/\\]+$", "") }
	table.clear(cache)
	return API
end

function API.GetConfig()
	return table.clone(settings)
end

function API.LoadModule(path, expectedMethod, fresh, ...)
	assert(type(path) == "string" and path:match("^[%w_/%-%.]+%.lua$")
		and not path:find("..", 1, true) and path:sub(1, 1) ~= "/", "Invalid module path")
	if not fresh and cache[path] ~= nil then return cache[path] end
	assert(not loading[path], "Circular module load: " .. path)
	assert(type(loadstring) == "function", "FrostScripts requires loadstring")
	loading[path] = true
	local args = table.pack(...)
	local ok, result = pcall(function()
		local source
		if settings.Mode == "local" then
			assert(type(readfile) == "function", "Local mode requires readfile")
			source = readfile(settings.LocalRoot .. "/" .. path)
		else
			assert(settings.BaseUrl:match("^https://"), "Configure an HTTPS BaseUrl before loading modules")
			source = game:HttpGet(settings.BaseUrl .. "/" .. path)
		end
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
	return API.LoadModule("UI.lua", "new", true)
end

function API.RunGame(name)
	assert(games[name], "Unsupported game: " .. tostring(name) .. ". Choose GrassCutter or NeedleInHay.")
	return API.LoadModule(games[name], "Unload", true, API)
end

function API.GetGames()
	return { "GrassCutter", "NeedleInHay" }
end
