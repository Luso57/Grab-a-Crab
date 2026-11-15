--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local DecorConfig = require(ReplicatedStorage.Source.Features.DecorShop.DecorConfig)

local create = Vide.create

export type Card = {
	instanceId: string,
	name: string,
	imageId: number,
	weight: string,
	income: string,
	isBoost: boolean,
	sellPrice: string,
	canSell: boolean,
}

export type AvailableCrab = {
	instanceId: string,
	name: string,
	imageId: number,
	weightGrams: number,
	weight: string,
}

export type Props = {
	cards: () -> { Card },
	capacity: () -> number,
	availableCrabs: () -> { AvailableCrab },
	crabPickerOpen: () -> boolean,
	crabPlacementMessage: () -> string,
	boostPercent: () -> number,
	decorCounts: () -> { [string]: number },
	decorSlots: () -> { [number]: { instanceId: string, decorId: string } },
	selectedDecorSlot: () -> number?,
	isOpen: () -> boolean,
	onClose: () -> (),
	onOpenCrabPicker: () -> (),
	onCloseCrabPicker: () -> (),
	onChooseCrab: (string) -> (),
	onDecorSlotSelected: (number) -> (),
	onCloseDecorations: () -> (),
	onChooseDecoration: (string) -> (),
	onPickupDecoration: (string, Vector2) -> (),
	onPickUp: (string, Vector2) -> (),
	onSell: (string) -> (),
}

