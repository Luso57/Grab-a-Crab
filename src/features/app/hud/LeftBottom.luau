local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client

local function LeftBottom()
	local currency, setCurrency = React.useState(PlayerData.currency())

	React.useEffect(function()
		return PlayerData.currency.Changed(function(amount: number)
			setCurrency(amount)
		end)
	end, {})

	return React.createElement("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(560, 54),
		Text = CompactNumber.format(currency, 1),
		TextColor3 = Color3.fromRGB(65, 255, 55),
		TextScaled = true,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = 4,
		}),
		TextSizeConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = 42,
			MinTextSize = 18,
		}),
	})
end

return LeftBottom
