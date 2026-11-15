--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create

type PassDefinition = {
	name: string,
	title: string,
	description: string,
	imageId: number,
	cardId: number,
	price: number?,
}

local passes: { PassDefinition } = {
	{
		name = "InstantHatch",
		title = "INSTANT HATCH",
		description = "Incubator with Zero Hatch Time",
		imageId = assets.InstantHatchPassImage,
		cardId = assets.InstantHatchPassCard,
		price = 199,
	},
	{
		name = "HugeTank",
		title = "HUGE TANK",
		description = "Holds 20x CRABS",
		imageId = assets.HugeTankPassImage,
		cardId = assets.HugeTankPassCard,
		price = 149,
	},
	{
		name = "AutoCollect",
		title = "Auto Collect",
		description = "Auto collect cash",
		imageId = assets.AutoCollectPassImage,
		cardId = assets.AutoCollectPassCard,
		price = 180,
	},
	{
		name = "MoreInventory",
		title = "+100 Inventory",
		description = "Add more inventory space",
		imageId = assets.MoreInventoryPassImage,
		cardId = assets.MoreInventoryPassCard,
		price = 49,
	},
	{
		name = "TankIncomeOnePointFive",
		title = "1.5x Tank Income",
		description = "Increase all income by 1.5x inside a tank",
		imageId = assets.PirateCrabImg,
		cardId = assets.TankIncomeOnePointFiveCard,
		price = 180,
	},
	{
		name = "TankIncomeDouble",
		title = "2x Tank Income",
		description = "Increase all income by 2x inside a tank",
		imageId = assets.KingCrabImg,
		cardId = assets.TankIncomeDoubleCard,
		price = 320,
	},
}

local function addOutline(label: TextLabel, thickness: number)
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = thickness,
	}.Parent = label
end

local function makeCard(pass: PassDefinition, onBuy: (string) -> (), autoCollectPassOwned: () -> boolean): ImageLabel
	local card = create "ImageLabel" {
		Name = pass.name .. "Pass",
		Size = UDim2.new(1 / 3, -8, 0, 270),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. pass.cardId,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	} :: ImageLabel

	local artworkSize = if pass.name == "TankIncomeOnePointFive" or pass.name == "TankIncomeDouble" then UDim2.fromScale(1.12, 0.64)
		elseif pass.name == "HugeTank" then UDim2.fromScale(1.04, 0.60)
		elseif pass.price then UDim2.fromScale(0.96, 0.57)
		else UDim2.fromScale(0.60, 0.48)
	local artwork = create "ImageLabel" {
		Name = "PassArtwork",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if pass.name == "TankIncomeOnePointFive" then 0.29 elseif pass.name == "TankIncomeDouble" then 0.27 elseif pass.name == "HugeTank" then 0.29 else 0.30),
		Size = artworkSize,
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. pass.imageId,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}
	if pass.name == "TankIncomeOnePointFive" or pass.name == "TankIncomeDouble" then
		local outlineOffsets = {
			Vector2.new(-3, -3), Vector2.new(0, -3), Vector2.new(3, -3),
			Vector2.new(-3, 0), Vector2.new(3, 0),
			Vector2.new(-3, 3), Vector2.new(0, 3), Vector2.new(3, 3),
		}
		for index, offset in outlineOffsets do
			create "ImageLabel" {
				Name = "ArtworkOutline" .. index,
				AnchorPoint = artwork.AnchorPoint,
				Position = artwork.Position + UDim2.fromOffset(offset.X, offset.Y),
				Size = artwork.Size,
				BackgroundTransparency = 1,
				Image = artwork.Image,
				ImageColor3 = Color3.new(0, 0, 0),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 4,
			}.Parent = card
		end
	end
	artwork.Parent = card

	local starPositions: { Vector2 } = if pass.name == "MoreInventory" then {} elseif pass.name == "AutoCollect" then {
		Vector2.new(0.12, 0.30),
		Vector2.new(0.88, 0.57),
	} else {
		Vector2.new(0.12, 0.13),
		Vector2.new(0.88, 0.16),
		Vector2.new(0.10, 0.46),
		Vector2.new(0.91, 0.48),
	}
	for index, position in starPositions do
		local star = create "ImageLabel" {
			Name = "Star" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(position.X, position.Y),
			Size = if pass.price then UDim2.fromScale(0.18, 0.21) else UDim2.fromScale(0.13, 0.15),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. assets.ShopMonoPassStar,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
		}
		star.Parent = card
	end

	local title = create "TextLabel" {
		Name = "PassTitle",
		Position = UDim2.fromScale(0.05, 0.59),
		Size = UDim2.fromScale(0.90, 0.12),
		BackgroundTransparency = 1,
		Text = pass.title,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 6,
	}
	create "UITextSizeConstraint" { MaxTextSize = 36 }.Parent = title
	addOutline(title, 3)
	title.Parent = card

	local description = create "TextLabel" {
		Name = "PassDescription",
		Position = UDim2.fromScale(0.06, 0.70),
		Size = UDim2.fromScale(0.88, 0.07),
		BackgroundTransparency = 1,
		Text = pass.description,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 6,
	}
	create "UITextSizeConstraint" { MaxTextSize = 19 }.Parent = description
	addOutline(description, 2)
	description.Parent = card

	local buttonScale = create "UIScale" { Scale = 1 }
	local buttonTween: Tween? = nil
	local function setButtonScale(scale: number)
		if buttonTween then
			buttonTween:Cancel()
		end
		buttonTween = TweenService:Create(buttonScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = scale })
		buttonTween:Play()
	end

	local button = create "ImageButton" {
		Name = "RobuxButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(0.44, 0.16),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopMonoCoinBuyButton,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false,
		Visible = pass.price ~= nil,
		ZIndex = 7,
		MouseEnter = function()
			setButtonScale(1.1)
		end,
		MouseLeave = function()
			setButtonScale(1)
		end,
		Activated = function()
			if pass.name == "InstantHatch" or pass.name == "HugeTank" or pass.name == "AutoCollect"
				or pass.name == "MoreInventory"
				or pass.name == "TankIncomeOnePointFive" or pass.name == "TankIncomeDouble" then
				onBuy(pass.name)
			end
		end,
	} :: ImageButton
	buttonScale.Parent = button
	button.Parent = card
	button.Destroying:Connect(function()
		if buttonTween then
			buttonTween:Cancel()
		end
	end)

	local robuxIcon = create "ImageLabel" {
		Name = "RobuxIcon",
		Visible = function()
			return pass.name ~= "AutoCollect" or not autoCollectPassOwned()
		end,
		Position = UDim2.fromScale(0.14, 0.09),
		Size = UDim2.fromScale(0.30, 0.82),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.RobuxIcon,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 8,
	}
	robuxIcon.Parent = button

	local price = create "TextLabel" {
		Name = "Price",
		Position = function()
			return if pass.name == "AutoCollect" and autoCollectPassOwned() then UDim2.fromScale(0, 0.06) else UDim2.fromScale(0.44, 0.06)
		end,
		Size = function()
			return if pass.name == "AutoCollect" and autoCollectPassOwned() then UDim2.fromScale(1, 0.85) else UDim2.fromScale(0.45, 0.85)
		end,
		BackgroundTransparency = 1,
		Text = function()
			return if pass.name == "AutoCollect" and autoCollectPassOwned() then "OWNED" elseif pass.price then tostring(pass.price) else ""
		end,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 8,
	}
	create "UITextSizeConstraint" { MaxTextSize = 32 }.Parent = price
	addOutline(price, 2)
	price.Parent = button

	return card
