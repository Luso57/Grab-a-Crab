local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local UpgradeConfig = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeConfig)
local UpgradeSlice = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeSlice)

local e = React.createElement
local SLIME_LUCK_ICON = "rbxthumb://type=Asset&id=129360611840213&w=420&h=420"
local CASH_MULTIPLIER_ICON = "rbxthumb://type=Asset&id=18209585851&w=420&h=420"
local PURCHASE_SOUND_ID = "rbxassetid://112283037672337"
local LUCK_MULTIPLIER_ATTRIBUTE = "SlimeLuckMultiplier"
local LUCK_LEVEL_ATTRIBUTE = "SlimeLuckLevel"
local LUCK_NEXT_MULTIPLIER_ATTRIBUTE = "SlimeLuckNextMultiplier"
local LUCK_COST_ATTRIBUTE = "SlimeLuckCost"
local LUCK_MAX_QUANTITY_ATTRIBUTE = "SlimeLuckMaxQuantity"
local LUCK_MAX_COST_ATTRIBUTE = "SlimeLuckMaxCost"
local CASH_MULTIPLIER_ATTRIBUTE = "CashMultiplier"
local CASH_LEVEL_ATTRIBUTE = "CashMultiplierLevel"
local CASH_NEXT_MULTIPLIER_ATTRIBUTE = "CashMultiplierNextMultiplier"
local CASH_COST_ATTRIBUTE = "CashMultiplierCost"
local CASH_MAX_QUANTITY_ATTRIBUTE = "CashMultiplierMaxQuantity"
local CASH_MAX_COST_ATTRIBUTE = "CashMultiplierMaxCost"

type EntryProps = {
	title: BasePart,
	board: BasePart,
	plotModel: Model,
	canPurchase: boolean,
	onBuyLuckOne: (() -> ())?,
	onBuyLuckMax: (() -> ())?,
	onBuyCashOne: (() -> ())?,
	onBuyCashMax: (() -> ())?,
}

local function getNumberAttribute(instance: Instance, attributeName: string, fallback: number): number
	local value = instance:GetAttribute(attributeName)
	return if type(value) == "number" then value else fallback
end

local function useNumberAttribute(instance: Instance, attributeName: string, fallback: number): number
	local value, setValue = React.useState(getNumberAttribute(instance, attributeName, fallback))

	React.useEffect(function()
		local connection = instance:GetAttributeChangedSignal(attributeName):Connect(function()
			setValue(getNumberAttribute(instance, attributeName, fallback))
		end)
		setValue(getNumberAttribute(instance, attributeName, fallback))

		return function()
			connection:Disconnect()
		end
	end, { instance, attributeName, fallback })

	return value
end

local function usePlayerCurrency(): number
	local currency, setCurrency = React.useState(PlayerData.currency())

	React.useEffect(function()
		return PlayerData.currency.Changed(function(value: number)
			setCurrency(value)
		end)
	end, {})

	return currency
end

local function formatCurrency(amount: number): string
	return "$" .. CompactNumber.format(amount, 2)
end

local function outlinedText(props: { [string]: any }, thickness: number?)
	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = thickness or 3,
		}),
	})
end

local function roundCorner(radius: UDim?)
	return e("UICorner", {
		CornerRadius = radius or UDim.new(0.15, 0),
	})
end

local function playPurchaseSound()
	local sound = Instance.new("Sound")
	sound.Name = "UpgradePurchased"
	sound.SoundId = PURCHASE_SOUND_ID
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
end

local function UpgradeIcon(props: { image: string })
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = props.image,
		Position = UDim2.fromScale(0.035, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(0.115, 0.66),
	}, {
		AspectRatio = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
end

local function PurchaseButton(props: {
	position: UDim2,
	label: string,
	cost: number,
	enabled: boolean,
	onActivated: (() -> ())?,
})
	local function onActivated()
		playPurchaseSound()
		if props.onActivated then
			props.onActivated()
		end
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = props.position,
		Size = UDim2.fromScale(0.19, 0.78),
	}, {
		BuyLabel = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 0.28),
			Text = props.label,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 2),
		Button = e("TextButton", {
			Active = props.enabled,
			AutoButtonColor = props.enabled,
			BackgroundColor3 = if props.enabled
				then Color3.fromRGB(46, 255, 63)
				else Color3.fromRGB(92, 115, 94),
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.32),
			Size = UDim2.fromScale(1, 0.6),
			Text = formatCurrency(props.cost),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			[React.Event.Activated] = if props.enabled then onActivated else nil,
		}, {
			Corner = roundCorner(),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(0, 115, 14),
				Thickness = 4,
			}),
			TextStroke = e("UIStroke", {
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 3,
			}),
		}),
	})
end

local function UpgradeRow(props: {
	name: string,
	position: UDim2,
	icon: string,
	currentMultiplier: number,
	nextMultiplier: number,
	singleCost: number,
	maxCost: number,
	singleEnabled: boolean,
	maxEnabled: boolean,
	onBuyOne: (() -> ())?,
	onBuyMax: (() -> ())?,
})
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(24, 20, 16),
		BackgroundTransparency = 0.16,
		Position = props.position,
		Size = UDim2.fromScale(0.94, 0.41),
	}, {
		Corner = roundCorner(UDim.new(0.04, 0)),
		Border = e("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = 4,
		}),
		Icon = e(UpgradeIcon, {
			image = if props.icon == "luck" then SLIME_LUCK_ICON else CASH_MULTIPLIER_ICON,
		}),
		Name = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.17, 0.12),
			Size = UDim2.fromScale(0.36, 0.28),
			Text = props.name,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, 2),
		Value = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.17, 0.47),
			Size = UDim2.fromScale(0.36, 0.3),
			Text = string.format("%.2fx > %.2fx", props.currentMultiplier, props.nextMultiplier),
			TextColor3 = Color3.fromRGB(59, 255, 68),
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, 2),
		BuyOne = e(PurchaseButton, {
			position = UDim2.fromScale(0.57, 0.11),
			label = "Buy 1",
			cost = props.singleCost,
			enabled = props.singleEnabled,
			onActivated = props.onBuyOne,
		}),
		BuyMax = e(PurchaseButton, {
			position = UDim2.fromScale(0.78, 0.11),
			label = "Buy Max",
			cost = props.maxCost,
			enabled = props.maxEnabled,
			onActivated = props.onBuyMax,
		}),
	})
