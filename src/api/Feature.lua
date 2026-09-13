local Feature = {}
Feature.__index = Feature
API.Feature = Feature

function API.CreateFeature(name, settings)
	return setmetatable({
		Name = name, Settings = settings or {}, Enabled = false, Status = "Ready",
		NextRun = 0, _token = 0, _connections = {},
	}, Feature)
end

function Feature:AddSetting(key, default)
	if self.Settings[key] == nil then self.Settings[key] = default end
	return self.Settings[key]
end

function Feature:SetSetting(key, value)
	assert(self.Settings[key] ~= nil, "Unknown " .. self.Name .. " setting: " .. tostring(key))
	self.Settings[key] = value
	if self.OnSettingChanged then self:OnSettingChanged(key, value) end
end

function Feature:_syncControl()
	local control = self._control
	if not control then return end
	control:SetEnabled(self.Enabled)
	if control.Toggle then control.Toggle:SetValue(self.Enabled, true) end
	control:SetStatus(self.Status)
end

function Feature:BindControl(control)
	self._control = control
	self:_syncControl()
	return self
end

function Feature:SetStatus(status)
	local value = tostring(status or "")
	if value == self.Status then return end
	self.Status = value
	self:_syncControl()
	if self.OnStatusChanged then self.OnStatusChanged(value) end
end

function Feature:Track(connection)
	if connection then table.insert(self._connections, connection) end
	return connection
end

function Feature:ClearConnections()
	for _, connection in ipairs(self._connections) do pcall(function() connection:Disconnect() end) end
	table.clear(self._connections)
end

function Feature:Enable()
	if self.Enabled then return true end
	self.Enabled = true
	self._token += 1
	local ok, result = pcall(function()
		if self.OnStateChanged then self.OnStateChanged(true) end
		if self.OnEnable then return self:OnEnable(self._token) end
	end)
	if not ok or result == false then
		self:Disable()
		self:SetStatus(ok and "Unable to start" or tostring(result))
		return false
	end
	self:_syncControl()
	return true
end

function Feature:Disable()
	if not self.Enabled then return end
	self.Enabled = false
	self._token += 1
	self:ClearConnections()
	local ok, err = pcall(function()
		if self.OnDisable then self:OnDisable() end
	end)
	local stateOK, stateError = pcall(function()
		if self.OnStateChanged then self.OnStateChanged(false) end
	end)
	if not ok or not stateOK then self.Status = tostring(not ok and err or stateError) end
	self:_syncControl()
end

function Feature:SetEnabled(enabled)
	if enabled then return self:Enable() end
	self:Disable()
	return true
end

function Feature:Destroy()
	self:Disable()
	self:ClearConnections()
	self._control = nil
end
