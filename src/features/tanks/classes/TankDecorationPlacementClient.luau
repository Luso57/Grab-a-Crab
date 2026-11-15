--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Placement = require(ReplicatedStorage.Source.Features.Tanks.Modules.TankDecorationPlacement)

local PlacementClient = {}
PlacementClient.__index = PlacementClient

local TOUCH_DRAG_SCALE = 0.5

local function button(name: string, label: string, callback: () -> ()): TextButton
	local control = Vide.create "TextButton" {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromOffset(135, 52),
		BackgroundColor3 = Color3.fromRGB(143, 75, 15),
		Text = label,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		TextScaled = true,
		Activated = callback,
	}
	Vide.create "UICorner" { CornerRadius = UDim.new(0, 10) }.Parent = control
	Vide.create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}.Parent = control
	Vide.create "UITextSizeConstraint" { MaxTextSize = 24, MinTextSize = 12 }.Parent = control
	return control
end

local function containsPoint(control: GuiObject, point: Vector2): boolean
	local position = control.AbsolutePosition
	local size = control.AbsoluteSize
	return point.X >= position.X and point.X <= position.X + size.X
		and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

function PlacementClient.new(tankModel: Model, decorId: string, onPlace: (number, number, number) -> (), onCancel: () -> ())
	local floor = tankModel:FindFirstChild("InsideFloor", true)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local decorations = if assets then assets:FindFirstChild("Decorations") else nil
	local template = if decorations then decorations:FindFirstChild(decorId) else nil
	local camera = Workspace.CurrentCamera
	if not floor or not floor:IsA("BasePart") or not template or not template:IsA("Model") or not camera then
		return nil
	end
	local ghost = template:Clone()
	local size = Placement.prepare(ghost, floor)
	if not size then
		ghost:Destroy()
		return nil
	end
	for _, descendant in ghost:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			-- Glass tank walls hide translucent objects behind them, so keep the preview solid.
			if descendant.Transparency < 1 then
				descendant.Transparency = 0
			end
		end
	end
	ghost.Name = "DecorationPreview"
	ghost.Parent = Workspace

	local previousType = camera.CameraType
	local previousSubject = camera.CameraSubject
	local previousCFrame = camera.CFrame
	local center = floor.Position
	local moneyPad = tankModel:FindFirstChild("GreenInnerCircle", true)
	local slotId = tankModel:GetAttribute("SlotId")
	local fallbackDirection = floor.CFrame.RightVector * (if typeof(slotId) == "string" and string.match(slotId, "^Right") then -1 else 1)
	local padOffset = if moneyPad and moneyPad:IsA("BasePart") then moneyPad.Position - center else fallbackDirection
	local horizontalDirection = Vector3.new(padOffset.X, 0, padOffset.Z)
	if horizontalDirection.Magnitude < 0.1 then
		horizontalDirection = fallbackDirection
	end
	local cameraDistance = math.max(7.2, floor.Size.X * 1.8)
	local height = floor.Size.X * 0.95 + 0.7
	local target = center + Vector3.new(0, floor.Size.X * 0.2, 0)
	local placementCameraCFrame = CFrame.lookAt(center + horizontalDirection.Unit * cameraDistance + Vector3.new(0, height, 0), target)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = placementCameraCFrame
	local cameraBinding = "TankDecorationPlacementCamera"
	RunService:BindToRenderStep(cameraBinding, Enum.RenderPriority.Camera.Value + 1, function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = placementCameraCFrame
	end)

	local self = setmetatable({
		floor = floor, ghost = ghost, size = size, camera = camera,
		previousType = previousType, previousSubject = previousSubject, previousCFrame = previousCFrame,
		cameraBinding = cameraBinding,
		x = 0, z = 0, rotation = 0, valid = false, destroyed = false,
		connections = {} :: { RBXScriptConnection },
		gui = nil :: ScreenGui?,
		usingTouch = UserInputService.TouchEnabled,
		activeTouch = nil :: InputObject?,
		touchStartPosition = nil :: Vector2?,
		touchStartX = 0,
		touchStartZ = 0,
	}, PlacementClient)

	local function confirm()
		if self.valid then
			onPlace(self.x, self.z, self.rotation)
		else
			self:setStatus("THAT SPOT IS BLOCKED")
			task.delay(1.5, function()
				if not self.destroyed and self.heading.Text == "THAT SPOT IS BLOCKED" then
					self:setStatus("MOVE DECORATION INSIDE THE TANK")
				end
			end)
		end
	end
	local function rotate()
		self.rotation = (self.rotation + 1) % 4
	end
	local gui = Vide.create "ScreenGui" {
		Name = "TankDecorationPlacement",
		ResetOnSpawn = false,
		DisplayOrder = 40,
		IgnoreGuiInset = true,
	}
	local heading = Vide.create "TextLabel" {
		Name = "Instructions",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.13),
		Size = UDim2.fromOffset(460, 50),
		BackgroundColor3 = Color3.fromRGB(76, 39, 11),
		BackgroundTransparency = 0.15,
		Text = "MOVE DECORATION INSIDE THE TANK",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		TextScaled = true,
	}
	heading.Parent = gui
	Vide.create "UICorner" { CornerRadius = UDim.new(0, 10) }.Parent = heading
	local headingTextSize = Vide.create "UITextSizeConstraint" { MaxTextSize = 26, MinTextSize = 12 }
	headingTextSize.Parent = heading
	local placeButton = button("PlaceButton", "PLACE", confirm)
	placeButton.Parent = gui
	local rotateButton = button("RotateButton", "ROTATE (R)", rotate)
	rotateButton.Parent = gui
	local cancelButton = button("CancelButton", "CANCEL", onCancel)
	cancelButton.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui
	self.heading = heading

	local function layout()
		local viewport = camera.ViewportSize
		local compact = math.min(viewport.X, viewport.Y) < 600
		local gap = if compact then 12 else 16
		local buttonWidth = if compact then math.min(96, math.floor((viewport.X - 48 - gap * 2) / 3)) else 135
		local buttonHeight = if compact then 40 else 52
		local step = buttonWidth + gap
		for index, control in { placeButton, rotateButton, cancelButton } do
			control.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
			control.Position = UDim2.new(0.5, (index - 2) * step, if compact then 0.83 else 0.79, 0)
		end
		rotateButton.Text = if compact then "ROTATE" else "ROTATE (R)"
		heading.Size = UDim2.fromOffset(math.min(if compact then 370 else 460, viewport.X - 32), if compact then 38 else 50)
		heading.Position = UDim2.fromScale(0.5, if compact then 0.12 else 0.13)
		headingTextSize.MaxTextSize = if compact then 19 else 26
	end
	layout()
	table.insert(self.connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout))

	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotate()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			onCancel()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			confirm()
		end
	end))
	table.insert(self.connections, UserInputService.TouchStarted:Connect(function(input)
		if self.activeTouch then
			return
		end
		local point = Vector2.new(input.Position.X, input.Position.Y)
		if containsPoint(placeButton, point) or containsPoint(rotateButton, point) or containsPoint(cancelButton, point) then
			return
		end
		self.activeTouch = input
		self.usingTouch = true
		self.touchStartPosition = point
		self.touchStartX = self.x
		self.touchStartZ = self.z
	end))
	table.insert(self.connections, UserInputService.TouchMoved:Connect(function(input)
		if input == self.activeTouch then
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local start = self.touchStartPosition
			if not start then
				return
			end
			local screenCenter = camera:WorldToViewportPoint(floor.Position)
			local xPoint = camera:WorldToViewportPoint(floor.Position + floor.CFrame:VectorToWorldSpace(Vector3.xAxis))
			local zPoint = camera:WorldToViewportPoint(floor.Position + floor.CFrame:VectorToWorldSpace(Vector3.zAxis))
			local xAxis = Vector2.new(xPoint.X - screenCenter.X, xPoint.Y - screenCenter.Y)
			local zAxis = Vector2.new(zPoint.X - screenCenter.X, zPoint.Y - screenCenter.Y)
			local determinant = xAxis.X * zAxis.Y - xAxis.Y * zAxis.X
			if math.abs(determinant) < 0.001 then
				return
			end
			local delta = (point - start) * TOUCH_DRAG_SCALE
			self.x = math.round((self.touchStartX + (delta.X * zAxis.Y - delta.Y * zAxis.X) / determinant) * 100) / 100
			self.z = math.round((self.touchStartZ + (xAxis.X * delta.Y - xAxis.Y * delta.X) / determinant) * 100) / 100
		end
	end))
	table.insert(self.connections, UserInputService.TouchEnded:Connect(function(input)
		if input == self.activeTouch then
			self.activeTouch = nil
			self.touchStartPosition = nil
		end
	end))
	table.insert(self.connections, RunService.RenderStepped:Connect(function()
		if not floor.Parent then
			onCancel()
			return
		end
		if not self.usingTouch then
			local mouse = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			local normal = floor.CFrame.UpVector
			local denominator = ray.Direction:Dot(normal)
			if math.abs(denominator) > 0.001 then
				local distance = (floor.Position - ray.Origin):Dot(normal) / denominator
				if distance > 0 then
					local localPoint = floor.CFrame:PointToObjectSpace(ray.Origin + ray.Direction * distance)
					self.x = math.round(localPoint.X * 100) / 100
					self.z = math.round(localPoint.Z * 100) / 100
				end
			end
		end
		self.x, self.z = Placement.clampToFloor(floor, size, self.x, self.z, self.rotation)
		self.valid = Placement.fits(floor, size, self.x, self.z, self.rotation)
		local width, depth = Placement.footprint(size, self.rotation)
		local folder = tankModel:FindFirstChild("ContainedDecorations")
		if folder then
			for _, placed in folder:GetChildren() do
				if placed:IsA("Model") then
					local otherX = placed:GetAttribute("DecorX")
					local otherZ = placed:GetAttribute("DecorZ")
					local otherWidth = placed:GetAttribute("DecorWidth")
					local otherDepth = placed:GetAttribute("DecorDepth")
					if typeof(otherX) == "number" and typeof(otherZ) == "number"
						and typeof(otherWidth) == "number" and typeof(otherDepth) == "number"
						and Placement.overlaps(self.x, self.z, width, depth, otherX, otherZ, otherWidth, otherDepth) then
						self.valid = false
					end
				end
			end
		end
		ghost:PivotTo(Placement.pivotOnFloor(ghost, floor, self.x, self.z, self.rotation))
		placeButton.BackgroundColor3 = if self.valid then Color3.fromRGB(143, 75, 15) else Color3.fromRGB(94, 88, 77)
	end))
	return self
end

function PlacementClient.setStatus(self, message: string)
	if not self.destroyed then
		self.heading.Text = message
	end
end

function PlacementClient.destroy(self)
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.ghost:Destroy()
	RunService:UnbindFromRenderStep(self.cameraBinding)
	if self.gui then
		self.gui:Destroy()
	end
	if Workspace.CurrentCamera == self.camera then
		self.camera.CameraSubject = self.previousSubject
		self.camera.CameraType = self.previousType
		if self.previousType == Enum.CameraType.Scriptable then
			self.camera.CFrame = self.previousCFrame
		end
	end
end

return PlacementClient
