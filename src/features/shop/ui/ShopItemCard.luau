--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create

export type Props = {
	id: string,
	name: string?,
	stock: number?,
	price: string?,
	imageId: number?,
	imageScale: number?,
	imageOffsetX: number?,
	onBuy: (string) -> (),
}

local function outlinedText(name: string, value: string, color: Color3, position: UDim2, size: UDim2, maxTextSize: number, strokeThickness: number?): TextLabel
	local label = create "TextLabel" {
		Name = name,
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = color,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansExtraBold,
	}
	local stroke = create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = strokeThickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}
	stroke.Parent = label
	local constraint = create "UITextSizeConstraint" { MaxTextSize = maxTextSize }
	constraint.Parent = label
	return label
end

local function ShopItemCard(props: Props): ImageLabel
	local paper = create "ImageLabel" {
		Name = `ShopItem_{props.id}`,
		BackgroundTransparency = 1,
		Image = `rbxassetid://{assets.ShopPaperBanner}`,
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.new(1, -10, 0, 150),
	}

	if not (props.name and props.stock and props.price and props.imageId) then
		return paper
	end

	local iconBackground = create "ImageLabel" {
		Name = "ItemBackground",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.18, 0.5),
		Size = UDim2.fromScale(0.17, 0.82),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{assets.ShopItemBackground}`,
		ScaleType = Enum.ScaleType.Stretch,
	}
	iconBackground.Parent = paper

	local icon = create "ImageLabel" {
		Name = "ItemImage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + (props.imageOffsetX or 0), 0.5),
		Size = UDim2.fromScale(0.82 * (props.imageScale or 1), 0.88 * (props.imageScale or 1)),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{props.imageId}`,
		ScaleType = Enum.ScaleType.Crop,
	}
	icon.Parent = iconBackground

	outlinedText("ItemName", props.name, Color3.new(1, 1, 1), UDim2.fromScale(0.31, 0.02), UDim2.fromScale(0.55, 0.34), 58, 4).Parent = paper
	outlinedText("Stock", `Stock: {props.stock}`, Color3.fromRGB(255, 255, 0), UDim2.fromScale(0.31, 0.37), UDim2.fromScale(0.48, 0.30), 52, 4).Parent = paper
	local priceIcon = create "ImageLabel" {
		Name = "PriceIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.295, 0.64),
		Size = UDim2.fromScale(0.08, 0.36),
		Image = `rbxassetid://{assets.SandDollar}`,
		ScaleType = Enum.ScaleType.Fit,
	}
	priceIcon.Parent = paper
	outlinedText("Price", props.price, Color3.new(1, 1, 1), UDim2.fromScale(0.38, 0.66), UDim2.fromScale(0.37, 0.30), 55, 4).Parent = paper

	local buyButtonPosition = UDim2.fromScale(0.83, 0.76)
	local random = Random.new()
	local confettiColors = {
		Color3.fromRGB(255, 222, 66),
		Color3.fromRGB(255, 100, 168),
		Color3.fromRGB(80, 211, 255),
		Color3.fromRGB(123, 235, 97),
		Color3.fromRGB(174, 115, 255),
	}

	local function showConfetti()
		for index = 1, 12 do
			local angle = (index - 1) * math.pi / 6 + random:NextNumber(-0.18, 0.18)
			local distance = random:NextNumber(100, 240)
			local piece = create "Frame" {
				Name = "BuyConfetti",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = buyButtonPosition,
				Size = UDim2.fromOffset(random:NextInteger(5, 7), random:NextInteger(7, 10)),
				Rotation = random:NextInteger(-35, 35),
				BackgroundColor3 = confettiColors[(index - 1) % #confettiColors + 1],
				BorderSizePixel = 0,
				ZIndex = 10,
			}
			piece.Parent = paper

			local tween = TweenService:Create(piece, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(buyButtonPosition.X.Scale, math.cos(angle) * distance, buyButtonPosition.Y.Scale, math.sin(angle) * distance),
				Size = UDim2.fromOffset(3, 5),
				Rotation = piece.Rotation + random:NextInteger(-120, 120),
				BackgroundTransparency = 1,
			})
			tween.Completed:Once(function()
				piece:Destroy()
			end)
			tween:Play()
		end
	end
	local buyScale = create "UIScale" { Scale = 1 }
	local buySound = create "Sound" {
		Name = "BuyClickSound",
		SoundId = "rbxassetid://4612383453",
		Volume = 1,
	}
	local hovered = false
	local buyTween: Tween? = nil
	local function tweenBuyScale(target: number, duration: number): Tween
		if buyTween then
			buyTween:Cancel()
		end
		local tween = TweenService:Create(buyScale, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = target,
		})
		buyTween = tween
		tween:Play()
		return tween
	end
	local buyButton = create "ImageButton" {
		Name = "BuyButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = buyButtonPosition,
		Size = UDim2.fromScale(0.22, 0.31),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{assets.BuyButtonBackGround}`,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false,
		MouseEnter = function()
			hovered = true
			tweenBuyScale(1.1, 0.12)
		end,
		MouseLeave = function()
			hovered = false
			tweenBuyScale(1, 0.12)
		end,
		Activated = function()
			buySound.TimePosition = 0
			buySound:Play()
			showConfetti()
			props.onBuy(props.id)
			local pressTween = tweenBuyScale(0.94, 0.07)
			pressTween.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed then
					tweenBuyScale(if hovered then 1.1 else 1, 0.12)
				end
			end)
		end,
	}
	buyButton.Parent = paper
	buyScale.Parent = buyButton
	buySound.Parent = buyButton

	local buyText = outlinedText("BuyText", "BUY", Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 43)
	buyText.TextXAlignment = Enum.TextXAlignment.Center
	buyText.Parent = buyButton

	return paper
end

return ShopItemCard
