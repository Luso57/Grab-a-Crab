--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local ShopItemCard = require(script.Parent.ShopItemCard)

local create = Vide.create

export type ItemView = {
	id: string,
	name: string?,
	stock: number?,
	price: string?,
	imageId: number?,
	imageScale: number?,
	imageOffsetX: number?,
}

export type Props = {
	items: { ItemView },
	isOpen: () -> boolean,
	refreshSeconds: () -> number,
	onClose: () -> (),
	onBuy: (string) -> (),
}

local function ShopRoot(props: Props): Instance
	local cards: { ImageLabel } = {}
	for _, item in props.items do
		table.insert(cards, ShopItemCard({ id = item.id, name = item.name, stock = item.stock, price = item.price, imageId = item.imageId, imageScale = item.imageScale, imageOffsetX = item.imageOffsetX, onBuy = props.onBuy }))
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
		local remaining = props.refreshSeconds()
		return string.format("Shop Refresh %02d:%02d", math.floor(remaining / 60), remaining % 60)
	end)
	local timerLabel = create "TextLabel" {
		Name = "RefreshTimer",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.88, 0.085),
		Size = UDim2.fromScale(0.5, 0.13),
		BackgroundTransparency = 1,
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
		Name = "ShopMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
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
				Position = UDim2.fromScale(0.08, 0.05),
				Size = UDim2.fromScale(0.4, 0.26),
				BackgroundTransparency = 1,
				Image = `rbxassetid://{assets.WoodenPlankShop}`,
				ScaleType = Enum.ScaleType.Fit,

				create "TextLabel" {
					Name = "Title",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 0.85),
					Position = UDim2.fromScale(0, 0.02),
					Text = "SHOP",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 1,
					Font = Enum.Font.BuilderSansExtraBold,
					TextScaled = true,
					Rotation = -8,
					create "UITextSizeConstraint" { MaxTextSize = 84 },
					create "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = Color3.fromRGB(0, 0, 0),
						Thickness = 5,
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
		-- Two cards fit inside the viewport, including the gap and vertical padding.
		local cardHeight = math.max(184, math.floor((itemList.AbsoluteSize.Y - 24) / 2))
		for _, card in cards do
			card.Size = UDim2.new(1, -10, 0, cardHeight)
		end
	end
	itemList:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCards)
	resizeCards()
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
