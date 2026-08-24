local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)
local useOwnsProduct = require(ReplicatedStorage.Source.Features.Monetization.Hooks.useOwnsProduct)
local MonetizationServiceClient = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient)

local AUTO_COLLECT_IMAGE = "rbxassetid://139635723208368"
local SUNBURST_IMAGE = "rbxassetid://84880292033466"
local PRODUCT_KEY = "autoCollectSlime"
local PROMPT_COOLDOWN = 1
local SUNBURST_TWEEN_INFO = TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

local function outlinedText(props: { [string]: any })
	return React.createElement("TextLabel", props, {
		Stroke = React.createElement("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = 3,
		}),
	})
end

local function AutoCollectSlimePromo()
	local isPhone = useIsPhoneViewport()
	local isOwned = useOwnsProduct(PRODUCT_KEY)
	local priceText, setPriceText = React.useState("R$ ...")
	local sunburstRef = React.useRef(nil)
	local promptLockedRef = React.useRef(false)

	React.useEffect(function()
		local sunburst = sunburstRef.current
		if not sunburst then return nil end

		local tween = TweenService:Create(sunburst, SUNBURST_TWEEN_INFO, { Rotation = 360 })
		tween:Play()

		return function()
			tween:Cancel()
		end
	end, { isOwned })

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			local productInfo = MonetizationServiceClient:getProductInfo(PRODUCT_KEY)
			if cancelled then return end

			local price = if productInfo then productInfo.PriceInRobux else nil
			setPriceText(if price then "R$ " .. tostring(price) else "R$ ---")
		end)

		return function()
			cancelled = true
		end
	end, {})

	if isOwned then return nil end

	local size = if isPhone then Vector2.new(64, 90) else Vector2.new(120, 170)
	local titleHeight = if isPhone then 20 else 36
	local artworkSize = if isPhone then 54 else 108
	local iconSize = if isPhone then 50 else 100
	local sunburstSize = if isPhone then 72 else 140
	local artworkCenterY = titleHeight + artworkSize / 2

	return React.createElement("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(size.X, size.Y),
		Text = "",
		ZIndex = 10,
		[React.Event.Activated] = function()
			if promptLockedRef.current then return end

			promptLockedRef.current = true
			UISounds.playSelect()
			MonetizationServiceClient:promptProduct(PRODUCT_KEY)
			task.delay(PROMPT_COOLDOWN, function()
				promptLockedRef.current = false
			end)
		end,
	}, {
		Title = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			LineHeight = 0.8,
			Position = UDim2.fromOffset(-8, 0),
			Size = UDim2.new(1, 16, 0, titleHeight),
			Text = "Auto Collect\nSlime",
			TextColor3 = Color3.fromRGB(255, 230, 45),
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 14,
		}),
		Sunburst = React.createElement("ImageLabel", {
			ref = sunburstRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = SUNBURST_IMAGE,
			ImageTransparency = 0,
			Position = UDim2.new(0.5, 0, 0, artworkCenterY),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(sunburstSize, sunburstSize),
			ZIndex = 11,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = AUTO_COLLECT_IMAGE,
			Position = UDim2.new(0.5, 0, 0, artworkCenterY),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(iconSize, iconSize),
			ZIndex = 12,
		}),
		Price = outlinedText({
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(0.82, 0, 0, if isPhone then 18 else 30),
			Text = priceText,
			TextColor3 = Color3.fromRGB(255, 230, 45),
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 14,
		}),
	})
end

return AutoCollectSlimePromo