local function outlinedText(name: string, value: () -> string, position: UDim2, size: UDim2, maxSize: number, strokeThickness: number?, visible: (() -> boolean)?): TextLabel
	local label = create "TextLabel" {
		Name = name,
		BackgroundTransparency = 1,
		Visible = if visible then visible else true,
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

local function makeCard(index: number, cards: () -> { Card }, onPickUp: (string, Vector2) -> (), onSell: (string) -> ()): ImageLabel
	local function info(): Card?
		return cards()[index]
	end

	local card = create "ImageLabel" {
		Name = "CrabCard" .. index,
		LayoutOrder = index,
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TankCArdPopUP,
		ScaleType = Enum.ScaleType.Stretch,
		Visible = function()
			return info() ~= nil
		end,
		Size = UDim2.new(1, -8, 0, 210),
	}

	local crabImage = create "ImageLabel" {
		Name = "CrabImage",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.025, 0.08),
		Size = UDim2.fromScale(0.305, 0.84),
		Image = function()
			local item = info()
			return if item then "rbxassetid://" .. item.imageId else ""
		end,
		ScaleType = Enum.ScaleType.Crop,
	}
	crabImage.Parent = card
	local weightText = outlinedText("CrabWeight", function()
		local item = info()
		return if item then item.weight else ""
	end, UDim2.fromScale(0.07, 0.73), UDim2.fromScale(0.86, 0.22), 24, 2.5)
	weightText.TextXAlignment = Enum.TextXAlignment.Center
	weightText.ZIndex = 2
	weightText.Parent = crabImage

	outlinedText("CrabName", function()
		local item = info()
		return if item then string.upper(item.name) else ""
	end, UDim2.fromScale(0.36, 0.07), UDim2.fromScale(0.59, 0.25), 40).Parent = card

	create "ImageLabel" {
		Name = "CoinIcon",
		Visible = function()
			local item = info()
			return item ~= nil and not item.isBoost
		end,
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
				onPickUp(item.instanceId, crabImage.AbsolutePosition + crabImage.AbsoluteSize / 2)
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

	local sellScale = create "UIScale" { Scale = 1 }
	local sellTween: Tween? = nil
	local function setSellScale(value: number)
		if sellTween then
			sellTween:Cancel()
		end
		local tween = TweenService:Create(sellScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = value,
		})
		sellTween = tween
		tween:Play()
	end
	local sell = create "ImageButton" {
		Name = "SellButton",
		Visible = function()
			local item = info()
			return item ~= nil and item.canSell
		end,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.83, 0.82),
		Size = UDim2.fromScale(0.26, 0.18),
		Image = "rbxassetid://" .. assets.TankSellButton,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false,
		MouseEnter = function()
			setSellScale(1.1)
		end,
		MouseLeave = function()
			setSellScale(1)
		end,
		Activated = function()
			local item = info()
			if item then
				setSellScale(1)
				onSell(item.instanceId)
			end
		end,
	}
	sell.Parent = card
	sellScale.Parent = sell
	local sellText = outlinedText("SellText", function()
		local item = info()
		return if item then "SELL $" .. item.sellPrice else "SELL"
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
	local sellSound = create "Sound" {
		Name = "SellSound",
		SoundId = "rbxassetid://4612383453",
		Volume = 1,
	}
	local function onSell(instanceId: string)
		sellSound.TimePosition = 0
		sellSound:Play()
		props.onSell(instanceId)
	end
	local function onPickUp(instanceId: string, startPosition: Vector2)
		closeSound.TimePosition = 0
		closeSound:Play()
		props.onPickUp(instanceId, startPosition)
	end
	local cardInstances = {
		makeCard(1, props.cards, onPickUp, onSell),
		makeCard(2, props.cards, onPickUp, onSell),
		makeCard(3, props.cards, onPickUp, onSell),
		makeCard(4, props.cards, onPickUp, onSell),
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
		DisplayOrder = 35,
		Enabled = visible,
	}

	closeSound.Parent = gui
	sellSound.Parent = gui

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
	local aspectRatio = create "UIAspectRatioConstraint" {
		AspectRatio = 0.86,
		DominantAxis = Enum.DominantAxis.Width,
	}
	aspectRatio.Parent = background
	create "UISizeConstraint" {
		MaxSize = Vector2.new(620, 720),
	}.Parent = background

	local titleBanner = create "ImageLabel" {
		Name = "CrabsTitleBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.17, 0.015),
		Size = UDim2.fromScale(0.38, 0.093),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TopBarCard,
		ImageColor3 = Color3.fromRGB(255, 176, 72),
		ScaleType = Enum.ScaleType.Stretch,
	}
	titleBanner.Parent = background
	local title = outlinedText("CrabsTitle", function()
		return "CRABS"
	end, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.90, 0.76), 39, 3)
	title.TextXAlignment = Enum.TextXAlignment.Center
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
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.86, 0.56),
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
		SortOrder = Enum.SortOrder.LayoutOrder,
	}.Parent = list
	create "UIPadding" {
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
	}.Parent = list

	for _, card in cardInstances do
		card.Parent = list
	end

	local addCrabTile = create "ImageButton" {
		Name = "AddCrabTile",
		LayoutOrder = 5,
		Size = UDim2.new(1, -8, 0, 112),
		BackgroundColor3 = Color3.fromRGB(94, 51, 20),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = true,
		Visible = function()
			return props.capacity() > #props.cards()
		end,
		Activated = props.onOpenCrabPicker,
	}
	addCrabTile.Parent = list
	create "UICorner" { CornerRadius = UDim.new(0, 8) }.Parent = addCrabTile
	local dashColor = Color3.fromRGB(255, 225, 155)
	for index = 0, 10 do
		for _, y in { 0, 1 } do
			create "Frame" {
				Position = UDim2.new(index / 11, 3, y, if y == 0 then 2 else -5),
				Size = UDim2.new(0.06, 0, 0, 3),
				BackgroundColor3 = dashColor,
				BorderSizePixel = 0,
			}.Parent = addCrabTile
		end
	end
	for index = 0, 3 do
		for _, x in { 0, 1 } do
			create "Frame" {
				Position = UDim2.new(x, if x == 0 then 2 else -5, index / 4, 4),
				Size = UDim2.new(0, 3, 0.14, 0),
				BackgroundColor3 = dashColor,
				BorderSizePixel = 0,
			}.Parent = addCrabTile
		end
	end
	local addCrabText = outlinedText("AddCrabText", function()
		return "ADD CRAB"
	end, UDim2.fromScale(0.08, 0.2), UDim2.fromScale(0.84, 0.6), 32, 3)
	addCrabText.TextXAlignment = Enum.TextXAlignment.Center
	addCrabText.Parent = addCrabTile

	local decorBanner = create "ImageLabel" {
		Name = "DecorBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(0.94, 0.205),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopPaperBanner,
		ScaleType = Enum.ScaleType.Stretch,
	}
	decorBanner.Parent = background

	for index = 1, 4 do
		local slotScale = create "UIScale" { Scale = 1 }
		local slotTween: Tween? = nil
		local hovering = false
		local hovered = Vide.source(false)
		local function tweenSlot(target: number)
			if slotTween then
				slotTween:Cancel()
			end
			local tween = TweenService:Create(slotScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = target,
			})
			slotTween = tween
			tween:Play()
		end
		local slot: ImageButton
		slot = create "ImageButton" {
			Name = "DecorSlot" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.19 + (index - 1) * 0.205, 0.52),
			Size = UDim2.fromScale(0.155, 0.6),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. assets.ShopItemBackground,
			ScaleType = Enum.ScaleType.Stretch,
			AutoButtonColor = false,
			MouseEnter = function()
				hovering = true
				hovered(true)
				tweenSlot(1.08)
			end,
			MouseLeave = function()
				hovering = false
				hovered(false)
				tweenSlot(1)
			end,
			Activated = function()
				local placed = props.decorSlots()[index]
				if placed then
					closeSound.TimePosition = 0
					closeSound:Play()
					props.onCloseDecorations()
					props.onPickupDecoration(placed.instanceId, slot.AbsolutePosition + slot.AbsoluteSize / 2)
				else
					props.onDecorSlotSelected(index)
				end
				tweenSlot(0.94)
				task.delay(0.08, function()
					if slotScale.Parent then
						tweenSlot(if hovering then 1.08 else 1)
					end
				end)
			end,
		}
		slot.Parent = decorBanner
		slotScale.Parent = slot
		create "ImageLabel" {
			Name = "PlacedDecoration",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.08, 0.08),
			Size = UDim2.fromScale(0.84, 0.84),
			ScaleType = Enum.ScaleType.Fit,
			Image = function()
				local placed = props.decorSlots()[index]
				local definition = if placed then DecorConfig.get(placed.decorId) else nil
				return if definition then "rbxassetid://" .. definition.imageId else ""
			end,
		}.Parent = slot
		create "TextLabel" {
			Name = "RemoveDecorationHint",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.98, 0.01),
			Size = UDim2.fromScale(0.43, 0.43),
			BackgroundTransparency = 1,
			Text = "X",
			TextColor3 = Color3.fromRGB(255, 38, 42),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
			ZIndex = 3,
			Visible = function()
				return hovered() and props.decorSlots()[index] ~= nil
			end,
		}.Parent = slot
		create "UICorner" { CornerRadius = UDim.new(0, 8) }.Parent = slot
		create "UIStroke" {
			Name = "SelectedStroke",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(255, 225, 100),
			Thickness = 3,
			Transparency = function()
				return if props.selectedDecorSlot() == index then 0 else 1
			end,
		}.Parent = slot
	end

	local decorPlank = create "ImageLabel" {
		Name = "DecorTitleBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.19, 0.71),
		Size = UDim2.fromScale(0.32, 0.074),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TopBarCard,
		ImageColor3 = Color3.fromRGB(255, 176, 72),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	}
	decorPlank.Parent = background
	local decorTitle = outlinedText("DecorTitle", function()
		return "DECOR"
	end, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.90, 0.76), 34, 3)
	decorTitle.TextXAlignment = Enum.TextXAlignment.Center
	decorTitle.ZIndex = 4
	decorTitle.Parent = decorPlank

	local boostLabel = outlinedText("TankBoostPercent", function()
		return `+{props.boostPercent()}% BOOSTED`
	end, UDim2.fromScale(0.55, 0.668), UDim2.fromScale(0.38, 0.055), 24, 2.5, function()
		return props.boostPercent() > 0
	end)
	boostLabel.TextColor3 = Color3.fromRGB(80, 235, 88)
	boostLabel.TextXAlignment = Enum.TextXAlignment.Right
	boostLabel.ZIndex = 4
	boostLabel.Parent = background

	local empty = create "TextLabel" {
		Name = "EmptyMessage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.84, 0.22),
		BackgroundTransparency = 1,
		Text = "NO CRABS IN THIS TANK",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		Visible = function()
			return #props.cards() == 0 and props.capacity() <= 0
		end,
	}
	empty.Parent = background
	create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = 3.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}.Parent = empty
	create "UITextSizeConstraint" { MaxTextSize = 42 }.Parent = empty

	local decorationsPanel = create "Frame" {
		Name = "DecorationsPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(1.025, 0.48),
		Size = UDim2.fromScale(0.48, 0.63),
		BackgroundColor3 = Color3.fromRGB(48, 32, 19),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = function()
			return props.isOpen() and props.selectedDecorSlot() ~= nil
		end,
	}
	decorationsPanel.Parent = background
	local decorationsAspect = create "UIAspectRatioConstraint" {
		AspectRatio = 1,
		DominantAxis = Enum.DominantAxis.Width,
	}
	decorationsAspect.Parent = decorationsPanel
	create "UICorner" { CornerRadius = UDim.new(0, 10) }.Parent = decorationsPanel
	create "UIStroke" {
		Color = Color3.fromRGB(107, 58, 19),
		Thickness = 3,
	}.Parent = decorationsPanel

	local decorationsTitle = outlinedText("DecorationsTitle", function()
		return "DECORATIONS"
	end, UDim2.fromScale(0.06, 0.035), UDim2.fromScale(0.76, 0.11), 30, 2.5)
	decorationsTitle.ZIndex = 6
	decorationsTitle.Parent = decorationsPanel

	local closeDecorations = create "TextButton" {
		Name = "CloseDecorations",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.035),
		Size = UDim2.fromScale(0.13, 0.1),
		BackgroundTransparency = 1,
		Text = "X",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 6,
		Activated = props.onCloseDecorations,
	}
	closeDecorations.Parent = decorationsPanel
	create "UITextSizeConstraint" { MaxTextSize = 28 }.Parent = closeDecorations

	local decorList = create "ScrollingFrame" {
		Name = "OwnedDecorations",
		Position = UDim2.fromScale(0.06, 0.18),
		Size = UDim2.fromScale(0.88, 0.76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(209, 158, 77),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
		Visible = function()
			local index = props.selectedDecorSlot()
			return index ~= nil and props.decorSlots()[index] == nil
		end,
	}
	decorList.Parent = decorationsPanel
	local decorGrid = create "UIGridLayout" {
		CellSize = UDim2.fromOffset(80, 80),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}
	decorGrid.Parent = decorList
	local function resizeDecorGrid()
		local cellSize = math.max(1, math.min(112, math.floor((decorList.AbsoluteSize.X - 12) / 2)))
		decorGrid.CellSize = UDim2.fromOffset(cellSize, cellSize)
	end
	decorList:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeDecorGrid)
	resizeDecorGrid()

	for index, definition in DecorConfig.items do
		local decorCard = create "ImageButton" {
			Name = "OwnedDecor_" .. definition.id,
			Size = UDim2.fromOffset(100, 112),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. assets.ShopItemBackground,
			ScaleType = Enum.ScaleType.Stretch,
			LayoutOrder = index,
			ZIndex = 7,
			AutoButtonColor = true,
			Activated = function()
				props.onChooseDecoration(definition.id)
			end,
			Visible = function()
				return (props.decorCounts()[definition.id] or 0) > 0
			end,
		}
		decorCard.Parent = decorList
		create "ImageLabel" {
			Name = "ItemImage",
			Position = UDim2.fromScale(0.08, 0.06),
			Size = UDim2.fromScale(0.84, 0.62),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. definition.imageId,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8,
		}.Parent = decorCard
		local name = outlinedText("ItemName", function()
			return definition.name
		end, UDim2.fromScale(0.04, 0.69), UDim2.fromScale(0.92, 0.22), 17, 2)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.ZIndex = 8
		name.Parent = decorCard
		local count = outlinedText("Count", function()
			return "x" .. tostring(props.decorCounts()[definition.id] or 0)
		end, UDim2.fromScale(0.64, 0.04), UDim2.fromScale(0.3, 0.2), 17, 2)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.ZIndex = 8
		count.Parent = decorCard
	end

	local noDecorations = create "TextLabel" {
		Name = "NoDecorations",
		Position = UDim2.fromScale(0.08, 0.43),
		Size = UDim2.fromScale(0.84, 0.14),
		BackgroundTransparency = 1,
		Text = "NO DECORATIONS IN BACKPACK",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 7,
		Visible = function()
			local index = props.selectedDecorSlot()
			if index and props.decorSlots()[index] then
				return false
			end
			for _, count in props.decorCounts() do
				if count > 0 then
					return false
				end
			end
			return true
		end,
	}
	noDecorations.Parent = decorationsPanel
	create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = 2.5,
	}.Parent = noDecorations
	create "UITextSizeConstraint" { MaxTextSize = 22 }.Parent = noDecorations

	local crabPicker = create "Frame" {
		Name = "CrabInventoryPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(1.025, 0.48),
		Size = UDim2.fromScale(0.48, 0.63),
		BackgroundColor3 = Color3.fromRGB(48, 32, 19),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = function()
			return props.isOpen() and props.crabPickerOpen() and props.capacity() > #props.cards()
		end,
	}
	crabPicker.Parent = background
	create "UICorner" { CornerRadius = UDim.new(0, 10) }.Parent = crabPicker
	create "UIStroke" { Color = Color3.fromRGB(107, 58, 19), Thickness = 3 }.Parent = crabPicker

	local crabPickerTitle = outlinedText("CrabInventoryTitle", function()
		return "YOUR CRABS"
	end, UDim2.fromScale(0.06, 0.035), UDim2.fromScale(0.76, 0.11), 30, 2.5)
	crabPickerTitle.ZIndex = 6
	crabPickerTitle.Parent = crabPicker

	local closeCrabPicker = create "TextButton" {
		Name = "CloseCrabInventory",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.035),
		Size = UDim2.fromScale(0.13, 0.1),
		BackgroundTransparency = 1,
		Text = "X",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 6,
		Activated = props.onCloseCrabPicker,
	}
	closeCrabPicker.Parent = crabPicker
	create "UITextSizeConstraint" { MaxTextSize = 28 }.Parent = closeCrabPicker

	local placementMessage = outlinedText("CrabPlacementMessage", props.crabPlacementMessage,
		UDim2.fromScale(0.06, 0.13), UDim2.fromScale(0.88, 0.075), 17, 2)
	placementMessage.TextXAlignment = Enum.TextXAlignment.Center
	placementMessage.ZIndex = 6
	placementMessage.Parent = crabPicker

	local crabInventoryList = create "ScrollingFrame" {
		Name = "OwnedCrabs",
		Position = UDim2.fromScale(0.06, 0.22),
		Size = UDim2.fromScale(0.88, 0.72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(209, 158, 77),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
	}
	crabInventoryList.Parent = crabPicker
	create "UIGridLayout" {
			CellSize = UDim2.new(0.48, -8, 0, 112),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
	}.Parent = crabInventoryList
	Vide.indexes(props.availableCrabs, function(entry, index)
			local crabCard = create "ImageButton" {
				Name = "OwnedCrab_" .. index,
				Size = UDim2.fromOffset(100, 112),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. assets.ShopItemBackground,
				ScaleType = Enum.ScaleType.Stretch,
				LayoutOrder = index,
				ZIndex = 7,
				AutoButtonColor = true,
				Activated = function()
					local crab = entry()
					if crab then
						props.onChooseCrab(crab.instanceId)
					end
				end,
			}
			create "ImageLabel" {
				Name = "CrabImage",
				Position = UDim2.fromScale(0.08, 0.05),
				Size = UDim2.fromScale(0.84, 0.61),
				BackgroundTransparency = 1,
				Image = function()
					local crab = entry()
					return if crab then "rbxassetid://" .. crab.imageId else ""
				end,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 8,
			}.Parent = crabCard
			local name = outlinedText("CrabName", function()
				local crab = entry()
				return if crab then crab.name else ""
			end, UDim2.fromScale(0.04, 0.64), UDim2.fromScale(0.92, 0.17), 17, 2)
			name.TextXAlignment = Enum.TextXAlignment.Center
			name.ZIndex = 8
			name.Parent = crabCard
			local weight = outlinedText("Weight", function()
				local crab = entry()
				return if crab then crab.weight else ""
			end, UDim2.fromScale(0.04, 0.82), UDim2.fromScale(0.92, 0.15), 15, 2)
			weight.TextXAlignment = Enum.TextXAlignment.Center
			weight.ZIndex = 8
			weight.Parent = crabCard
			crabCard.Parent = crabInventoryList
			Vide.cleanup(crabCard)
			return crabCard
	end)

	local noCrabs = outlinedText("NoCrabsInInventory", function()
		return "NO CRABS IN BACKPACK"
	end, UDim2.fromScale(0.08, 0.43), UDim2.fromScale(0.84, 0.14), 22, 2.5,
	function()
		return #props.availableCrabs() == 0
	end)
	noCrabs.TextXAlignment = Enum.TextXAlignment.Center
	noCrabs.ZIndex = 7
	noCrabs.Parent = crabPicker

	local function resizeCards()
		local height = math.max(80, math.floor(math.min((list.AbsoluteSize.X - 8) / 2.8, (list.AbsoluteSize.Y - 22) / 2)))
		for _, card in cardInstances do
			card.Size = UDim2.new(1, -8, 0, height)
		end
		addCrabTile.Size = UDim2.new(1, -8, 0, math.max(100, math.floor(height * 0.55)))
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

	local compactText = false
	local originalTextStroke: { [Instance]: number } = {}
	local originalOutlineThickness: { [UIStroke]: number } = {}
	local function updateLabelOutline(label: TextLabel | TextButton)
		local original = originalTextStroke[label]
		if original == nil then
			original = label.TextStrokeTransparency
			originalTextStroke[label] = original
		end
		label.TextStrokeTransparency = if compactText then math.max(original, 0.45) else original
		for _, child in label:GetChildren() do
			if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
				local thickness = originalOutlineThickness[child]
				if thickness == nil then
					thickness = child.Thickness
					originalOutlineThickness[child] = thickness
				end
				child.Thickness = if compactText then thickness * 0.65 else thickness
			end
		end
	end
	local function updateAllOutlines()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		compactText = math.min(viewport.X, viewport.Y) < 600
		background.Size = UDim2.fromScale(if compactText then 0.94 else 0.88, if compactText then 0.74 else 0.8)
		aspectRatio.AspectRatio = if compactText then 0.93 else 0.86
		decorationsPanel.Size = UDim2.fromScale(if compactText then 0.60 else 0.48, 0.63)
		decorationsAspect.AspectRatio = if compactText then 0.88 else 1
		for _, descendant in background:GetDescendants() do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				updateLabelOutline(descendant)
			end
		end
	end
	background.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			updateLabelOutline(descendant)
		elseif descendant:IsA("UIStroke") then
			local parent = descendant.Parent
			if parent and (parent:IsA("TextLabel") or parent:IsA("TextButton")) then
				updateLabelOutline(parent)
			end
		end
	end)
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAllOutlines) else nil
		updateAllOutlines()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	gui.Destroying:Connect(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)
	watchCamera()

	return gui
end

return TankPopupRoot
