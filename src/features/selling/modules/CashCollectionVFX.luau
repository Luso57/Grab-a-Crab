local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)

local SOUND_ID = "rbxassetid://131737037329240"
local ICON_ID = "rbxassetid://18209585851"
local SCREEN_GUI_NAME = "CashCollectionVFX"

local CashCollectionVFX = {}

local function formatAmount(amount: number): string
	return CompactNumber.format(math.max(0, amount), 2)
end

local function getScreenGui(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_GUI_NAME
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	return screenGui
end

local function playSound()
	local sound = Instance.new("Sound")
	sound.Name = "CashCollected"
	sound.SoundId = SOUND_ID
	sound.Volume = 0.2
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
end

function CashCollectionVFX.play(amount: number)
	if amount <= 0 then
		return
	end

	playSound()

	local container = Instance.new("Frame")
	container.Name = "CashCollected"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Position = UDim2.fromScale(0.5, 0.48)
	container.Size = UDim2.fromOffset(360, 82)
	container.ZIndex = 100
	container.Parent = getScreenGui()

	local scale = Instance.new("UIScale")
	scale.Scale = 0.65
	scale.Parent = container

	local icon = Instance.new("ImageLabel")
	icon.Name = "CurrencyIcon"
	icon.BackgroundTransparency = 1
	icon.Image = ICON_ID
	icon.Position = UDim2.fromOffset(0, 5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(72, 72)
	icon.ZIndex = 101
	icon.Parent = container

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "Amount"
	amountLabel.BackgroundTransparency = 1
	amountLabel.Font = Enum.Font.FredokaOne
	amountLabel.Position = UDim2.fromOffset(78, 0)
	amountLabel.Size = UDim2.new(1, -78, 1, 0)
	amountLabel.Text = `${formatAmount(amount)}`
	amountLabel.TextColor3 = Color3.fromRGB(65, 255, 55)
	amountLabel.TextScaled = true
	amountLabel.TextStrokeTransparency = 1
	amountLabel.TextXAlignment = Enum.TextXAlignment.Left
	amountLabel.ZIndex = 101
	amountLabel.Parent = container

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 54
	textConstraint.MinTextSize = 18
	textConstraint.Parent = amountLabel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 4
	stroke.Parent = amountLabel

	task.spawn(function()
		local popTween = TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		popTween:Play()
		popTween.Completed:Wait()
		task.wait(0.22)

		local moveTween = TweenService:Create(
			container,
			TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.new(0, 105, 1, -54) }
		)
		local textFade = TweenService:Create(amountLabel, TweenInfo.new(0.75), { TextTransparency = 1 })
		local iconFade = TweenService:Create(icon, TweenInfo.new(0.75), { ImageTransparency = 1 })
		local strokeFade = TweenService:Create(stroke, TweenInfo.new(0.75), { Transparency = 1 })

		moveTween:Play()
		textFade:Play()
		iconFade:Play()
		strokeFade:Play()
		moveTween.Completed:Wait()
		container:Destroy()
	end)
end

return CashCollectionVFX
