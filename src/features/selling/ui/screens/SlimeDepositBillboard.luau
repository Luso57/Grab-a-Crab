local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)

local e = React.createElement
local DOUBLE_SLIME_DEPOSIT_ATTRIBUTE = "HasDoubleSlimeDeposit"

type EntryProps = {
	adornee: Attachment,
	plotModel: Model,
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 65, 65)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 166, 54)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 240, 64)),
	ColorSequenceKeypoint.new(0.51, Color3.fromRGB(69, 255, 103)),
	ColorSequenceKeypoint.new(0.68, Color3.fromRGB(57, 216, 255)),
	ColorSequenceKeypoint.new(0.84, Color3.fromRGB(111, 93, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 74, 227)),
})

local function outlinedText(props: { [string]: any }, maxTextSize: number, children: { [string]: any }?)
	local textChildren = children or {}
	textChildren.Stroke = e("UIStroke", {
		Color = Color3.new(0, 0, 0),
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = 3,
	})
	textChildren.TextSizeConstraint = e("UITextSizeConstraint", {
		MaxTextSize = maxTextSize,
		MinTextSize = 1,
	})
	return e("TextLabel", props, textChildren)
end

local function DepositEntry(props: EntryProps)
	local hasDoubleSlime, setHasDoubleSlime = React.useState(
		props.plotModel:GetAttribute(DOUBLE_SLIME_DEPOSIT_ATTRIBUTE) == true
	)

	React.useEffect(function()
		local function refresh()
			setHasDoubleSlime(props.plotModel:GetAttribute(DOUBLE_SLIME_DEPOSIT_ATTRIBUTE) == true)
		end
		local connection = props.plotModel:GetAttributeChangedSignal(DOUBLE_SLIME_DEPOSIT_ATTRIBUTE):Connect(refresh)
		refresh()
		return function()
			connection:Disconnect()
		end
	end, { props.plotModel })

	return e("BillboardGui", {
		Adornee = props.adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 100,
		Size = UDim2.fromScale(6, 2.4),
		StudsOffsetWorldSpace = Vector3.new(0, 0.4, 0),
	}, {
		OwnershipBadge = if hasDoubleSlime
			then outlinedText({
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0.08, 0.02),
				Size = UDim2.fromScale(0.84, 0.31),
				Text = "[x2 Slime]",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 1,
			}, 28, {
				Rainbow = e("UIGradient", { Color = RAINBOW }),
			})
			else nil,
		Label = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0.33),
			Size = UDim2.fromScale(1, 0.67),
			Text = "Deposit Slime",
			TextColor3 = Color3.fromRGB(65, 255, 55),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 36),
	})
end

local function SlimeDepositBillboard()
	local deposits = ReactCharm.useAtom(SellingSlice.state.deposits)
	local billboards = {}

	for entryId, entry in deposits do
		billboards[entryId] = e(DepositEntry, {
			adornee = entry.adornee,
			plotModel = entry.plotModel,
		})
	end

	return e(React.Fragment, nil, billboards)
end

return SlimeDepositBillboard