end

local ShopMonoPasses = {}

function ShopMonoPasses.new(onBuy: (string) -> (), autoCollectPassOwned: () -> boolean): (Frame, (boolean) -> ())
	local section = create "Frame" {
		Name = "PassesSection",
		Size = UDim2.new(1, -58, 0, 602),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 2,
	}

	local header = create "TextLabel" {
		Name = "PassesHeader",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "Shop",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 4,
	}
	create "UITextSizeConstraint" { MaxTextSize = 34 }.Parent = header
	addOutline(header, 3)
	header.Parent = section

	local row = create "Frame" {
		Name = "PassCards",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 552),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}
	row.Parent = section

	local layout = create "UIGridLayout" {
		CellSize = UDim2.new(1 / 3, -8, 0, 270),
		CellPadding = UDim2.fromOffset(12, 12),
		FillDirectionMaxCells = 3,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}
	layout.Parent = row

	for index, pass in passes do
		local card = makeCard(pass, onBuy, autoCollectPassOwned)
		card.LayoutOrder = index
		card.Parent = row
	end

	local function resize(portrait: boolean, compact: boolean)
		if compact then
			local cardHeight = if portrait then 190 else 210
			local gap = 8
			local rows = if portrait then 6 else 2
			local rowHeight = rows * cardHeight + (rows - 1) * gap
			header.Size = UDim2.new(1, 0, 0, 30)
			row.Position = UDim2.fromOffset(0, 36)
			row.Size = UDim2.new(1, 0, 0, rowHeight)
			section.Size = UDim2.new(1, -58, 0, rowHeight + 44)
			layout.CellPadding = UDim2.fromOffset(gap, gap)
			layout.FillDirectionMaxCells = if portrait then 1 else 3
			layout.CellSize = UDim2.new(if portrait then 1 else 1 / 3, -8, 0, cardHeight)
		elseif portrait then
			header.Size = UDim2.new(1, 0, 0, 36)
			row.Position = UDim2.fromOffset(0, 42)
			section.Size = UDim2.new(1, -58, 0, 1604)
			row.Size = UDim2.new(1, 0, 0, 1554)
			layout.CellPadding = UDim2.fromOffset(12, 12)
			layout.FillDirectionMaxCells = 1
			layout.CellSize = UDim2.new(1, -8, 0, 249)
		else
			header.Size = UDim2.new(1, 0, 0, 36)
			row.Position = UDim2.fromOffset(0, 42)
			section.Size = UDim2.new(1, -58, 0, 602)
			row.Size = UDim2.new(1, 0, 0, 552)
			layout.CellPadding = UDim2.fromOffset(12, 12)
			layout.FillDirectionMaxCells = 3
			layout.CellSize = UDim2.new(1 / 3, -8, 0, 270)
		end
	end

	return section, resize
end

return ShopMonoPasses
