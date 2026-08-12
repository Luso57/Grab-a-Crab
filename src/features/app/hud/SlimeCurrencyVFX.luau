local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)

local SCREEN_GUI_NAME = "SlimeCurrencyVFX"

local SlimeCurrencyVFX = {}

local function getScreenGui(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_GUI_NAME
	screenGui.DisplayOrder = 101
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = playerGui

	return screenGui
end

local function getViewportSize(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function getDestination(viewportSize: Vector2): Vector2
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local reactGui = playerGui and playerGui:FindFirstChild("React")
	local bottomBar = reactGui and reactGui:FindFirstChild("BottomBar")
	local amount = bottomBar and bottomBar:FindFirstChild("Amount")
	if amount and amount:IsA("GuiObject") then
		return amount.AbsolutePosition + amount.AbsoluteSize / 2
	end

	return Vector2.new(viewportSize.X / 2, viewportSize.Y - 52)
end

function SlimeCurrencyVFX.play(amount: number)
	local safeAmount = math.floor(math.max(0, amount))
	if safeAmount <= 0 then
		return
	end

	local viewportSize = getViewportSize()
	local destination = getDestination(viewportSize)
	local startPosition = destination + Vector2.new(0, -90)
	local popPosition = destination + Vector2.new(0, -35)

	local container = Instance.new("Frame")
	container.Name = "SlimeCurrencyGained"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Position = UDim2.fromOffset(startPosition.X, startPosition.Y)
	container.Size = UDim2.fromOffset(260, 64)
	container.ZIndex = 110
	container.Parent = getScreenGui()

	local scale = Instance.new("UIScale")
	scale.Scale = 0.72
	scale.Parent = container

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "Amount"
	amountLabel.BackgroundTransparency = 1
	amountLabel.Font = Enum.Font.FredokaOne
	amountLabel.Size = UDim2.fromScale(1, 1)
	amountLabel.Text = `+{CompactNumber.format(safeAmount, 2)}`
	amountLabel.TextColor3 = Color3.fromRGB(65, 255, 55)
	amountLabel.TextScaled = true
	amountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	amountLabel.TextStrokeTransparency = 0
	amountLabel.ZIndex = 111
	amountLabel.Parent = container

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 48
	textConstraint.MinTextSize = 18
	textConstraint.Parent = amountLabel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 4
	stroke.Parent = amountLabel

	task.spawn(function()
		local emergeTween = TweenService:Create(
			container,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(popPosition.X, popPosition.Y) }
		)
		local popScaleTween = TweenService:Create(
			scale,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		emergeTween:Play()
		popScaleTween:Play()
		emergeTween.Completed:Wait()
		task.wait(0.12)

		local moveTween = TweenService:Create(
			container,
			TweenInfo.new(0.68, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromOffset(destination.X, destination.Y) }
		)
		local shrinkTween = TweenService:Create(
			scale,
			TweenInfo.new(0.68, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.48 }
		)
		local fadeInfo = TweenInfo.new(0.24, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.44)
		local textFade = TweenService:Create(amountLabel, fadeInfo, { TextTransparency = 1 })
		local strokeFade = TweenService:Create(stroke, fadeInfo, { Transparency = 1 })

		moveTween:Play()
		shrinkTween:Play()
		textFade:Play()
		strokeFade:Play()
		moveTween.Completed:Wait()
		container:Destroy()
	end)
end

return SlimeCurrencyVFX
