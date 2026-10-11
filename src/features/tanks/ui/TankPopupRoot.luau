--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create

export type Card = {
	instanceId: string,
	name: string,
	imageId: number,
	income: string,
}

export type Props = {
	cards: () -> { Card },
	isOpen: () -> boolean,
	onClose: () -> (),
	onPickUp: (string) -> (),
}

local function outlinedText(name: string, value: () -> string, position: UDim2, size: UDim2, maxSize: number, strokeThickness: number?): TextLabel
	local label = create "TextLabel" {
		Name = name,
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansExtraBold,
	}
	create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = strokeThickness or 3.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}.Parent = label
	create "UITextSizeConstraint" { MaxTextSize = maxSize }.Parent = label
	return label
end

local function makeCard(index: number, cards: () -> { Card }, onPickUp: (string) -> ()): ImageLabel
	local function info(): Card?
		return cards()[index]
	end

	local card = create "ImageLabel" {
		Name = "CrabCard" .. index,
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TankCArdPopUP,
		ScaleType = Enum.ScaleType.Stretch,
		Visible = function()
			return info() ~= nil
		end,
		Size = UDim2.new(1, -8, 0, 210),
	}

	create "ImageLabel" {
		Name = "CrabImage",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.025, 0.08),
		Size = UDim2.fromScale(0.305, 0.84),
		Image = function()
			local item = info()
			return if item then "rbxassetid://" .. item.imageId else ""
		end,
		ScaleType = Enum.ScaleType.Crop,
	}.Parent = card

	outlinedText("CrabName", function()
		local item = info()
		return if item then string.upper(item.name) else ""
	end, UDim2.fromScale(0.36, 0.07), UDim2.fromScale(0.59, 0.25), 40).Parent = card

	create "ImageLabel" {
		Name = "CoinIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.35, 0.30),
		Size = UDim2.fromScale(0.09, 0.23),
		Image = "rbxassetid://" .. assets.SandDollar,
		ScaleType = Enum.ScaleType.Fit,
	}.Parent = card

	outlinedText("IncomePerSecond", function()
		local item = info()
		return if item then item.income else ""
	end, UDim2.fromScale(0.45, 0.28), UDim2.fromScale(0.46, 0.25), 42).Parent = card

	local pickupScale = create "UIScale" { Scale = 1 }
	local pickupTween: Tween? = nil
	local function setPickupScale(value: number)
		if pickupTween then
			pickupTween:Cancel()
		end
		local tween = TweenService:Create(pickupScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = value,
		})
		pickupTween = tween
		tween:Play()
	end
	local pickup = create "ImageButton" {
		Name = "PickupButton",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.83, 0.605),
		Size = UDim2.fromScale(0.26, 0.19),
		Image = "rbxassetid://" .. assets.TankpickUpbutton,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false,
		MouseEnter = function()
			setPickupScale(1.1)
		end,
		MouseLeave = function()
			setPickupScale(1)
		end,
		Activated = function()
			local item = info()
			if item then
				onPickUp(item.instanceId)
			end
		end,
	}
	pickup.Parent = card
	pickupScale.Parent = pickup
	local pickupText = outlinedText("PickupText", function()
		return "PICK UP"
	end, UDim2.new(), UDim2.fromScale(1, 1), 26, 2)
	pickupText.TextXAlignment = Enum.TextXAlignment.Center
	pickupText.Parent = pickup

	local sell = create "ImageLabel" {
		Name = "SellDecoration",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.70, 0.73),
		Size = UDim2.fromScale(0.26, 0.18),
		Image = "rbxassetid://" .. assets.TankSellButton,
		ScaleType = Enum.ScaleType.Stretch,
	}
	sell.Parent = card
	local sellText = outlinedText("SellText", function()
		return "SELL"
	end, UDim2.new(), UDim2.fromScale(1, 1), 26, 2)
	sellText.TextXAlignment = Enum.TextXAlignment.Center
	sellText.Parent = sell

	return card
end

