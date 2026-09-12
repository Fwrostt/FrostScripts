local translators = {}
function API.Text(value, scope)
	scope = scope or "Shared"
	if not translators[scope] then translators[scope] = makeText(API.TextData, scope) end
	return translators[scope](value)
end

function API.ReloadText()
	local ok, result = pcall(API.LoadModule, "config/Text.lua", nil, true)
	if ok and type(result.Shared) == "table" then
		for _, section in pairs(result) do
			if type(section) ~= "table" then return false, "Text sections must be tables" end
			for key, value in pairs(section) do
				if type(key) ~= "string" or type(value) ~= "string" then return false, "Text entries must have string keys and values" end
			end
		end
		API.TextData = result
		table.clear(translators)
		return true
	end
	return false, ok and "Text.lua must return a Shared table" or result
end
