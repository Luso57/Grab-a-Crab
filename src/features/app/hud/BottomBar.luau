local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client

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
			Text = CompactNumber.format(slimeCurrency, 1),
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
