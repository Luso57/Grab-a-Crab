--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create

export type Props = {
	isOpen: () -> boolean,
	priceText: () -> string,
	onBuy: () -> (),
	onClose: () -> (),
}

local rewards = {
	{ name = "Basic", amount = "10g", imageId = assets.BasicCrabImg, amountColor = Color3.new(1, 1, 1) },
	{ name = "Large Tank", amount = "2x", imageId = assets.LargeTank, amountColor = Color3.new(1, 1, 1) },
	{ name = "Money", amount = "$50k", imageId = assets.SandDollar, amountColor = Color3.new(1, 1, 1) },
	{ name = "Luck", amount = "+1x", imageId = assets.IndexClover, amountColor = Color3.new(1, 1, 1) },
}

local function outlinedText(name: string, value: string | (() -> string), color: Color3, maxTextSize: number, zIndex: number): TextLabel
	local label = create "TextLabel" {
		Name = name,
		BackgroundTransparency = 1,
		Text = value,
		TextColor3 = color,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = zIndex,
	} :: TextLabel
	create "UITextSizeConstraint" { MaxTextSize = maxTextSize, MinTextSize = 10 }.Parent = label
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 2,
	}.Parent = label
	return label
end

local function makeRewardCard(reward: typeof(rewards[1])): Frame
	local card = create "Frame" {
		Name = reward.name:gsub("%s", "") .. "Reward",
		BackgroundTransparency = 1,
		ZIndex = 3,
	} :: Frame

	local title = outlinedText("Title", reward.name, Color3.new(1, 1, 1), 28, 5)
	title.Size = UDim2.fromScale(1, 0.21)
	title.Parent = card

	local tile = create "ImageLabel" {
		Name = "YellowCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.19),
		Size = UDim2.fromScale(0.86, 0.57),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopMonoCoinCard,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 4,
	} :: ImageLabel
	tile.Parent = card

	local icon = create "ImageLabel" {
		Name = "RewardIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.475),
		Size = if reward.name == "Basic" then UDim2.fromScale(0.88, 0.68) else UDim2.fromScale(0.55, 0.47),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. reward.imageId,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
	} :: ImageLabel
	icon.Parent = card

	local amount = outlinedText("Amount", reward.amount, reward.amountColor, 37, 5)
	amount.Position = UDim2.fromScale(0, 0.75)
	amount.Size = UDim2.fromScale(1, 0.25)
	amount.Parent = card

	return card
end

