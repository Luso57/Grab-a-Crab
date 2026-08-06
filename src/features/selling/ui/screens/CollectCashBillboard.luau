local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)

local e = React.createElement
local CASH_ATTRIBUTE = "UncollectedCash"
local CASH_MULTIPLIER_ATTRIBUTE = "CashMultiplier"

type EntryProps = {
	adornee: Attachment,
	plotModel: Model,
}

local function getCash(plotModel: Model): number
	local value = plotModel:GetAttribute(CASH_ATTRIBUTE)
	local multiplier = plotModel:GetAttribute(CASH_MULTIPLIER_ATTRIBUTE)
	local baseCash = if type(value) == "number" then math.floor(math.max(0, value)) else 0
	local cashMultiplier = if type(multiplier) == "number" then math.max(1, multiplier) else 1
	return math.floor(baseCash * cashMultiplier)
end

local function createOutlinedLabel(props: { [string]: any })
	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = 3,
		}),
		TextSizeConstraint = e("UITextSizeConstraint", {
			MaxTextSize = 36,
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
		local multiplierConnection = props.plotModel:GetAttributeChangedSignal(CASH_MULTIPLIER_ATTRIBUTE):Connect(function()
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
		Size = UDim2.fromScale(6, 2.4),
	}, {
		Title = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.05),
			Size = UDim2.fromScale(1, 0.38),
			Text = "Collect Cash",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}),
		Amount = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.42),
			Size = UDim2.fromScale(1, 0.5),
			Text = CompactNumber.format(cash, 2),
			TextColor3 = Color3.fromRGB(65, 255, 55),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}),
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