local function TankPopupRoot(props: Props): ScreenGui
	local closeSound = create "Sound" {
		Name = "CloseSound",
		SoundId = "rbxassetid://132948338000932",
		Volume = 1,
	}
	local function onPickUp(instanceId: string)
		closeSound.TimePosition = 0
		closeSound:Play()
		props.onPickUp(instanceId)
	end
	local cardInstances = {
		makeCard(1, props.cards, onPickUp),
		makeCard(2, props.cards, onPickUp),
		makeCard(3, props.cards, onPickUp),
	}

	local visible = Vide.source(false)
	local closeScale = create "UIScale" { Scale = 1 }
	local hoverTween: Tween? = nil
	local function setCloseScale(scale: number)
		if hoverTween then
			hoverTween:Cancel()
		end
		local tween = TweenService:Create(closeScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = scale,
		})
		hoverTween = tween
		tween:Play()
	end

	local gui = create "ScreenGui" {
		Name = "TankPopup",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = visible,
	}

	closeSound.Parent = gui

	local background = create "ImageLabel" {
		Name = "Background",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.8),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TankPopUpbackgorund,
		ScaleType = Enum.ScaleType.Stretch,
	}
	background.Parent = gui
	create "UIAspectRatioConstraint" {
		AspectRatio = 0.86,
		DominantAxis = Enum.DominantAxis.Width,
	}.Parent = background
	create "UISizeConstraint" {
		MaxSize = Vector2.new(620, 720),
	}.Parent = background

	local titleBanner = create "ImageLabel" {
		Name = "CrabsTitleBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.17, 0.015),
		Size = UDim2.fromScale(0.55, 0.17),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.WoodenPlankShop,
		ScaleType = Enum.ScaleType.Fit,
	}
	titleBanner.Parent = background
	local title = outlinedText("CrabsTitle", function()
		return "CRABS"
	end, UDim2.fromScale(0.14, 0.04), UDim2.fromScale(0.74, 0.90), 72)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Rotation = -8
	title.Parent = titleBanner
	local close = create "ImageButton" {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.97, 0.015),
		Size = UDim2.fromScale(0.14, 0.12),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ExitButton,
		ScaleType = Enum.ScaleType.Fit,
		MouseEnter = function()
			setCloseScale(1.1)
		end,
		MouseLeave = function()
			setCloseScale(1)
		end,
		Activated = function()
			setCloseScale(1)
			closeSound:Play()
			props.onClose()
		end,
	}
	close.Parent = background
	closeScale.Parent = close

	local list = create "ScrollingFrame" {
		Name = "CrabList",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.86, 0.84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(100, 48, 8),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	list.Parent = background
	create "UIListLayout" {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
	}.Parent = list
	create "UIPadding" {
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
	}.Parent = list

	for _, card in cardInstances do
		card.Parent = list
	end

	local empty = create "TextLabel" {
		Name = "EmptyMessage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.84, 0.22),
		BackgroundTransparency = 1,
		Text = "NO CRABS IN THIS TANK",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		Visible = function()
			return #props.cards() == 0
		end,
	}
	empty.Parent = background
	create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = 3.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}.Parent = empty
	create "UITextSizeConstraint" { MaxTextSize = 42 }.Parent = empty

	local function resizeCards()
		local height = math.max(90, math.floor((list.AbsoluteSize.X - 8) / 2.3))
		for _, card in cardInstances do
			card.Size = UDim2.new(1, -8, 0, height)
		end
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCards)
	resizeCards()

	local shownPosition = UDim2.fromScale(0.5, 0.5)
	local hiddenPosition = UDim2.fromScale(0.5, 1.6)
	local panelTween: Tween? = nil
	local animationVersion = 0
	local shown = false
	local wasOpen = false

	background.Position = hiddenPosition

	Vide.effect(function()
		local shouldOpen = props.isOpen()
		if shouldOpen == wasOpen then
			return
		end
		wasOpen = shouldOpen
		animationVersion += 1
		local version = animationVersion

		if panelTween then
			panelTween:Cancel()
		end

		if shouldOpen then
			if not shown then
				background.Position = hiddenPosition
			end
			shown = true
			visible(true)
			local openingTween = TweenService:Create(background, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = shownPosition,
			})
			panelTween = openingTween
			openingTween:Play()
		elseif shown then
			local closingTween = TweenService:Create(background, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = hiddenPosition,
			})
			panelTween = closingTween
			closingTween.Completed:Once(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed and animationVersion == version then
					shown = false
					visible(false)
				end
			end)
			closingTween:Play()
		else
			background.Position = hiddenPosition
		end
	end)

	return gui
end

return TankPopupRoot