local function StarterPackRoot(props: Props): ScreenGui
	local visible = Vide.source(false)
	local shownPosition = UDim2.fromScale(0.5, 0.54)
	local hiddenPosition = UDim2.fromScale(0.5, 1.6)
	local screen = create "ScreenGui" {
		Name = "StarterPackMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 45,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = visible,
	} :: ScreenGui

	create "Frame" {
		Name = "Dimmer",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 1,
	}.Parent = screen

	local panel = create "Frame" {
		Name = "StarterPackPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = hiddenPosition,
		Size = UDim2.fromOffset(660, 390),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	} :: Frame
	panel.Parent = screen
	local panelCorner = create "UICorner" { CornerRadius = UDim.new(0, 42) }
	panelCorner.Parent = panel
	local panelStroke = create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(87, 42, 0),
		Thickness = 9,
	}
	panelStroke.Parent = panel
	create "UIGradient" {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(177, 86, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(158, 70, 0)),
		}),
		Rotation = 90,
	}.Parent = panel

	local banner = create "ImageLabel" {
		Name = "ExclusivePackBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TopBarCard,
		ImageColor3 = Color3.fromRGB(255, 176, 72),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 7,
	} :: ImageLabel
	banner.Parent = panel
	local bannerText = outlinedText("BannerText", "Exclusive Pack", Color3.new(1, 1, 1), 36, 8)
	bannerText.Position = UDim2.fromScale(0.05, 0.04)
	bannerText.Size = UDim2.fromScale(0.9, 0.76)
	bannerText.Parent = banner

	local exitScale = create "UIScale" { Scale = 1 }
	local exitHoverTween: Tween? = nil
	local function setExitScale(scale: number)
		if exitHoverTween then
			exitHoverTween:Cancel()
		end
		exitHoverTween = TweenService:Create(exitScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = scale,
		})
		exitHoverTween:Play()
	end

	local exitButton = create "ImageButton" {
		Name = "ExitButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ExitButton,
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = false,
		ZIndex = 9,
		MouseEnter = function()
			setExitScale(1.1)
		end,
		MouseLeave = function()
			setExitScale(1)
		end,
		Activated = function()
			setExitScale(1)
			props.onClose()
		end,
	} :: ImageButton
	exitScale.Parent = exitButton
	exitButton.Parent = panel

	local heading = outlinedText("Heading", "Starter Pack", Color3.new(1, 1, 1), 52, 4)
	heading.AnchorPoint = Vector2.new(0.5, 0)
	heading.Position = UDim2.fromScale(0.5, 0.09)
	heading.Size = UDim2.fromScale(0.88, 0.16)
	heading.Parent = panel

	local cardArea = create "Frame" {
		Name = "RewardCards",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromScale(0.88, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
	} :: Frame
	cardArea.Parent = panel
	local cards: { Frame } = {}
	for _, reward in rewards do
		local card = makeRewardCard(reward)
		card.Parent = cardArea
		table.insert(cards, card)
	end

	local priceScale = create "UIScale" { Scale = 1 }
	local priceHoverTween: Tween? = nil
	local function setPriceScale(scale: number)
		if priceHoverTween then
			priceHoverTween:Cancel()
		end
		priceHoverTween = TweenService:Create(priceScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = scale,
		})
		priceHoverTween:Play()
	end

	local priceDisplay = create "ImageButton" {
		Name = "PriceDisplay",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.85),
		Size = UDim2.fromScale(0.33, 0.15),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopMonoCoinBuyButton,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false,
		ZIndex = 5,
		MouseEnter = function()
			setPriceScale(1.1)
		end,
		MouseLeave = function()
			setPriceScale(1)
		end,
		Activated = props.onBuy,
	} :: ImageButton
	priceScale.Parent = priceDisplay
	priceDisplay.Parent = panel
	local robuxIcon = create "ImageLabel" {
		Name = "RobuxIcon",
		Position = UDim2.fromScale(0.17, 0.18),
		Size = UDim2.fromScale(0.22, 0.64),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.RobuxIcon,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 6,
	} :: ImageLabel
	robuxIcon.Parent = priceDisplay
	local price = outlinedText("Price", props.priceText, Color3.new(1, 1, 1), 40, 6)
	price.Position = UDim2.fromScale(0.41, 0.08)
	price.Size = UDim2.fromScale(0.47, 0.84)
	price.Parent = priceDisplay

	local viewportConnection: RBXScriptConnection? = nil
	local function resize()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local portrait = viewport.X < viewport.Y
		local compact = math.min(viewport.X, viewport.Y) < 600
		local panelWidth = math.floor(math.min(660, viewport.X * (if compact then 0.82 else 0.9)))
		local maxHeight = if portrait then (if compact then 480 else 520) else (if compact then 350 else 390)
		local panelHeight = math.floor(math.min(maxHeight, viewport.Y * (if compact then 0.72 else 0.78)))
		panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
		panelCorner.CornerRadius = UDim.new(0, if panelHeight < 340 then 26 else 42)
		panelStroke.Thickness = if panelHeight < 340 then 6 else 9
		banner.Position = UDim2.fromScale(0.2, 0.015)
		banner.Size = UDim2.fromScale(if compact then 0.48 else 0.42, if compact then 0.15 else 0.17)
		cardArea.Position = UDim2.fromScale(0.5, if portrait then 0.25 else 0.26)
		cardArea.Size = UDim2.fromScale(0.88, if portrait then 0.54 else 0.5)
		priceDisplay.Position = UDim2.fromScale(0.5, if portrait then 0.91 else 0.85)
		priceDisplay.Size = UDim2.fromScale(if compact then (if portrait then 0.46 else 0.27) else (if portrait then 0.56 else 0.33), if portrait then 0.11 else 0.15)

		local areaWidth = panelWidth * 0.88
		local areaHeight = panelHeight * (if portrait then 0.54 else 0.5)
		local columns = if portrait then 2 else 4
		local rows = if portrait then 2 else 1
		local gap = if panelWidth < 500 then 8 else 14
		local cardWidth = math.floor((areaWidth - gap * (columns - 1)) / columns)
		local cardHeight = math.floor((areaHeight - gap * (rows - 1)) / rows)
		for index, card in cards do
			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			card.Position = UDim2.fromOffset(column * (cardWidth + gap), row * (cardHeight + gap))
			card.Size = UDim2.fromOffset(cardWidth, cardHeight)
		end
	end
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) else nil
		resize()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	local panelTween: Tween? = nil
	local animationVersion = 0
	screen.Destroying:Connect(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		if panelTween then
			panelTween:Cancel()
		end
		if exitHoverTween then
			exitHoverTween:Cancel()
		end
		if priceHoverTween then
			priceHoverTween:Cancel()
		end
	end)
	watchCamera()

	local wasOpen = false
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
			visible(true)
			panelTween = TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = shownPosition,
			})
			panelTween:Play()
		else
			setPriceScale(1)
			panelTween = TweenService:Create(panel, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = hiddenPosition,
			})
			panelTween.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed and animationVersion == version then
					visible(false)
				end
			end)
			panelTween:Play()
		end
	end)

	return screen
end

return StarterPackRoot
