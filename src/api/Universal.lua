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
		ToggleKey = options.ToggleKey or Enum.KeyCode.F,
		VerticalSpeed = options.VerticalSpeed or 50,
		UpKey = options.UpKey or Enum.KeyCode.Space,
		DownKey = options.DownKey or Enum.KeyCode.LeftControl,
	})
	function feature:OnEnable()
		local player = Players.LocalPlayer
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then return false end
		self._humanoid = humanoid
		self._root = root
		self._previousAutoRotate = humanoid.AutoRotate
		self._previousPlatformStand = humanoid.PlatformStand
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
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
		orientation.Responsiveness = 18
		orientation.Parent = root
		self._attachment = attachment
		self._velocity = velocity
		self._orientation = orientation
		self:Track(RunService.RenderStepped:Connect(function()
			if not root.Parent or not humanoid.Parent or humanoid.Health <= 0 then
				self:Disable()
				return
			end
			local camera = workspace.CurrentCamera
			local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
			local flatLook = Vector3.new(look.X, 0, look.Z)
			flatLook = flatLook.Magnitude > 0.001 and flatLook.Unit or Vector3.new(0, 0, -1)
			local flatRight = Vector3.new(-flatLook.Z, 0, flatLook.X)
			local move = Vector3.zero
			if UserInputService:GetFocusedTextBox() or (options.IsInputCaptured and options.IsInputCaptured()) then
				velocity.VectorVelocity = Vector3.zero
				return
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += flatLook end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= flatLook end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += flatRight end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= flatRight end
			if move.Magnitude > 1 then move = move.Unit end
			local vertical = 0
			if UserInputService:IsKeyDown(self.Settings.UpKey) then vertical += 1 end
			if UserInputService:IsKeyDown(self.Settings.DownKey) then vertical -= 1 end
			velocity.VectorVelocity = move * self.Settings.Speed + Vector3.new(0, vertical * self.Settings.VerticalSpeed, 0)
			orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
		end))
		self:SetStatus("WASD flight active")
		return true
	end
	function feature:OnDisable()
		if self._velocity then self._velocity:Destroy() end
		if self._orientation then self._orientation:Destroy() end
		if self._attachment then self._attachment:Destroy() end
		if self._humanoid and self._humanoid.Parent then
			self._humanoid.PlatformStand = self._previousPlatformStand
			self._humanoid.AutoRotate = self._previousAutoRotate
			self._humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if self._root and self._root.Parent then
			self._root.AssemblyLinearVelocity = Vector3.zero
		end
		self._velocity, self._orientation, self._attachment = nil, nil, nil
		self._humanoid, self._root = nil, nil
		self:SetStatus("Flight disabled")
	end
	return feature
end

function API.UniversalModules.CreateAutoClicker(options)
	options = options or {}
	local feature = API.CreateFeature(options.Name or "Auto Clicker", {
		ClicksPerSecond = options.ClicksPerSecond or 8,
		ToggleKey = options.ToggleKey or Enum.KeyCode.V,
	})
	function feature:OnEnable(token)
		if not VirtualInputManager then
			self:SetStatus("VirtualInputManager unavailable")
			return false
		end
		task.spawn(function()
			while self.Enabled and self._token == token do
				local started = os.clock()
				if not UserInputService:GetFocusedTextBox()
					and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
					and not (options.IsInputCaptured and options.IsInputCaptured()) then
					local ok, err = pcall(function()
						VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
						VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
					end)
					if not ok then
						self:Disable()
						self:SetStatus(tostring(err))
						break
					end
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

