-- Optional GitHub image bridge. Executable source never uses the filesystem.
local imageCache = {}
local extensions = { "png", "jpg", "jpeg" }

local function resolveImage(path, cacheKey)
	if type(path) ~= "string" or not path:match("^[%w_/%-%.]+$")
		or path:find("..", 1, true) or path:sub(1, 1) == "/" then
		return nil, "Invalid image path"
	end
	local extension = path:lower():match("%.(png)$") or path:lower():match("%.(jpe?g)$")
	if not extension then return nil, "Only PNG and JPEG images are supported" end
	local register = getcustomasset or getsynasset
	if type(writefile) ~= "function" or type(register) ~= "function" then
		return nil, "GitHub images require writefile and getcustomasset support"
	end
	local url = API.GetConfig().BaseUrl .. "/" .. path
	cacheKey = cacheKey or url
	if imageCache[cacheKey] then return imageCache[cacheKey] end
	local ok, bytes = pcall(function() return game:HttpGet(url) end)
	if not ok or type(bytes) ~= "string" or #bytes > 4 * 1024 * 1024 then return nil, "Image download failed" end
	local png = extension == "png" and #bytes >= 24 and bytes:sub(1, 8) == "\137PNG\r\n\26\n"
	local jpeg = extension ~= "png" and #bytes >= 4 and bytes:sub(1, 3) == "\255\216\255"
	if not png and not jpeg then return nil, "Invalid image data" end
	local hash = 5381
	for index = 1, #bytes do hash = (hash * 33 + bytes:byte(index)) % 4294967296 end
	local filename = "FrostScripts_image_" .. path:gsub("[^%w_-]", "_") .. "_" .. string.format("%08x", hash) .. "." .. extension
	local saved, content = pcall(function()
		writefile(filename, bytes)
		return register(filename)
	end)
	if not saved or type(content) ~= "string" or content == "" then return nil, "Image registration failed" end
	imageCache[cacheKey] = content
	return content
end

function API.ResolveAsset(path)
	return resolveImage(path)
end

function API.ResolveCover(entry)
	if type(entry) ~= "table" or type(entry.EntryPoint) ~= "string" then return nil, "Invalid catalog entry" end
	if type(entry.Image) == "table" and entry.Image.Enabled == false then return nil, "Disabled" end
	local directory = entry.EntryPoint:match("^(games/[%w_/-]+)/[%w_-]+%.lua$")
	if not directory or directory:find("..", 1, true) then return nil, "Invalid game directory" end
	local base = API.GetConfig().BaseUrl .. "/" .. directory .. "/icon."
	if imageCache[base] then return imageCache[base] end
	for _, extension in ipairs(extensions) do
		local content = resolveImage(directory .. "/icon." .. extension, base)
		if content then return content end
	end
	return nil, "No supported icon found"
end
