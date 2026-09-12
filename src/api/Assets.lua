-- Optional GitHub image bridge. Executable source never uses the filesystem.
local imageCache = {}
local extensions = { "png", "jpg", "jpeg" }

function API.ResolveCover(entry)
	if type(entry) ~= "table" or type(entry.EntryPoint) ~= "string" then return nil, "Invalid catalog entry" end
	if type(entry.Image) == "table" and entry.Image.Enabled == false then return nil, "Disabled" end
	local directory = entry.EntryPoint:match("^(games/[%w_/-]+)/[%w_-]+%.lua$")
	if not directory or directory:find("..", 1, true) then return nil, "Invalid game directory" end
	local register = getcustomasset or getsynasset
	if type(writefile) ~= "function" or type(register) ~= "function" then
		return nil, "GitHub covers require writefile and getcustomasset support"
	end
	local base = API.GetConfig().BaseUrl .. "/" .. directory .. "/icon."
	if imageCache[base] then return imageCache[base] end
	for _, extension in ipairs(extensions) do
		local ok, bytes = pcall(function() return game:HttpGet(base .. extension) end)
		if ok and type(bytes) == "string" and #bytes <= 4 * 1024 * 1024 then
			local png = extension == "png" and #bytes >= 24 and bytes:sub(1, 8) == "\137PNG\r\n\26\n"
			local jpeg = extension ~= "png" and #bytes >= 4 and bytes:sub(1, 3) == "\255\216\255"
			if png or jpeg then
				-- Content-derived names prevent Roblox reusing an older image after an upload.
				local hash = 5381
				for i = 1, #bytes do hash = (hash * 33 + bytes:byte(i)) % 4294967296 end
				local filename = "FrostScripts_image_" .. directory:gsub("/", "_") .. "_" .. string.format("%08x", hash) .. "." .. extension
				local saved, content = pcall(function()
					writefile(filename, bytes)
					return register(filename)
				end)
				if saved and type(content) == "string" and content ~= "" then
					imageCache[base] = content
					return content
				end
			end
		end
	end
	return nil, "No supported icon found"
end
