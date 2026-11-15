--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local ShopItemCard = require(script.Parent.ShopItemCard)

local create = Vide.create

export type ItemView = {
	id: string,
	name: string?,
	price: number?,
	robuxPrice: (() -> string)?,
	boostPercent: number?,
	imageId: number?,
	imageScale: number?,
	imageOffsetX: number?,
}

export type Props = {
	items: { ItemView },
	stock: (string) -> number,
	isOpen: () -> boolean,
	refreshSeconds: (() -> number)?,
	refreshLabel: string?,
	title: string?,
	menuName: string?,
	titleMaxTextSize: number?,
	onClose: () -> (),
	onBuy: (string, Vector2) -> boolean,
	onRobuxBuy: (string, Vector2) -> (),
}

local function ShopRoot(props: Props): Instance
	local cards: { ImageLabel } = {}
	local compact = Vide.source(false)
	local wideTitle = #(props.title or "SHOP") > 6
	for _, item in props.items do
		table.insert(cards, ShopItemCard({ id = item.id, name = item.name, compact = compact, stock = function()
			return props.stock(item.id)
		end, price = item.price, robuxPrice = item.robuxPrice, boostPercent = item.boostPercent, imageId = item.imageId, imageScale = item.imageScale, imageOffsetX = item.imageOffsetX, onBuy = props.onBuy, onRobuxBuy = props.onRobuxBuy }))
	end

	local visible = Vide.source(false)
	local openSound = create "Sound" {
		Name = "OpenSound",
		SoundId = "rbxassetid://127488139302452",
		Volume = 1,
	}
	local closeSound = create "Sound" {
		Name = "CloseSound",
		SoundId = "rbxassetid://132948338000932",
		Volume = 1,
	}
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

	local refreshText = Vide.derive(function()
		local getRefreshSeconds = props.refreshSeconds
		if not getRefreshSeconds then
			return ""
		end
		local remaining = getRefreshSeconds()
		return string.format("%s %02d:%02d", props.refreshLabel or "Shop Refresh", math.floor(remaining / 60), remaining % 60)
	end)
	local timerLabel = create "TextLabel" {
		Name = "RefreshTimer",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.88, 0.085),
		Size = UDim2.fromScale(0.5, 0.13),
		BackgroundTransparency = 1,
		Visible = props.refreshSeconds ~= nil,
		Text = refreshText,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.BuilderSansExtraBold,
	}
	local timerTextSize = create "UITextSizeConstraint" { MaxTextSize = 36 }
	timerTextSize.Parent = timerLabel
	local timerStroke = create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}
	timerStroke.Parent = timerLabel
	local screenGui = create "ScreenGui" {
		Name = props.menuName or "ShopMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 34,
		Enabled = visible,

		openSound,
		closeSound,
		create "ImageLabel" {
			Name = "Background",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Size = UDim2.fromScale(0.88, 0.64),
			BackgroundTransparency = 1,
			Image = `rbxassetid://{assets.ShopBackground}`,
			ScaleType = Enum.ScaleType.Stretch,

			create "UIAspectRatioConstraint" {
				AspectRatio = 1.86,
				DominantAxis = Enum.DominantAxis.Height,
			},
			create "UISizeConstraint" {
				MaxSize = Vector2.new(900, 500),
			},
			create "ImageLabel" {
				Name = "ShopSign",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(if wideTitle then 0.20 else 0.14, 0.015),
				Size = UDim2.fromScale(if wideTitle then 0.42 else 0.32, 0.17),
				BackgroundTransparency = 1,
				Image = `rbxassetid://{assets.TopBarCard}`,
				ImageColor3 = Color3.fromRGB(255, 176, 72),
				ScaleType = Enum.ScaleType.Stretch,

				create "TextLabel" {
					Name = "Title",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(0.90, 0.76),
					Position = UDim2.fromScale(0.05, 0.04),
					Text = props.title or "SHOP",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0,
					Font = Enum.Font.BuilderSansExtraBold,
					TextScaled = true,
					create "UITextSizeConstraint" { MaxTextSize = props.titleMaxTextSize or 52 },
					create "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = Color3.fromRGB(0, 0, 0),
						Thickness = 3,
					},
				},
			},
			timerLabel,
			create "ImageButton" {
				Name = "CloseButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.985, 0.04),
				Size = UDim2.fromScale(0.08, 0.15),
				BackgroundTransparency = 1,
				Image = `rbxassetid://{assets.ExitButton}`,
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
			closeScale,
			},
			create "ScrollingFrame" {
				Name = "ItemList",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.fromScale(0.91, 0.81),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 7,
				ScrollBarImageColor3 = Color3.fromRGB(89, 43, 8),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				create "UIListLayout" {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 12),
				},
				create "UIPadding" {
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				},
				cards,
			},
		},
	}

	local background = screenGui:FindFirstChild("Background") :: ImageLabel
	local itemList = background:FindFirstChild("ItemList") :: ScrollingFrame
	local function resizeCards()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local isCompact = math.min(viewport.X, viewport.Y) < 600
		compact(isCompact)
		itemList.Position = UDim2.fromScale(0.5, if isCompact then 0.58 else 0.56)
		itemList.Size = UDim2.fromScale(0.91, if isCompact then 0.78 else 0.81)
		-- Show one compact card and a small preview of the next card on phones.
		local cardHeight = math.max(if isCompact then 160 else 184, math.floor((itemList.AbsoluteSize.Y - 24) / 2))
		for _, card in cards do
			card.Size = UDim2.new(1, -10, 0, cardHeight)
		end
	end
	itemList:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCards)
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeCards) else nil
		resizeCards()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	screenGui.Destroying:Connect(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)
	watchCamera()
	local shownPosition = UDim2.fromScale(0.5, 0.53)
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
			openSound:Play()
			local openingTween = TweenService:Create(background, TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = shownPosition,
			})
			panelTween = openingTween
			openingTween:Play()
		elseif shown then
			local closingTween = TweenService:Create(background, TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
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

	return screenGui
end

return ShopRoot
