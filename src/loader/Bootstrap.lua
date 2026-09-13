-- Generated entry points share this bootstrap. Configure once before running.
local env = (type(getgenv) == "function" and getgenv()) or _G
local config = env.FrostScriptsConfig or {}
config = table.clone(config)
config.BaseUrl = config.BaseUrl or "https://raw.githubusercontent.com/Fwrostt/FrostScripts/main"
assert(type(loadstring) == "function", "FrostScripts requires loadstring")
assert(config.Mode == nil or config.Mode == "http", "FrostScripts loads only from GitHub over HTTPS")
assert(type(config.BaseUrl) == "string" and config.BaseUrl:gsub("/+$", ""):match("^https://raw%.githubusercontent%.com/Fwrostt/FrostScripts/[%w%._/%-]+$"),
	"Use a raw.githubusercontent.com/Fwrostt/FrostScripts branch or commit URL")
local ok, source = pcall(function()
	local fresh = tostring(os.time()) .. "_" .. tostring(math.floor(os.clock() * 1000000))
	return game:HttpGet(config.BaseUrl:gsub("/+$", "") .. "/dist/api/FrostScriptsAPI.lua?frost=" .. fresh)
end)
assert(ok, "FrostScriptsAPI download failed: " .. tostring(source)
	.. ". The GitHub repository and raw source files must be publicly readable.")
local chunk, compileError = loadstring(source, "@FrostScriptsAPI")
assert(chunk, compileError)
local API = chunk()
assert(type(API) == "table" and API.Version == "2.0.0" and type(API.Configure) == "function",
	"Incompatible FrostScriptsAPI; publish all files from the same build")
API.Configure(config)
return API.OpenLauncher()
