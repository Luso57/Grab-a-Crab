local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local SellingConfig = require(ReplicatedStorage.Source.Features.Selling.SellingConfig)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)

local e = React.createElement
local QUEUE_ATTRIBUTE = "SlimeQueue"
local RATE_ATTRIBUTE = "SlimesPerSecond"

type EntryProps = {
	display: BasePart,
	plotModel: Model,
}

local function getNumberAttribute(instance: Instance, attributeName: string, defaultValue: number): number
	local value = instance:GetAttribute(attributeName)
	return if type(value) == "number" then value else defaultValue
end

local function createOutlinedLabel(props: { [string]: any })
	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = 3,
		}),
	})
end

local function SlimeQueueSignEntry(props: EntryProps)
	local queue, setQueue = React.useState(getNumberAttribute(props.plotModel, QUEUE_ATTRIBUTE, 0))
	local sellRate, setSellRate = React.useState(
		getNumberAttribute(props.plotModel, RATE_ATTRIBUTE, SellingConfig.DefaultSlimesPerSecond)
	)

	React.useEffect(function()
		local queueConnection = props.plotModel:GetAttributeChangedSignal(QUEUE_ATTRIBUTE):Connect(function()
			setQueue(getNumberAttribute(props.plotModel, QUEUE_ATTRIBUTE, 0))
		end)
		local rateConnection = props.plotModel:GetAttributeChangedSignal(RATE_ATTRIBUTE):Connect(function()
			setSellRate(
				getNumberAttribute(props.plotModel, RATE_ATTRIBUTE, SellingConfig.DefaultSlimesPerSecond)
			)
		end)

		setQueue(getNumberAttribute(props.plotModel, QUEUE_ATTRIBUTE, 0))
		setSellRate(getNumberAttribute(props.plotModel, RATE_ATTRIBUTE, SellingConfig.DefaultSlimesPerSecond))

		return function()
			queueConnection:Disconnect()
			rateConnection:Disconnect()
		end
	end, { props.plotModel })

	local hasSlime = queue > 0

	return e("SurfaceGui", {
		Adornee = props.display,
		AlwaysOnTop = false,
		CanvasSize = Vector2.new(600, 335),
		Face = Enum.NormalId.Left,
		LightInfluence = 0,
	}, {
		Title = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = if hasSlime then UDim2.fromScale(0.08, 0.06) else UDim2.fromScale(0.08, 0.2),
			Size = UDim2.fromScale(0.84, 0.22),
			Text = if hasSlime then "Selling Slime" else "No Slime...",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}),
		Amount = if hasSlime
			then createOutlinedLabel({
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0.08, 0.28),
				Size = UDim2.fromScale(0.84, 0.4),
				Text = CompactNumber.format(math.max(0, queue), 1),
				TextColor3 = Color3.fromRGB(255, 242, 194),
				TextScaled = true,
				TextStrokeTransparency = 1,
			})
			else nil,
		Rate = createOutlinedLabel({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.08, 0.73),
			Size = UDim2.fromScale(0.84, 0.18),
			Text = `{CompactNumber.format(math.max(0, sellRate), 1)} per second`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}),
	})
end

local function SlimeQueueSign()
	local slimeSigns = ReactCharm.useAtom(SellingSlice.state.slimeSigns)
	local signs = {}

	for entryId, entry in slimeSigns do
		signs[entryId] = e(SlimeQueueSignEntry, {
			display = entry.display,
			plotModel = entry.plotModel,
		})
	end

	return e(React.Fragment, nil, signs)
end

return SlimeQueueSign
