local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client

local SUFFIXES = {
	{ threshold = 1e12, suffix = "T" },
	{ threshold = 1e9, suffix = "B" },
	{ threshold = 1e6, suffix = "M" },
	{ threshold = 1e3, suffix = "K" },
}

local function formatAmount(amount: number): string
	for _, entry in SUFFIXES do
		if math.abs(amount) >= entry.threshold then
			local formatted = string.format("%.1f", amount / entry.threshold)
			formatted = string.gsub(formatted, "%.0$", "")

			return `{formatted}{entry.suffix}`
		end
	end

	return tostring(math.floor(amount))
end

local function BottomBar()
	local slimeCurrency, setSlimeCurrency = React.useState(PlayerData.slimeCurrency())

	React.useEffect(function()
		return PlayerData.slimeCurrency.Changed(function(amount: number)
			setSlimeCurrency(amount)
		end)
	end, {})

	return React.createElement("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Image = "rbxthumb://type=Asset&id=137154481767301&w=420&h=420",
		Position = UDim2.new(0.5, 0, 1, -5),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(100, 0, 100, 0),
	}, {
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = Vector2.new(770, 165),
			MinSize = Vector2.new(275, 50),
		}),
		Title = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.32),
			Size = UDim2.fromScale(0.34, 0.3),
			Text = "Slime",
			TextColor3 = Color3.new(0, 0, 0),
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 2,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 40,
				MinTextSize = 12,
			}),
		}),
		Amount = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, .6),
			Size = UDim2.fromScale(0.42, 0.32),
			Text = formatAmount(slimeCurrency),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 2,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 3,
			}),
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 36,
				MinTextSize = 12,
			}),
		}),
	})
end

return BottomBar
