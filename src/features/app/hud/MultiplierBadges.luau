local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)
local UpgradeConfig = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeConfig)

local CASH_ICON = "rbxthumb://type=Asset&id=15040641396&w=420&h=420"
local LUCK_ICON = "rbxthumb://type=Asset&id=17009565443&w=420&h=420"

local function formatMultiplier(value: number): string
	if value ~= value or value == math.huge or value == -math.huge then
		value = 1
	end

	local rounded = math.floor(math.max(1, value) * 100 + 0.5) / 100
	local formatted = string.format("%.2f", rounded):gsub("0+$", ""):gsub("%.$", "")
	return `{formatted}x`
end

local function MultiplierBadge(props: {
	Image: string,
	Value: number,
})
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(48, 48),
	}, {
		Icon = React.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Image = props.Image,
			Position = UDim2.fromOffset(2, 1),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(36, 34),
			ZIndex = 10,
		}),
		Value = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.fromOffset(44, 20),
			Text = formatMultiplier(props.Value),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 11,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 3,
			}),
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 18,
				MinTextSize = 10,
			}),
		}),
	})
end

local function MultiplierBadges()
	local luckLevel, setLuckLevel = React.useState(PlayerData.slimeLuckLevel())
	local cashLevel, setCashLevel = React.useState(PlayerData.cashMultiplierLevel())
	local rebirths, setRebirths = React.useState(PlayerData.rebirths())

	React.useEffect(function()
		local luckConnection = PlayerData.slimeLuckLevel.Changed(setLuckLevel)
		local cashConnection = PlayerData.cashMultiplierLevel.Changed(setCashLevel)
		local rebirthConnection = PlayerData.rebirths.Changed(setRebirths)

		return function()
			luckConnection()
			cashConnection()
			rebirthConnection()
		end
	end, {})

	local rebirthMultiplier = RebirthConfig.getRewardMultiplier(rebirths)
	local luckMultiplier = UpgradeConfig.getLuckMultiplier(luckLevel) * rebirthMultiplier
	local cashMultiplier = UpgradeConfig.getCashMultiplier(cashLevel) * rebirthMultiplier

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 24, 1, -80),
		Size = UDim2.fromOffset(98, 48),
		ZIndex = 10,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Luck = React.createElement(MultiplierBadge, {
			Image = LUCK_ICON,
			Value = luckMultiplier,
		}),
		Cash = React.createElement(MultiplierBadge, {
			Image = CASH_ICON,
			Value = cashMultiplier,
		}),
	})
end

return MultiplierBadges
