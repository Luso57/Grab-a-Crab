local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local PlotLevelConfig = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelConfig)
local PlotLevelSlice = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelSlice)

local e = React.createElement

local function outlinedText(props: { [string]: any }, thickness: number)
	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = thickness,
		}),
	})
end

local function PlotLevelSign(props: {
	board: BasePart,
	currentLevel: number,
	canPurchase: boolean,
	onPurchase: (() -> ())?,
	currency: number,
})
	local currentLevel = PlotLevelConfig.getLevel(props.currentLevel)
	local isMaxLevel = currentLevel >= PlotLevelConfig.MaxLevel
	local nextLevel = math.min(currentLevel + 1, PlotLevelConfig.MaxLevel)
	local nextCost = PlotLevelConfig.getCost(nextLevel) or 0
	local canAfford = props.canPurchase and not isMaxLevel and props.currency >= nextCost
	local titleText = if isMaxLevel then "MAX LEVEL" else `LEVEL {nextLevel}`
	local priceText = if isMaxLevel then "MAX" else CompactNumber.format(nextCost, 1)

	return e("SurfaceGui", {
		Active = true,
		Adornee = props.board,
		AlwaysOnTop = false,
		CanvasSize = Vector2.new(600, 530),
		Face = Enum.NormalId.Back,
		LightInfluence = 0,
	}, {
		Title = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.06, 0.055),
			Size = UDim2.fromScale(0.88, 0.34),
			Text = titleText,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 7),
		ButtonShadow = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(25, 67, 24),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.12, 0.535),
			Size = UDim2.fromScale(0.76, 0.34),
			ZIndex = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.08, 0) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(63, 38, 18),
				Thickness = 9,
			}),
		}),
		PricePanel = e("TextButton", {
			Active = canAfford,
			AutoButtonColor = canAfford,
			BackgroundColor3 = if canAfford
				then Color3.fromRGB(67, 214, 42)
				else Color3.fromRGB(47, 130, 38),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.12, 0.505),
			Size = UDim2.fromScale(0.76, 0.34),
			Text = "",
			ZIndex = 2,
			[React.Event.Activated] = if canAfford then props.onPurchase else nil,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.08, 0) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(20, 75, 22),
				Thickness = 7,
			}),
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(128, 255, 62)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(58, 205, 39)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 126, 29)),
				}),
				Rotation = 90,
			}),
			Price = outlinedText({
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0.04, 0.06),
				Size = UDim2.fromScale(0.92, 0.88),
				Text = priceText,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 1,
				ZIndex = 3,
			}, 7),
		}),
	})
end

local function PlotLevelRoot()
	local signs = ReactCharm.useAtom(PlotLevelSlice.state.signs)
	local currency, setCurrency = React.useState(PlayerData.currency())

	React.useEffect(function()
		return PlayerData.currency.Changed(function(value: number)
			setCurrency(value)
		end)
	end, {})

	local elements = {}
	for entryId, entry in signs do
		elements[entryId] = e(PlotLevelSign, {
			board = entry.board,
			currentLevel = entry.currentLevel,
			canPurchase = entry.canPurchase,
			onPurchase = entry.onPurchase,
			currency = currency,
		})
	end
	return e(React.Fragment, nil, elements)
end

return PlotLevelRoot