end

local function UpgradeBoardEntry(props: EntryProps)
	local luckLevel = useNumberAttribute(props.plotModel, LUCK_LEVEL_ATTRIBUTE, 0)
	local currentLuck = useNumberAttribute(
		props.plotModel,
		LUCK_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.BaseLuckMultiplier
	)
	local nextLuck = useNumberAttribute(
		props.plotModel,
		LUCK_NEXT_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.BaseLuckMultiplier + UpgradeConfig.LuckPerLevel
	)
	local luckCost = useNumberAttribute(
		props.plotModel,
		LUCK_COST_ATTRIBUTE,
		UpgradeConfig.LuckUpgradeBaseCost
	)
	local maxLuckQuantity = useNumberAttribute(props.plotModel, LUCK_MAX_QUANTITY_ATTRIBUTE, 0)
	local maxLuckCost = useNumberAttribute(props.plotModel, LUCK_MAX_COST_ATTRIBUTE, 0)
	local playerCurrency = usePlayerCurrency()
	if props.canPurchase then
		maxLuckQuantity, maxLuckCost = UpgradeConfig.getMaxAffordableLuckUpgrades(luckLevel, playerCurrency)
	end
	local canAffordSingleLuck = props.canPurchase and playerCurrency >= luckCost
	local canAffordMaxLuck = props.canPurchase and maxLuckQuantity > 0
	local cashLevel = useNumberAttribute(props.plotModel, CASH_LEVEL_ATTRIBUTE, 0)
	local currentCash = useNumberAttribute(
		props.plotModel,
		CASH_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.BaseCashMultiplier
	)
	local nextCash = useNumberAttribute(
		props.plotModel,
		CASH_NEXT_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.BaseCashMultiplier + UpgradeConfig.CashPerLevel
	)
	local cashCost = useNumberAttribute(props.plotModel, CASH_COST_ATTRIBUTE, UpgradeConfig.CashUpgradeBaseCost)
	local maxCashQuantity = useNumberAttribute(props.plotModel, CASH_MAX_QUANTITY_ATTRIBUTE, 0)
	local maxCashCost = useNumberAttribute(props.plotModel, CASH_MAX_COST_ATTRIBUTE, 0)
	if props.canPurchase then
		maxCashQuantity, maxCashCost = UpgradeConfig.getMaxAffordableCashUpgrades(cashLevel, playerCurrency)
	end
	local canAffordSingleCash = props.canPurchase and playerCurrency >= cashCost
	local canAffordMaxCash = props.canPurchase and maxCashQuantity > 0

	return e(React.Fragment, nil, {
		Title = e("SurfaceGui", {
			Adornee = props.title,
			AlwaysOnTop = false,
			CanvasSize = Vector2.new(200, 900),
			Face = Enum.NormalId.Bottom,
			LightInfluence = 0,
		}, {
			Text = outlinedText({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = 90,
				Size = UDim2.fromOffset(810, 164),
				Text = "UPGRADES",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 1,
			}, 6),
		}),
		Board = e("SurfaceGui", {
			Active = true,
			Adornee = props.board,
			AlwaysOnTop = false,
			CanvasSize = Vector2.new(1240, 654),
			Face = Enum.NormalId.Right,
			LightInfluence = 0,
		}, {
			SlimeLuck = e(UpgradeRow, {
				name = "SLIME LUCK",
				position = UDim2.fromScale(0.03, 0.055),
				icon = "luck",
				currentMultiplier = currentLuck,
				nextMultiplier = nextLuck,
				singleCost = luckCost,
				maxCost = maxLuckCost,
				singleEnabled = canAffordSingleLuck,
				maxEnabled = canAffordMaxLuck,
				onBuyOne = props.onBuyLuckOne,
				onBuyMax = props.onBuyLuckMax,
			}),
			CashMultiplier = e(UpgradeRow, {
				name = "CASH MULTIPLIER",
				position = UDim2.fromScale(0.03, 0.535),
				icon = "cash",
				currentMultiplier = currentCash,
				nextMultiplier = nextCash,
				singleCost = cashCost,
				maxCost = maxCashCost,
				singleEnabled = canAffordSingleCash,
				maxEnabled = canAffordMaxCash,
				onBuyOne = props.onBuyCashOne,
				onBuyMax = props.onBuyCashMax,
			}),
		}),
	})
end

local function UpgradeBoard()
	local boards = ReactCharm.useAtom(UpgradeSlice.state.boards)
	local elements = {}

	for entryId, entry in boards do
		elements[entryId] = e(UpgradeBoardEntry, {
			title = entry.title,
			board = entry.board,
			plotModel = entry.plotModel,
			canPurchase = entry.canPurchase,
			onBuyLuckOne = entry.onBuyLuckOne,
			onBuyLuckMax = entry.onBuyLuckMax,
			onBuyCashOne = entry.onBuyCashOne,
			onBuyCashMax = entry.onBuyCashMax,
		})
	end

	return e(React.Fragment, nil, elements)
end

return UpgradeBoard
