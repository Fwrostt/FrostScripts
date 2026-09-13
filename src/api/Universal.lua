local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

API.UniversalModules = {}

function API.UniversalModules.CreateFlight(options)
	options = options or {}
	local feature = API.CreateFeature(options.Name or "Flight", {
		Speed = options.Speed or 70,
		ToggleKey = options.ToggleKey or Enum.KeyCode.Unknown,
		VerticalSpeed = options.VerticalSpeed or 50,
		Mode = options.Mode or "Character Flight",
		Style = options.Style or "Smooth Flight",
		Direction = options.Direction or "Camera-direction Flight",
		Inertia = options.Inertia or 12,
		FlightHover = options.FlightHover ~= false,
		HoverHeight = options.HoverHeight or 8,
		UpKey = options.UpKey or Enum.KeyCode.Space,
		DownKey = options.DownKey or Enum.KeyCode.LeftControl,
	})
	function feature:_detach(restore)
		if self._velocity then self._velocity:Destroy() end
		if self._orientation then self._orientation:Destroy() end
		if self._attachment then self._attachment:Destroy() end
		if restore and self._humanoid and self._humanoid.Parent and self._controlsCharacter then
			self._humanoid.PlatformStand = self._previousPlatformStand
			self._humanoid.AutoRotate = self._previousAutoRotate
			self._humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if restore and self._root and self._root.Parent then self._root.AssemblyLinearVelocity = Vector3.zero end
		self._velocity, self._orientation, self._attachment = nil, nil, nil
		self._humanoid, self._root, self._controlsCharacter = nil, nil, nil
		self._currentVelocity = Vector3.zero
	end

	function feature:_attach(character, humanoid, characterRoot)
		self:_detach(true)
		humanoid = humanoid or (character and character:FindFirstChildOfClass("Humanoid"))
		characterRoot = characterRoot or (character and character:FindFirstChild("HumanoidRootPart"))
		local root = characterRoot
		if self.Settings.Mode == "Vehicle Flight" then
			local seat = humanoid and humanoid.SeatPart
			root = seat and (seat.AssemblyRootPart or seat)
		end
		if not humanoid or not root or humanoid.Health <= 0 then
			self:SetStatus(self.Settings.Mode == "Vehicle Flight" and "Sit in a vehicle to begin" or "Waiting for character")
			return false
		end
		self._humanoid = humanoid
		self._root = root
		self._previousAutoRotate = humanoid.AutoRotate
		self._previousPlatformStand = humanoid.PlatformStand
		self._controlsCharacter = self.Settings.Mode ~= "Vehicle Flight"
		if self._controlsCharacter then
			humanoid.AutoRotate = false
			humanoid.PlatformStand = true
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "FrostScriptsFlightAttachment"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "FrostScriptsFlightVelocity"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.ForceLimitsEnabled = false
		velocity.VectorVelocity = Vector3.zero
		velocity.Parent = root
		local orientation = Instance.new("AlignOrientation")
		orientation.Name = "FrostScriptsFlightOrientation"
		orientation.Attachment0 = attachment
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.MaxTorque = math.huge
		orientation.Responsiveness = math.max(5, self.Settings.Inertia)
		orientation.Parent = root
		self._attachment = attachment
		self._velocity = velocity
		self._orientation = orientation
		self._mouse = Players.LocalPlayer:GetMouse()
		local raycast = RaycastParams.new()
		raycast.FilterType = Enum.RaycastFilterType.Exclude
		raycast.FilterDescendantsInstances = character and { character } or {}
		self._raycast = raycast
		self._currentVelocity = Vector3.zero
		self:SetStatus(self.Settings.Mode .. " active")
		return true
	end

	function feature:_step(deltaTime)
		local root, humanoid = self._root, self._humanoid
		if not root or not humanoid or not root.Parent or not humanoid.Parent or humanoid.Health <= 0 then
			if root or humanoid then self:_detach(false) end
			if options.CharacterManager then
				local character, nextHumanoid, nextRoot = options.CharacterManager:Get()
				if nextHumanoid and nextRoot and self:_attach(character, nextHumanoid, nextRoot) then return end
			end
			self:SetStatus("Waiting for character")
			return
		end
			local camera = workspace.CurrentCamera
			local look
			if self.Settings.Direction == "Mouse-direction Flight" and self._mouse and self._mouse.Hit then
				look = self._mouse.Hit.Position - root.Position
			elseif self.Settings.Direction == "Character-direction Flight" then
				look = root.CFrame.LookVector
			else
				look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
			end
			local flatLook = Vector3.new(look.X, 0, look.Z)
			flatLook = flatLook.Magnitude > 0.001 and flatLook.Unit or Vector3.new(0, 0, -1)
			local flatRight = Vector3.new(-flatLook.Z, 0, flatLook.X)
			local move = Vector3.zero
			if UserInputService:GetFocusedTextBox() or (options.IsInputCaptured and options.IsInputCaptured()) then
				self._velocity.VectorVelocity = Vector3.zero
				return
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += flatLook end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= flatLook end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += flatRight end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= flatRight end
			if options.GetMoveVector then
				local mobile = options.GetMoveVector()
				if typeof(mobile) == "Vector2" then move += flatRight * mobile.X + flatLook * mobile.Y end
			end
			if move.Magnitude > 1 then move = move.Unit end
			local vertical = 0
			if UserInputService:IsKeyDown(self.Settings.UpKey) then vertical += 1 end
			if UserInputService:IsKeyDown(self.Settings.DownKey) then vertical -= 1 end
			if options.GetVertical then vertical += tonumber(options.GetVertical()) or 0 end
			vertical = math.clamp(vertical, -1, 1)
			local mode = self.Settings.Mode
			if mode == "Levitate" and vertical == 0 then vertical = 0.35 end
			if mode == "Hover" and vertical == 0 then
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), self._raycast)
				if hit then
					vertical = math.clamp((self.Settings.HoverHeight - hit.Distance) / math.max(1, self.Settings.HoverHeight), -1, 1)
				end
			elseif mode == "Float" and vertical == 0 then
				vertical = 0
			elseif not self.Settings.FlightHover and vertical == 0 then
				vertical = -0.12
			end
			local targetVelocity = move * self.Settings.Speed
				+ Vector3.new(0, vertical * self.Settings.VerticalSpeed, 0)
			if self.Settings.Style == "Instant Flight" then
				self._currentVelocity = targetVelocity
			else
				local response = math.max(1, tonumber(self.Settings.Inertia) or 12)
				self._currentVelocity = self._currentVelocity:Lerp(targetVelocity, 1 - math.exp(-response * deltaTime))
			end
			self._velocity.VectorVelocity = self._currentVelocity
			self._orientation.Responsiveness = math.max(5, tonumber(self.Settings.Inertia) or 12)
			self._orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
	end

	function feature:OnEnable()
		local manager = options.CharacterManager
		local function attach(character, humanoid, root)
			if self.Enabled then self:_attach(character, humanoid, root) end
		end
		if manager then
			self:Track(manager:OnAdded(attach, false))
			self:Track(manager:OnRemoving(function() self:_detach(false) end))
			attach(manager:Get())
		else
			local player = Players.LocalPlayer
			attach(player.Character)
			self:Track(player.CharacterAdded:Connect(function(character) attach(character) end))
		end
		if options.UpdateManager then
			self:Track(options.UpdateManager:Register(self.Name .. ":" .. tostring(self), "Render", function(deltaTime)
				self:_step(deltaTime)
			end))
		else
			self:Track(RunService.RenderStepped:Connect(function(deltaTime) self:_step(deltaTime) end))
		end
		return true
	end
	function feature:OnSettingChanged(key)
		if self.Enabled and (key == "Mode") then
			self:Disable()
			self:Enable()
		elseif self.Enabled then
			self:SetStatus(self.Settings.Mode .. " active")
		end
	end
	function feature:OnDisable()
		self:_detach(true)
		self:SetStatus("Flight disabled")
	end
	return feature
end

function API.UniversalModules.CreateAutoClicker(options)
	options = options or {}
	local feature = API.CreateFeature(options.Name or "Auto Clicker", {
		ClicksPerSecond = options.ClicksPerSecond or 8,
		ToggleKey = options.ToggleKey or Enum.KeyCode.Unknown,
	})
	function feature:Click()
		if not VirtualInputManager then return false, "VirtualInputManager unavailable" end
		if UserInputService:GetFocusedTextBox()
			or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			or (options.IsInputCaptured and options.IsInputCaptured()) then return true end
		return pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	function feature:OnEnable(token)
		if not VirtualInputManager then
			self:SetStatus("VirtualInputManager unavailable")
			return false
		end
		task.spawn(function()
			while self.Enabled and self._token == token do
				local started = os.clock()
				local ok, err = self:Click()
				if not ok then
					self:Disable()
					self:SetStatus(tostring(err))
					break
				end
				local rate = math.clamp(tonumber(self.Settings.ClicksPerSecond) or 8, 1, 30)
				task.wait(math.max(0.02, (1 / rate) - (os.clock() - started)))
			end
		end)
		self:SetStatus("Clicking")
		return true
	end
	function feature:OnDisable()
		self:SetStatus("Stopped")
	end
	return feature
end
