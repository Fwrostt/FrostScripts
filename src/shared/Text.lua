-- A presentation-only catalog: translated labels never replace gameplay identifiers.
return function(catalog, scope)
	local values, templates, cache = {}, {}, {}
	for _, section in ipairs({ "Shared", scope }) do
		for key, value in pairs(type(catalog[section]) == "table" and catalog[section] or {}) do
			if type(key) == "string" and type(value) == "string" then values[key] = value end
		end
	end
	local specifier = "%%[-+ #0%d%.]*[cdeEfgGiouXxsq]"
	local function escape(value) return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")) end
	for source, replacement in pairs(values) do
		if source ~= replacement and source:find(specifier) then
			local pattern, cursor, count = "^", 1, 0
			while true do
				local first, last = source:find(specifier, cursor)
				if not first then break end
				pattern ..= escape(source:sub(cursor, first - 1)) .. "(.-)"
				cursor, count = last + 1, count + 1
			end
			table.insert(templates, { Pattern = pattern .. escape(source:sub(cursor)) .. "$", Replacement = replacement, Length = #source })
		end
	end
	table.sort(templates, function(a, b) return a.Length > b.Length end)
	local cacheCount = 0
	return function(value)
		if type(value) ~= "string" then return value end
		if values[value] ~= nil then return values[value] end
		if cache[value] then return cache[value] end
		for _, template in ipairs(templates) do
			local captures = table.pack(value:match(template.Pattern))
			if captures[1] ~= nil then
				local index = 0
				local result = template.Replacement:gsub(specifier, function()
					index += 1
					return captures[index] or ""
				end)
				cacheCount += 1
				if cacheCount > 256 then table.clear(cache); cacheCount = 1 end
				cache[value] = result
				return result
			end
		end
		return value
	end
end
