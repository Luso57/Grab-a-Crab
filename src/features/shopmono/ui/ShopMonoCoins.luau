--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local CoinBundles = require(ReplicatedStorage.Source.Features.Monotization.Modules.CoinBundles)

local create = Vide.create

local packages = {
	{ name = "Small", bundle = CoinBundles.Small, price = "36", coins = { { 0.5, 0.21, 0.88, 22 } } },
	{ name = "Medium", bundle = CoinBundles.Medium, price = "360", coins = { { 0.42, -0.10, 0.47, -18 }, { 0.76, 0.18, 0.54, 16 }, { 0.31, 0.41, 0.70, -8 } } },
	{ name = "Large", bundle = CoinBundles.Large, price = "720", coins = { { 0.15, -0.08, 0.37, -15 }, { 0.49, -0.06, 0.43, 10 }, { 0.85, -0.07, 0.41, -20 }, { 0.26, 0.34, 0.56, -8 }, { 0.76, 0.36, 0.52, 12 } } },
}

local function makeCard(package: typeof(packages[1]), maxMoney: () -> number, onBuyProduct: (number) -> ()): ImageLabel
	local card = create "ImageLabel" {
		Name = package.name .. "Coins",
		Size = UDim2.new(1 / 3, -8, 0, 190),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopMonoCoinCard,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	}

	for index, coin in package.coins do
		local icon = create "ImageLabel" {
			Name = "Coin" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(coin[1], coin[2]),
			Size = UDim2.fromScale(coin[3], coin[3]),
			Rotation = coin[4] or 0,
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. assets.SandDollar,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4 + index,
		}
		icon.Parent = card
	end

	local amount = create "TextLabel" {
		Name = "CoinAmount",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.96, 0.20),
		BackgroundTransparency = 1,
		Text = function()
			local high = maxMoney()
			local quantity = CoinBundles.getAmount(high, package.bundle.multiplier)
			return CompactNumber.format(quantity, 2) .. " Coins"
		end,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 10,
	}
	create "UITextSizeConstraint" { MaxTextSize = 31 }.Parent = amount
	create "UIGradient" {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 126)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 190, 27)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(231, 128, 0)),
		}),
		Rotation = 90,
	}.Parent = amount
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}.Parent = amount
	amount.Parent = card

	local buyScale = create "UIScale" { Scale = 1 }
	local buyTween: Tween? = nil
	local function setScale(scale: number)
		if buyTween then
			buyTween:Cancel()
		end
		buyTween = TweenService:Create(buyScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = scale })
		buyTween:Play()
	end

	local button = create "ImageButton" {
		Name = "RobuxButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.84),
		Size = UDim2.fromScale(0.59, 0.22),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopMonoCoinBuyButton,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false,
		ZIndex = 11,
		MouseEnter = function()
			setScale(1.1)
		end,
		MouseLeave = function()
			setScale(1)
		end,
		Activated = function()
			onBuyProduct(package.bundle.productId)
		end,
	} :: ImageButton
	buyScale.Parent = button
	button.Parent = card
	button.Destroying:Connect(function()
		if buyTween then
			buyTween:Cancel()
		end
	end)

	local robuxIcon = create "ImageLabel" {
		Name = "RobuxIcon",
		Position = UDim2.fromScale(0.19, 0.08),
		Size = UDim2.fromScale(0.27, 0.84),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.RobuxIcon,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 12,
	}
	robuxIcon.Parent = button

	local price = create "TextLabel" {
		Name = "Price",
		Position = UDim2.fromScale(0.43, 0.03),
		Size = UDim2.fromScale(0.44, 0.90),
		BackgroundTransparency = 1,
		Text = package.price,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 12,
	}
	create "UITextSizeConstraint" { MaxTextSize = 35 }.Parent = price
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 2,
	}.Parent = price
	price.Parent = button

	return card
end

local ShopMonoCoins = {}

function ShopMonoCoins.new(maxMoney: () -> number, onBuyProduct: (number) -> ()): (Frame, (boolean) -> ())
	local section = create "Frame" {
		Name = "CoinsSection",
		Size = UDim2.new(1, -58, 0, 286),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 2,
	}

	local header = create "TextLabel" {
		Name = "CoinsHeader",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "Coins",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 4,
	}
	create "UITextSizeConstraint" { MaxTextSize = 32 }.Parent = header
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}.Parent = header
	header.Parent = section

	local row = create "Frame" {
		Name = "CoinCards",
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 190),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}
	row.Parent = section
	local layout = create "UIListLayout" {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
	}
	layout.Parent = row
	local cards: { ImageLabel } = {}
	for _, package in packages do
		local card = makeCard(package, maxMoney, onBuyProduct)
		card.Parent = row
		table.insert(cards, card)
	end

	local function resize(portrait: boolean, compact: boolean)
		for index, card in cards do
			local amount = card:FindFirstChild("CoinAmount") :: TextLabel
			local button = card:FindFirstChild("RobuxButton") :: ImageButton
			amount.Position = UDim2.fromScale(0.5, if compact then 0.58 else 0.42)
			amount.Size = UDim2.fromScale(0.96, if compact then 0.16 else 0.20)
			button.Position = UDim2.fromScale(0.5, if compact then 0.87 else 0.84)
			button.Size = UDim2.fromScale(0.59, if compact then 0.20 else 0.22)
			for coinIndex, coin in packages[index].coins do
				local icon = card:FindFirstChild("Coin" .. coinIndex) :: ImageLabel
				icon.Position = UDim2.fromScale(coin[1], if compact then 0.20 + coin[2] * 0.45 else coin[2])
				icon.Size = UDim2.fromScale(coin[3] * (if compact then 0.65 else 1), coin[3] * (if compact then 0.65 else 1))
			end
		end
		if compact then
			local cardHeight = if portrait then 145 else 150
			local gap = 8
			local rowHeight = if portrait then cardHeight * 3 + gap * 2 else cardHeight
			header.Size = UDim2.new(1, 0, 0, 30)
			row.Position = UDim2.fromOffset(0, 36)
			row.Size = UDim2.new(1, 0, 0, rowHeight)
			section.Size = UDim2.new(1, -58, 0, rowHeight + 44)
			layout.Padding = UDim.new(0, gap)
			layout.FillDirection = if portrait then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
			for _, card in cards do
				card.Size = UDim2.new(if portrait then 1 else 1 / 3, if portrait then 0 else -8, 0, cardHeight)
			end
		elseif portrait then
			header.Size = UDim2.new(1, 0, 0, 34)
			row.Position = UDim2.fromOffset(0, 90)
			section.Size = UDim2.new(1, -58, 0, 686)
			row.Size = UDim2.new(1, 0, 0, 590)
			layout.Padding = UDim.new(0, 10)
			layout.FillDirection = Enum.FillDirection.Vertical
			for _, card in cards do
				card.Size = UDim2.new(1, 0, 0, 190)
			end
		else
			header.Size = UDim2.new(1, 0, 0, 34)
			row.Position = UDim2.fromOffset(0, 90)
			section.Size = UDim2.new(1, -58, 0, 286)
			row.Size = UDim2.new(1, 0, 0, 190)
			layout.Padding = UDim.new(0, 10)
			layout.FillDirection = Enum.FillDirection.Horizontal
			for _, card in cards do
				card.Size = UDim2.new(1 / 3, -8, 0, 190)
			end
		end
	end

	return section, resize
end

return ShopMonoCoins
