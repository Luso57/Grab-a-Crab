local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local SlimeCurrencyVFX = require(ReplicatedStorage.Source.Features.App.Hud.SlimeCurrencyVFX)
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)

local DESKTOP_MAX_SIZE = Vector2.new(770, 165)
local DESKTOP_MIN_SIZE = Vector2.new(275, 50)
local PHONE_MAX_SIZE = Vector2.new(310, 70)
local PHONE_MIN_SIZE = Vector2.new(190, 44)

local function BottomBar()
	local slimeCurrency, setSlimeCurrency = React.useState(PlayerData.slimeCurrency())
	local isPhone = useIsPhoneViewport()

	React.useEffect(function()
		local previousAmount = PlayerData.slimeCurrency()
		setSlimeCurrency(previousAmount)

		return PlayerData.slimeCurrency.Changed(function(amount: number)
			local gainedAmount = amount - previousAmount
			previousAmount = amount
			setSlimeCurrency(amount)
			if gainedAmount > 0 then
				SlimeCurrencyVFX.play(gainedAmount)
			end
		end)
	end, {})

	return React.createElement("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Image = "rbxthumb://type=Asset&id=137154481767301&w=420&h=420",
		Position = UDim2.new(0.5, 0, 1, if isPhone then 7 else -5),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(100, 0, 100, 0),
	}, {
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = if isPhone then PHONE_MAX_SIZE else DESKTOP_MAX_SIZE,
			MinSize = if isPhone then PHONE_MIN_SIZE else DESKTOP_MIN_SIZE,
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
