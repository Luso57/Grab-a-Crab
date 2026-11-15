--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)

local create = Vide.create

export type Props = {
	id: string,
	name: string?,
	compact: () -> boolean,
	stock: () -> number,
	price: number?,
	robuxPrice: (() -> string)?,
	boostPercent: number?,
	imageId: number?,
	imageScale: number?,
	imageOffsetX: number?,
	onBuy: (string, Vector2) -> boolean,
	onRobuxBuy: (string, Vector2) -> (),
}

local function outlinedText(name: string, value: string | (() -> string), color: Color3, position: UDim2, size: UDim2, maxTextSize: number, strokeThickness: number?): TextLabel
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

	local itemName = outlinedText("ItemName", props.name, Color3.new(1, 1, 1), UDim2.fromScale(0.31, 0.02),
		UDim2.fromScale(if props.boostPercent then 0.35 else 0.55, 0.34), 58, 4)
	itemName.Parent = paper
	local stockLabel = outlinedText("Stock", function()
		return `Stock: {props.stock()}`
	end, Color3.fromRGB(255, 255, 0), UDim2.fromScale(0.31, 0.37), UDim2.fromScale(if props.boostPercent then 0.34 else 0.48, 0.30), 52, 4)
	stockLabel.Parent = paper

	local boostLabel: TextLabel? = nil
	if props.boostPercent then
		local boost = outlinedText("TankIncomeBoost", `+{props.boostPercent}% Tank Boost`,
			Color3.fromRGB(80, 235, 88), UDim2.fromScale(0.67, 0.10), UDim2.fromScale(0.31, 0.21), 28, 3)
		boost.TextXAlignment = Enum.TextXAlignment.Center
		boost.Parent = paper
		boostLabel = boost
	end
	local priceIcon = create "ImageLabel" {
		Name = "PriceIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.295, 0.64),
		Size = UDim2.fromScale(0.08, 0.36),
		Image = `rbxassetid://{assets.SandDollar}`,
		ScaleType = Enum.ScaleType.Fit,
	}
	priceIcon.Parent = paper
	local priceLabel = outlinedText("Price", CompactNumber.format(props.price :: number), Color3.new(1, 1, 1), UDim2.fromScale(0.38, 0.66), UDim2.fromScale(0.37, 0.30), 55, 4)
	priceLabel.Parent = paper

	local desktopBuyButtonPosition = UDim2.fromScale(0.83, if props.robuxPrice then 0.59 else 0.76)
	local buyButtonPosition = desktopBuyButtonPosition
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
		Size = UDim2.fromScale(0.22, if props.robuxPrice then 0.23 else 0.31),
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
			if props.stock() <= 0 or not props.onBuy(props.id, icon.AbsolutePosition + icon.AbsoluteSize / 2) then
				return
			end
			buySound.TimePosition = 0
			buySound:Play()
			showConfetti()
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

	local buyText = outlinedText("BuyText", function()
		if props.stock() <= 0 then
			return "SOLD OUT"
		end
		return "BUY"
	end, Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 43)
	buyText.TextXAlignment = Enum.TextXAlignment.Center
	buyText.Parent = buyButton

	local robuxButton: ImageButton? = nil
	if props.robuxPrice then
		local robuxScale = create "UIScale" { Scale = 1 }
		local robuxTween: Tween? = nil
		local function tweenRobuxScale(target: number)
			if robuxTween then
				robuxTween:Cancel()
			end
			robuxTween = TweenService:Create(robuxScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = target,
			})
			robuxTween:Play()
		end

		local button = create "ImageButton" {
			Name = "RobuxButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.83, 0.85),
			Size = UDim2.fromScale(0.22, 0.23),
			BackgroundTransparency = 1,
			Image = `rbxassetid://{assets.ShopMonoCoinBuyButton}`,
			ScaleType = Enum.ScaleType.Stretch,
			AutoButtonColor = false,
			MouseEnter = function()
				tweenRobuxScale(1.1)
			end,
			MouseLeave = function()
				tweenRobuxScale(1)
			end,
			Activated = function()
				props.onRobuxBuy(props.id, icon.AbsolutePosition + icon.AbsoluteSize / 2)
			end,
		}
		button.Parent = paper
		robuxButton = button
		robuxScale.Parent = button
		button.Destroying:Connect(function()
			if robuxTween then
				robuxTween:Cancel()
			end
		end)

		local robuxIcon = create "ImageLabel" {
			Name = "RobuxIcon",
			Position = UDim2.fromScale(0.15, 0.08),
			Size = UDim2.fromScale(0.34, 0.84),
			BackgroundTransparency = 1,
			Image = `rbxassetid://{assets.RobuxIcon}`,
			ScaleType = Enum.ScaleType.Fit,
		}
		robuxIcon.Parent = button

		local robuxPrice = outlinedText("RobuxPrice", props.robuxPrice, Color3.new(1, 1, 1),
			UDim2.fromScale(0.48, 0.08), UDim2.fromScale(0.40, 0.84), 35)
		robuxPrice.TextXAlignment = Enum.TextXAlignment.Center
		robuxPrice.Parent = button
	end

	local originalThickness: { [UIStroke]: number } = {}
	local originalTextSize: { [UITextSizeConstraint]: number } = {}
	local compactMaxSize: { [string]: number } = {
		ItemName = 32,
		Stock = 28,
		TankIncomeBoost = 18,
		Price = 32,
		BuyText = 25,
		RobuxPrice = 23,
	}
	Vide.effect(function()
		local mobile = props.compact()
		iconBackground.Position = UDim2.fromScale(if mobile then 0.21 else 0.18, 0.5)
		iconBackground.Size = UDim2.fromScale(if mobile then 0.23 else 0.17, if mobile then 0.76 else 0.82)
		icon.Size = if mobile then UDim2.fromScale(0.88 * (props.imageScale or 1), 0.88 * (props.imageScale or 1))
			else UDim2.fromScale(0.82 * (props.imageScale or 1), 0.88 * (props.imageScale or 1))
		icon.ScaleType = if mobile then Enum.ScaleType.Fit else Enum.ScaleType.Crop
		itemName.Position = UDim2.fromScale(if mobile then 0.35 else 0.31, if mobile then (if boostLabel then 0.09 else 0.12) else 0.02)
		itemName.Size = if mobile then UDim2.fromScale(0.43, if boostLabel then 0.18 else 0.22)
			else UDim2.fromScale(if boostLabel then 0.35 else 0.55, 0.34)
		stockLabel.Position = UDim2.fromScale(if mobile then 0.35 else 0.31, if mobile then (if boostLabel then 0.49 else 0.36) else 0.37)
		stockLabel.Size = if mobile then UDim2.fromScale(0.31, if boostLabel then 0.16 else 0.18)
			else UDim2.fromScale(if boostLabel then 0.34 else 0.48, 0.30)
		if boostLabel then
			boostLabel.TextXAlignment = if mobile then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
			boostLabel.Position = UDim2.fromScale(if mobile then 0.35 else 0.67, if mobile then 0.29 else 0.10)
			boostLabel.Size = if mobile then UDim2.fromScale(0.31, 0.15) else UDim2.fromScale(0.31, 0.21)
		end
		priceIcon.Position = UDim2.fromScale(if mobile then 0.35 else 0.295, if mobile then (if boostLabel then 0.665 else 0.60) else 0.64)
		priceIcon.Size = if mobile then UDim2.fromScale(0.085, 0.25) else UDim2.fromScale(0.08, 0.36)
		priceLabel.Position = UDim2.fromScale(if mobile then 0.445 else 0.38, if mobile then (if boostLabel then 0.69 else 0.60) else 0.66)
		priceLabel.Size = if mobile then UDim2.fromScale(0.215, if boostLabel then 0.20 else 0.22) else UDim2.fromScale(0.37, 0.30)
		buyButton.Position = if mobile then UDim2.fromScale(0.81, if robuxButton then 0.50 else 0.64) else desktopBuyButtonPosition
		buyButtonPosition = buyButton.Position
		buyButton.Size = if mobile then UDim2.fromScale(0.23, if robuxButton then 0.22 else 0.25)
			else UDim2.fromScale(0.22, if robuxButton then 0.23 else 0.31)
		if robuxButton then
			robuxButton.Position = UDim2.fromScale(if mobile then 0.81 else 0.83, if mobile then 0.78 else 0.85)
			robuxButton.Size = if mobile then UDim2.fromScale(0.23, 0.22) else UDim2.fromScale(0.22, 0.23)
		end
		for _, descendant in paper:GetDescendants() do
			if descendant:IsA("TextLabel") then
				descendant.TextStrokeTransparency = if mobile then 0.45 else 0
				local constraint = descendant:FindFirstChildOfClass("UITextSizeConstraint")
				if constraint then
					local fullSize = originalTextSize[constraint]
					if fullSize == nil then
						fullSize = constraint.MaxTextSize
						originalTextSize[constraint] = fullSize
					end
					constraint.MaxTextSize = if mobile then math.min(fullSize, compactMaxSize[descendant.Name] or 32) else fullSize
				end
				local stroke = descendant:FindFirstChildOfClass("UIStroke")
				if stroke then
					local fullThickness = originalThickness[stroke]
					if fullThickness == nil then
						fullThickness = stroke.Thickness
						originalThickness[stroke] = fullThickness
					end
					stroke.Thickness = if mobile then fullThickness * 0.65 else fullThickness
				end
			end
		end
	end)

	return paper
end

return ShopItemCard
