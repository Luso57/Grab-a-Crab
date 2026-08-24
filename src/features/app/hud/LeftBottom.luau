local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client

local function LeftBottom()
	local currency, setCurrency = React.useState(PlayerData.currency())
	local isPhone = useIsPhoneViewport()

	React.useEffect(function()
		return PlayerData.currency.Changed(function(amount: number)
			setCurrency(amount)
		end)
	end, {})

	return React.createElement("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Position = UDim2.new(0, if isPhone then 8 else 24, 1, if isPhone then -4 else -24),
		Size = UDim2.fromOffset(if isPhone then 448 else 560, if isPhone then 43 else 54),
		Text = "$" .. CompactNumber.format(currency, 1),
		TextColor3 = Color3.fromRGB(65, 255, 55),
		TextScaled = true,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = if isPhone then 3 else 4,
		}),
		TextSizeConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = if isPhone then 34 else 42,
			MinTextSize = if isPhone then 14 else 18,
		}),
	})
end

return LeftBottom
