local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)
local ProductEntitlements = require(ReplicatedStorage.Source.Features.Monetization.Modules.ProductEntitlements)
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)
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
	IsPhone: boolean,
})
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(if props.IsPhone then 40 else 48, if props.IsPhone then 40 else 48),
	}, {
		Icon = React.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Image = props.Image,
			Position = UDim2.fromOffset(2, 1),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(if props.IsPhone then 30 else 36, if props.IsPhone then 28 else 34),
			ZIndex = 10,
		}),
		Value = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.fromOffset(if props.IsPhone then 36 else 44, if props.IsPhone then 17 else 20),
			Text = formatMultiplier(props.Value),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 11,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = if props.IsPhone then 2.5 else 3,
			}),
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = if props.IsPhone then 15 else 18,
				MinTextSize = if props.IsPhone then 8 else 10,
			}),
		}),
	})
end

local function MultiplierBadges()
	local luckLevel, setLuckLevel = React.useState(PlayerData.slimeLuckLevel())
	local cashLevel, setCashLevel = React.useState(PlayerData.cashMultiplierLevel())
	local rebirths, setRebirths = React.useState(PlayerData.rebirths())
	local ownedProducts, setOwnedProducts = React.useState(PlayerData.ownedProducts())
	local ownedSlimes, setOwnedSlimes = React.useState(table.clone(PlayerData.slimes()))
	local isPhone = useIsPhoneViewport()

	React.useEffect(function()
		local luckConnection = PlayerData.slimeLuckLevel.Changed(setLuckLevel)
		local cashConnection = PlayerData.cashMultiplierLevel.Changed(setCashLevel)
		local rebirthConnection = PlayerData.rebirths.Changed(setRebirths)
		local ownedProductsConnection = PlayerData.ownedProducts.Changed(setOwnedProducts)
		local ownedSlimesConnection = PlayerData.slimes.Changed(function(nextSlimes)
			setOwnedSlimes(table.clone(nextSlimes))
		end)

		return function()
			luckConnection()
			cashConnection()
			rebirthConnection()
			ownedProductsConnection()
			ownedSlimesConnection()
		end
	end, {})

	local rebirthMultiplier = RebirthConfig.getRewardMultiplier(rebirths)
	local luckMultiplier = UpgradeConfig.getLuckMultiplier(luckLevel)
		* rebirthMultiplier
		* ProductEntitlements.getLuckMultiplierFromOwnedProducts(ownedProducts)
	local cashMultiplier = UpgradeConfig.getCashMultiplier(cashLevel)
		* rebirthMultiplier
		* ProductEntitlements.getCashMultiplierFromOwnedProducts(ownedProducts)
		* SlimeMutations.getEventCashMultiplier(ownedSlimes)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, if isPhone then 8 else 24, 1, if isPhone then -58 else -80),
		Size = UDim2.fromOffset(if isPhone then 82 else 98, if isPhone then 40 else 48),
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
			IsPhone = isPhone,
		}),
		Cash = React.createElement(MultiplierBadge, {
			Image = CASH_ICON,
			Value = cashMultiplier,
			IsPhone = isPhone,
		}),
	})
end

return MultiplierBadges
