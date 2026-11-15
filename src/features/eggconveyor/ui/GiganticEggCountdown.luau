--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local GiganticEggCountdown = {}

local MAX_DISTANCE = 60
local COVE_CLEARANCE = 3

function GiganticEggCountdown.mount(plotModel: Model, playerGui: PlayerGui): (() -> ())?
	local conveyor = plotModel:FindFirstChild("EggConveyor")
	local cove = if conveyor then conveyor:FindFirstChild("Cove2") else nil
	if not conveyor or not cove or not cove:IsA("Model") then
		return nil
	end

	local coveBounds, coveSize = cove:GetBoundingBox()
	local worldPosition = coveBounds.Position + Vector3.new(0, coveSize.Y / 2 + COVE_CLEARANCE, 0)
	local remaining = Vide.source(conveyor:GetAttribute("GiganticEggsRemaining"))
	local screenPosition = Vide.source(UDim2.fromOffset(0, 0))
	local visible = Vide.source(false)
	local labelScale = Vide.source(1)
	local attributeConnection = conveyor:GetAttributeChangedSignal("GiganticEggsRemaining"):Connect(function()
		remaining(conveyor:GetAttribute("GiganticEggsRemaining"))
	end)
	local cleanup = Vide.mount(function()
		local text = Vide.derive(function()
			local count = remaining()
			return "GIGANTIC EGG IN: " .. tostring(if typeof(count) == "number" then count else 500)
		end)
		local label = create "TextLabel" {
			Name = "Countdown",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = screenPosition,
			Size = UDim2.fromOffset(260, 30),
			BackgroundTransparency = 1,
			Text = text,
			TextSize = 22,
			Font = Enum.Font.BuilderSansExtraBold,
			TextColor3 = Color3.new(1, 1, 1),
			Visible = visible,
		}
		create "UIScale" { Scale = labelScale }.Parent = label
		create "UIStroke" {
			Color = Color3.new(0, 0, 0),
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}.Parent = label
		create "UIGradient" {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 65, 45)),
				ColorSequenceKeypoint.new(0.18, Color3.fromRGB(255, 192, 42)),
				ColorSequenceKeypoint.new(0.36, Color3.fromRGB(80, 235, 64)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(35, 220, 255)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(73, 112, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 67, 227)),
			}),
		}.Parent = label
		local screen = create "ScreenGui" {
			Name = "GiganticEggCountdown",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 30,
		}
		label.Parent = screen
		return screen
	end, playerGui)

	local lastViewport = Vector2.zero
	local renderConnection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera and camera.ViewportSize ~= lastViewport then
			lastViewport = camera.ViewportSize
			labelScale(math.clamp(math.min(lastViewport.X / 1000, lastViewport.Y / 650), 0.75, 1))
		end
		if typeof(remaining()) ~= "number" or not camera
			or (camera.CFrame.Position - worldPosition).Magnitude > MAX_DISTANCE then
			visible(false)
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(worldPosition)
		visible(onScreen and point.Z > 0)
		if onScreen and point.Z > 0 then
			screenPosition(UDim2.fromOffset(math.round(point.X), math.round(point.Y)))
		end
	end)

	return function()
		attributeConnection:Disconnect()
		renderConnection:Disconnect()
		cleanup()
	end
end

return GiganticEggCountdown
