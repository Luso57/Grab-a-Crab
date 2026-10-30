--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabSizeIndex = require(ReplicatedStorage.Source.Features.Index.Modules.CrabSizeIndex)
local IndexMilestones = require(ReplicatedStorage.Source.Features.Index.Modules.IndexMilestones)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)

local create = Vide.create
local source = Vide.source
local image = function(id: number): string
	return "rbxassetid://" .. id
end

export type Props = {
	isOpen: () -> boolean,
	discovered: () -> { [string]: boolean },
	discoveredBySize: () -> { [string]: boolean },
	claimed: () -> { [string]: boolean },
	onClaim: (string, number) -> (),
	onClose: () -> (),
}

local function label(name: string, value: any, position: UDim2, size: UDim2, maxSize: number, color: any?): TextLabel
	local text = create "TextLabel" {
		Name = name,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Text = value,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 5,
	} :: TextLabel
	create "UITextSizeConstraint" { MaxTextSize = maxSize }.Parent = text
	return text
end

local function IndexRoot(props: Props): Instance
	local ids = Crabs.getOrderedIds()
	local selectedId = source(ids[1])
	local selectedSize = source("Base")
	local visible = source(false)
	local function isKnown(crabId: string, sizeName: string): boolean
		return IndexMilestones.isKnown(crabId, sizeName, props.discovered(), props.discoveredBySize())
	end
	local function selectFirstKnown(sizeName: string)
		for _, crabId in ids do
			if isKnown(crabId, sizeName) then
				selectedId(crabId)
				return
			end
		end
		selectedId(ids[1])
	end
	local discoveredCount = Vide.derive(function()
		return IndexMilestones.countDiscovered(selectedSize(), props.discovered(), props.discoveredBySize())
	end)
	local nextTarget = Vide.derive(function()
		return IndexMilestones.nextUnclaimed(selectedSize(), props.claimed())
	end)
	local stageTarget = Vide.derive(function()
		return nextTarget() or #ids
	end)
	local stageStart = Vide.derive(function()
		local target = nextTarget()
		return if target == 15 then 5 elseif target == 29 or target == nil then 15 else 0
	end)
	local canClaim = Vide.derive(function()
		local target = nextTarget()
		return target ~= nil and discoveredCount() >= target
	end)
	local isSelectedKnown = Vide.derive(function()
		return isKnown(selectedId(), selectedSize())
	end)
	local selectedDefinition = Vide.derive(function()
		return Crabs.get(selectedId())
	end)

	local screen = create "ScreenGui" {
		Name = "IndexMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = visible,
	} :: ScreenGui
	local closeSound = create "Sound" { SoundId = "rbxassetid://132948338000932", Volume = 1 }
	closeSound.Parent = screen

	local panel = create "ImageLabel" {
		Name = "IndexPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromOffset(850, 458),
		BackgroundTransparency = 1,
		Image = image(assets.IndexBackground),
		ImageColor3 = Color3.fromRGB(165, 105, 48),
		ScaleType = Enum.ScaleType.Stretch,
	} :: ImageLabel
	panel.Parent = screen

	local sizeTabs = create "Frame" {
		Name = "SizeTabs",
		BackgroundTransparency = 1,
		ZIndex = 6,
	} :: Frame
	local tabLayout = create "UIListLayout" {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}
	tabLayout.Parent = sizeTabs
	local basicCrab = Crabs.get("BasicCrab")
	for order, tabName in CrabSizeIndex.names do
		local zoom = 0.88 + (order - 1) * 0.25
		local tab = create "ImageButton" {
			Name = tabName .. "Tab",
			LayoutOrder = order,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = true,
			Selectable = true,
			Image = image(assets.IndexMiniCard),
			ScaleType = Enum.ScaleType.Stretch,
			ClipsDescendants = true,
			ZIndex = 6,
			Activated = function()
				selectedSize(tabName)
				selectFirstKnown(tabName)
				closeSound.TimePosition = 0
				closeSound:Play()
			end,
		} :: ImageButton
		create "UICorner" { CornerRadius = UDim.new(0, 6) }.Parent = tab
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if selectedSize() == tabName then Color3.new(1, 1, 1) else Color3.fromRGB(22, 13, 4)
			end,
			Thickness = 3,
		}.Parent = tab
		create "ImageLabel" {
			Name = "CrabImage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(zoom, zoom),
			BackgroundTransparency = 1,
			Image = if basicCrab then image(basicCrab.imageId) else "",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 7,
		}.Parent = tab
		local tabLabel = create "TextLabel" {
			Name = "TabLabel",
			Position = UDim2.fromScale(0.03, 0.73),
			Size = UDim2.fromScale(0.94, 0.25),
			BackgroundTransparency = 1,
			Text = tabName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			Font = Enum.Font.BuilderSansExtraBold,
			ZIndex = 8,
		} :: TextLabel
		create "UITextSizeConstraint" { MaxTextSize = 16 }.Parent = tabLabel
		tabLabel.Parent = tab
		tab.Parent = sizeTabs
	end
	sizeTabs.Parent = panel

	local sign = create "ImageLabel" {
		Name = "IndexSign",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.14, 0.015),
		Size = UDim2.fromScale(0.32, 0.17),
		BackgroundTransparency = 1,
		Image = image(assets.TopBarCard),
		ImageColor3 = Color3.fromRGB(255, 176, 72),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	} :: ImageLabel
	local title = label("Title", "INDEX", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.90, 0.76), 52)
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}.Parent = title
	title.Parent = sign
	sign.Parent = panel

	local close = create "ImageButton" {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromScale(0.075, 0.14),
		BackgroundTransparency = 1,
		Image = image(assets.ExitButton),
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = false,
		ZIndex = 8,
		Activated = function()
			props.onClose()
		end,
	} :: ImageButton
	close.Parent = panel

	local gridBackground = create "ImageLabel" {
		Name = "CrabCollection",
		Position = UDim2.fromScale(0.03, 0.12),
		Size = UDim2.fromScale(0.61, 0.725),
		BackgroundColor3 = Color3.fromRGB(245, 180, 62),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Image = "",
		ZIndex = 2,
	} :: ImageLabel
	create "UICorner" { CornerRadius = UDim.new(0, 6) }.Parent = gridBackground
	create "UIStroke" { Color = Color3.fromRGB(38, 20, 0), Thickness = 3 }.Parent = gridBackground
	gridBackground.Parent = panel

	local list = create "ScrollingFrame" {
		Name = "CrabList",
		Position = UDim2.fromScale(0.035, 0.04),
		Size = UDim2.fromScale(0.93, 0.92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(96, 52, 13),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
	} :: ScrollingFrame
	local grid = create "UIGridLayout" {
		CellPadding = UDim2.fromOffset(6, 6),
		CellSize = UDim2.fromOffset(74, 76),
		SortOrder = Enum.SortOrder.LayoutOrder,
	} :: UIGridLayout
	grid.Parent = list
	list.Parent = gridBackground

	for order, crabId in ids do
		local definition = Crabs.get(crabId)
		if not definition then
			continue
		end
		local card = create "ImageButton" {
			Name = crabId,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Image = image(assets.IndexMiniCard),
			ScaleType = Enum.ScaleType.Stretch,
			AutoButtonColor = false,
			ZIndex = 4,
			Activated = function()
				selectedId(crabId)
				closeSound.TimePosition = 0
				closeSound:Play()
			end,
		} :: ImageButton
		local selection = create "Frame" {
			Name = "SelectionBorder",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
			Visible = function()
				return selectedId() == crabId
			end,
			ZIndex = 7,
		} :: Frame
		create "UICorner" { CornerRadius = UDim.new(0, 5) }.Parent = selection
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 4,
		}.Parent = selection
		selection.Parent = card
		create "ImageLabel" {
			Name = "CrabImage",
			Position = UDim2.fromScale(-0.19, 0.17),
			Size = UDim2.fromScale(1.38, 1.00),
			BackgroundTransparency = 1,
			Image = image(definition.imageId),
			ImageColor3 = function()
				return if isKnown(crabId, selectedSize()) then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			end,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
		}.Parent = card
		label("CardName", function()
			return if isKnown(crabId, selectedSize()) then definition.name else "???"
		end, UDim2.fromScale(0.03, 0.015), UDim2.fromScale(0.94, 0.29), 20).Parent = card
		card.Parent = list
	end

	local showcase = create "ImageLabel" {
		Name = "Showcase",
		Position = UDim2.fromScale(0.655, 0.11),
		Size = UDim2.fromScale(0.325, 0.50),
		BackgroundTransparency = 1,
		Image = image(assets.IndexShowcaseCard),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	} :: ImageLabel
	create "ImageLabel" {
		Name = "SelectedCrab",
		Position = UDim2.fromScale(-0.35, 0.12),
		Size = UDim2.fromScale(1.70, 0.70),
		BackgroundTransparency = 1,
		Image = function()
			local definition = selectedDefinition()
			return if definition then image(definition.imageId) else ""
		end,
		ImageColor3 = function()
			return if isSelectedKnown() then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		end,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}.Parent = showcase
	label("CrabName", function()
		local definition = selectedDefinition()
		return if isSelectedKnown() and definition then definition.name else "????"
	end, UDim2.fromScale(0.06, 0.005), UDim2.fromScale(0.88, 0.23), 42).Parent = showcase
	label("Rarity", function()
		local definition = selectedDefinition()
		return if definition then definition.rarity else ""
	end, UDim2.fromScale(0.04, 0.62), UDim2.fromScale(0.92, 0.12), 27, function()
		local definition = selectedDefinition()
		return if definition then Rarities.getColor(definition.rarity) else Color3.new(1, 1, 1)
	end).Parent = showcase
	label("IncomeHeading", "BASE INCOME", UDim2.fromScale(0.05, 0.75), UDim2.fromScale(0.90, 0.11), 24).Parent = showcase
	label("Income", function()
		local definition = selectedDefinition()
		return if isSelectedKnown() and definition then CompactNumber.formatIncomeRate(definition.incomePerSecond) .. "/s" else "????"
	end, UDim2.fromScale(0.05, 0.86), UDim2.fromScale(0.90, 0.12), 27).Parent = showcase
	showcase.Parent = panel
	local sizeRange = label("SizeRange", function()
		local sizeName = selectedSize()
		return string.upper(sizeName) .. " (" .. CrabSizeIndex.rangeText[sizeName] .. ")"
	end, UDim2.fromScale(0.655, 0.035), UDim2.fromScale(0.325, 0.065), 22)
	sizeRange.Parent = panel

	local rewards = create "ImageLabel" {
		Name = "Rewards",
		Position = UDim2.fromScale(0.655, 0.62),
		Size = UDim2.fromScale(0.325, 0.33),
		BackgroundTransparency = 1,
		Image = image(assets.IndexRewardCard),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	} :: ImageLabel
	local rewardsHeading = label("RewardsHeading", function()
		local target = nextTarget()
		return if target then "REWARDS: " .. tostring(target) else "ALL REWARDS CLAIMED"
	end, UDim2.fromScale(0.12, 0.035), UDim2.fromScale(0.76, 0.13), 18)
	rewardsHeading.TextXAlignment = Enum.TextXAlignment.Left
	rewardsHeading.Parent = rewards
	for index, iconId in { assets.IndexClover, assets.SandDollar } do
		local rewardSlot = create "ImageLabel" {
			Name = if index == 1 then "CloverReward" else "CoinReward",
			Position = UDim2.fromScale(if index == 1 then 0.13 else 0.56, 0.19),
			Size = UDim2.fromScale(0.32, 0.34),
			BackgroundTransparency = 1,
			Image = image(assets.IndexMiniCard),
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 4,
		} :: ImageLabel
		create "ImageLabel" {
			Name = "RewardIcon",
			Position = UDim2.fromScale(0.15, 0.12),
			Size = UDim2.fromScale(0.70, 0.76),
			BackgroundTransparency = 1,
			Image = image(iconId),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
		}.Parent = rewardSlot
		label("RewardAmount", function()
			if index == 1 then
				return if nextTarget() then "+1x" else "DONE"
			end
			local target = nextTarget()
			local coins = if target then IndexMilestones.getCoins(selectedSize(), target) else nil
			return if coins then "$" .. CompactNumber.format(coins) else "DONE"
		end, UDim2.fromScale(if index == 1 then 0.10 else 0.53, 0.52), UDim2.fromScale(0.38, 0.14), 17).Parent = rewards
		rewardSlot.Parent = rewards
	end
	local claim = create "ImageButton" {
		Name = "ClaimButton",
		Position = UDim2.fromScale(0.19, 0.65),
		Size = UDim2.fromScale(0.62, 0.26),
		BackgroundColor3 = function()
			return if canClaim() then Color3.fromRGB(44, 186, 67) else Color3.fromRGB(103, 105, 107)
		end,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		ZIndex = 4,
		Activated = function()
			local target = nextTarget()
			if target and canClaim() then
				props.onClaim(selectedSize(), target)
			end
		end,
	} :: ImageButton
	create "UICorner" { CornerRadius = UDim.new(0, 4) }.Parent = claim
	create "UIStroke" { Color = Color3.fromRGB(35, 35, 35), Thickness = 2 }.Parent = claim
	label("ClaimText", function()
		return if nextTarget() == nil then "DONE" elseif canClaim() then "CLAIM" else "LOCKED"
	end, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.90, 0.87), 17, function()
		return if canClaim() then Color3.new(1, 1, 1) else Color3.fromRGB(210, 210, 210)
	end).Parent = claim
	claim.Parent = rewards
	rewards.Parent = panel

	local progress = create "ImageLabel" {
		Name = "IndexProgress",
		Position = UDim2.fromScale(0.045, 0.87),
		Size = UDim2.fromScale(0.595, 0.11),
		BackgroundTransparency = 1,
		Image = image(assets.IndexProgressPill),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	} :: ImageLabel
	local track = create "Frame" {
		Name = "ProgressTrack",
		Position = UDim2.fromScale(0.04, 0.06),
		Size = UDim2.fromScale(0.93, 0.88),
		BackgroundColor3 = Color3.fromRGB(24, 30, 37),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	} :: Frame
	create "UICorner" { CornerRadius = UDim.new(1, 0) }.Parent = track
	local fill = create "Frame" {
		Name = "ProgressFill",
		Size = function()
			local start = stageStart()
			return UDim2.fromScale(math.clamp((discoveredCount() - start) / (stageTarget() - start), 0, 1), 1)
		end,
		BackgroundColor3 = Color3.fromRGB(0, 200, 255),
		BorderSizePixel = 0,
		ZIndex = 5,
	} :: Frame
	create "UICorner" { CornerRadius = UDim.new(1, 0) }.Parent = fill
	create "UIGradient" {
		Color = ColorSequence.new(Color3.fromRGB(0, 84, 235), Color3.fromRGB(0, 220, 255)),
		Rotation = 0,
	}.Parent = fill
	fill.Parent = track
	track.Parent = progress
	create "ImageLabel" {
		Name = "BookIcon",
		Position = UDim2.fromScale(-0.03, -0.12),
		Size = UDim2.fromScale(0.15, 1.24),
		BackgroundTransparency = 1,
		Image = image(assets.IndexButtonIcon),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 6,
	}.Parent = progress
	label("ProgressText", function()
		return string.format("%d/%d", math.min(discoveredCount(), stageTarget()), stageTarget())
	end, UDim2.fromScale(0.30, 0.08), UDim2.fromScale(0.40, 0.84), 23).Parent = progress
	progress.Parent = panel

	local function resize()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local portrait = viewport.Y > viewport.X
		local height = math.min(458, viewport.Y * (if portrait then 0.72 else 0.74))
		local tabSize = if portrait then math.floor((height * 0.45 - 16) / 5) else math.clamp(math.floor(height * 0.135), 42, 62)
		local width = math.min(850, viewport.X * (if portrait then 0.94 else 0.86), if portrait then math.huge else viewport.X - 2 * (tabSize + 16))
		panel.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
		local tabGap = if portrait then 4 else math.max(4, math.floor(tabSize * 0.10))
		tabLayout.Padding = UDim.new(0, tabGap)
		sizeTabs.Size = UDim2.fromOffset(tabSize, 5 * tabSize + 4 * tabGap)
		for _, child in sizeTabs:GetChildren() do
			if child:IsA("ImageButton") then
				child.Size = UDim2.fromOffset(tabSize, tabSize)
			end
		end
		if portrait then
			sizeTabs.Position = UDim2.new(0, 6, 0.13, 0)
			gridBackground.Position = UDim2.fromScale(0.15, 0.13)
			gridBackground.Size = UDim2.fromScale(0.79, 0.45)
			sizeRange.Position = UDim2.fromScale(0.04, 0.59)
			sizeRange.Size = UDim2.fromScale(0.45, 0.035)
			showcase.Position = UDim2.fromScale(0.04, 0.63)
			showcase.Size = UDim2.fromScale(0.45, 0.22)
			rewards.Position = UDim2.fromScale(0.51, 0.615)
			rewards.Size = UDim2.fromScale(0.45, 0.235)
			progress.Position = UDim2.fromScale(0.08, 0.87)
			progress.Size = UDim2.fromScale(0.84, 0.10)
		else
			sizeTabs.Position = UDim2.new(0, -tabSize - 12, 0.5, -math.floor(sizeTabs.Size.Y.Offset / 2) + 12)
			gridBackground.Position = UDim2.fromScale(0.03, 0.12)
			gridBackground.Size = UDim2.fromScale(0.61, 0.725)
			sizeRange.Position = UDim2.fromScale(0.655, 0.035)
			sizeRange.Size = UDim2.fromScale(0.325, 0.065)
			showcase.Position = UDim2.fromScale(0.655, 0.11)
			showcase.Size = UDim2.fromScale(0.325, 0.50)
			rewards.Position = UDim2.fromScale(0.655, 0.62)
			rewards.Size = UDim2.fromScale(0.325, 0.33)
			progress.Position = UDim2.fromScale(0.045, 0.87)
			progress.Size = UDim2.fromScale(0.595, 0.11)
		end
		local columns = if portrait then 4 else 5
		local cellWidth = math.floor((width * gridBackground.Size.X.Scale * 0.93 - (columns - 1) * 6 - 6) / columns)
		grid.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth * 1.03))
	end
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) else nil
		resize()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	screen.Destroying:Connect(function()
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
			selectFirstKnown(selectedSize())
			visible(true)
			panelTween = TweenService:Create(panel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = shownPosition })
			panelTween:Play()
		else
			closeSound:Play()
			panelTween = TweenService:Create(panel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = hiddenPosition })
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

return IndexRoot
