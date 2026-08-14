local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)

local e = React.createElement
local CASH_ATTRIBUTE = "UncollectedCash"
local CASH_PAYOUT_MULTIPLIER_ATTRIBUTE = "CashPayoutMultiplier"
local LEGACY_CASH_MULTIPLIER_ATTRIBUTE = "CashMultiplier"

type EntryProps = {
	adornee: Attachment,
	plotModel: Model,
}

local function getCash(plotModel: Model): number
	local value = plotModel:GetAttribute(CASH_ATTRIBUTE)
	local multiplier = plotModel:GetAttribute(CASH_PAYOUT_MULTIPLIER_ATTRIBUTE)
	if type(multiplier) ~= "number" then
		multiplier = plotModel:GetAttribute(LEGACY_CASH_MULTIPLIER_ATTRIBUTE)
	end
	local baseCash = if type(value) == "number" then math.floor(math.max(0, value)) else 0
	local cashMultiplier = if type(multiplier) == "number"
		and multiplier == multiplier
		and multiplier ~= math.huge
		and multiplier ~= -math.huge
		then math.max(1, multiplier)
		else 1
	return math.floor(baseCash * cashMultiplier)
end

local function createOutlinedLabel(props: { [string]: any }, maxTextSize: number, strokeThickness: number)
	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = strokeThickness,
		}),
		TextSizeConstraint = e("UITextSizeConstraint", {
			MaxTextSize = maxTextSize,
			MinTextSize = 1,
		}),
	})
end

local function CollectCashEntry(props: EntryProps)
	local cash, setCash = React.useState(getCash(props.plotModel))

	React.useEffect(function()
		local connection = props.plotModel:GetAttributeChangedSignal(CASH_ATTRIBUTE):Connect(function()
			setCash(getCash(props.plotModel))
		end)
		local multiplierConnection = props.plotModel
			:GetAttributeChangedSignal(CASH_PAYOUT_MULTIPLIER_ATTRIBUTE)
			:Connect(function()
			setCash(getCash(props.plotModel))
		end)
		setCash(getCash(props.plotModel))

		return function()
			connection:Disconnect()
			multiplierConnection:Disconnect()
		end
	end, { props.plotModel })

	return e("BillboardGui", {
		Adornee = props.adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 100,
		Size = UDim2.fromScale(8, 3.2),
	}, {
		Title = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.05),
			Size = UDim2.fromScale(1, 0.34),
			Text = "COLLECT CASH!",
			TextColor3 = Color3.fromRGB(255, 224, 102),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 44, 4),
		Amount = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.36),
			Size = UDim2.fromScale(1, 0.58),
			Text = "$" .. CompactNumber.format(cash, 2),
			TextColor3 = if cash > 0 then Color3.fromRGB(65, 255, 55) else Color3.fromRGB(130, 165, 130),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 64, 5),
	})
end

local function CollectCashBillboard()
	local cashCollectors = ReactCharm.useAtom(SellingSlice.state.cashCollectors)
	local billboards = {}

	for entryId, entry in cashCollectors do
		billboards[entryId] = e(CollectCashEntry, {
			adornee = entry.adornee,
			plotModel = entry.plotModel,
		})
	end

	return e(React.Fragment, nil, billboards)
end

return CollectCashBillboard
