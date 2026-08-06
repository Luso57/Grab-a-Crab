local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local SellingConfig = require(ReplicatedStorage.Source.Features.Selling.SellingConfig)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)

local e = React.createElement
local COST_ATTRIBUTE = "UpgradePerSecondCost"
local GAIN_ATTRIBUTE = "UpgradePerSecondGain"

type EntryProps = {
	adornee: Attachment,
	plotModel: Model,
}

local function getNumberAttribute(instance: Instance, attributeName: string, defaultValue: number): number
	local value = instance:GetAttribute(attributeName)
	return if type(value) == "number" then math.floor(math.max(0, value)) else defaultValue
end

local function createOutlinedLabel(props: { [string]: any }, maxTextSize: number)
	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = 3,
		}),
		TextSizeConstraint = e("UITextSizeConstraint", {
			MaxTextSize = maxTextSize,
			MinTextSize = 1,
		}),
	})
end

local function UpgradePerSecondEntry(props: EntryProps)
	local cost, setCost = React.useState(
		getNumberAttribute(props.plotModel, COST_ATTRIBUTE, SellingConfig.UpgradePerSecondBaseCost)
	)
	local gain, setGain = React.useState(
		getNumberAttribute(props.plotModel, GAIN_ATTRIBUTE, SellingConfig.UpgradePerSecondBaseGain)
	)

	React.useEffect(function()
		local costConnection = props.plotModel:GetAttributeChangedSignal(COST_ATTRIBUTE):Connect(function()
			setCost(getNumberAttribute(props.plotModel, COST_ATTRIBUTE, SellingConfig.UpgradePerSecondBaseCost))
		end)
		local gainConnection = props.plotModel:GetAttributeChangedSignal(GAIN_ATTRIBUTE):Connect(function()
			setGain(getNumberAttribute(props.plotModel, GAIN_ATTRIBUTE, SellingConfig.UpgradePerSecondBaseGain))
		end)

		setCost(getNumberAttribute(props.plotModel, COST_ATTRIBUTE, SellingConfig.UpgradePerSecondBaseCost))
		setGain(getNumberAttribute(props.plotModel, GAIN_ATTRIBUTE, SellingConfig.UpgradePerSecondBaseGain))

		return function()
			costConnection:Disconnect()
			gainConnection:Disconnect()
		end
	end, { props.plotModel })

	return e("BillboardGui", {
		Adornee = props.adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 100,
		Size = UDim2.fromScale(6, 2.4),
	}, {
		Gain = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.05),
			Size = UDim2.fromScale(1, 0.4),
			Text = `+{CompactNumber.format(gain, 2)} per second`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 36),
		Cost = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.43),
			Size = UDim2.fromScale(1, 0.48),
			Text = CompactNumber.format(cost, 2),
			TextColor3 = Color3.fromRGB(65, 255, 55),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 42),
	})
end

local function UpgradePerSecondBillboard()
	local upgradePads = ReactCharm.useAtom(SellingSlice.state.upgradePads)
	local billboards = {}

	for entryId, entry in upgradePads do
		billboards[entryId] = e(UpgradePerSecondEntry, {
			adornee = entry.adornee,
			plotModel = entry.plotModel,
		})
	end

	return e(React.Fragment, nil, billboards)
end

return UpgradePerSecondBillboard
