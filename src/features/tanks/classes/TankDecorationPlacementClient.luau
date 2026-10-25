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

local function button(name: string, label: string, x: number, callback: () -> ()): TextButton
	local control = Vide.create "TextButton" {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(x, 0.79),
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
	return control
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
		touchPosition = nil :: Vector2?,
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
	local placeButton = button("PlaceButton", "PLACE", 0.35, confirm)
	placeButton.Parent = gui
	button("RotateButton", "ROTATE (R)", 0.5, rotate).Parent = gui
	button("CancelButton", "CANCEL", 0.65, onCancel).Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui
	self.heading = heading

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
	table.insert(self.connections, UserInputService.TouchStarted:Connect(function(input, processed)
		if not processed then
			self.touchPosition = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))
	table.insert(self.connections, UserInputService.TouchMoved:Connect(function(input, processed)
		if not processed then
			self.touchPosition = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))
	table.insert(self.connections, RunService.RenderStepped:Connect(function()
		if not floor.Parent then
			onCancel()
			return
		end
		local mouse = self.touchPosition or UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local normal = floor.CFrame.UpVector
		local denominator = ray.Direction:Dot(normal)
		if math.abs(denominator) > 0.001 then
			local distance = (floor.Position - ray.Origin):Dot(normal) / denominator
			if distance > 0 then
				local localPoint = floor.CFrame:PointToObjectSpace(ray.Origin + ray.Direction * distance)
				if math.abs(localPoint.X) <= floor.Size.X / 2 and math.abs(localPoint.Z) <= floor.Size.Z / 2 then
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
