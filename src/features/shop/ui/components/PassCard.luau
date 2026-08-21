local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local MonetizationServiceClient = require(
	ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient
)
local PassCatalog = require(ReplicatedStorage.Source.Features.Monetization.Modules.PassCatalog)
local useOwnsProduct = require(ReplicatedStorage.Source.Features.Monetization.Hooks.useOwnsProduct)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)

export type Props = {
	Entry: PassCatalog.Entry,
	LayoutOrder: number,
	Color: Color3,
}

local function outlinedText(props: { [string]: any }, thickness: number?)
	return React.createElement("TextLabel", props, {
		Stroke = React.createElement("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = thickness or 3,
		}),
	})
end

local function PassCard(props: Props)
	local priceText, setPriceText = React.useState("R$ ...")
	local isOwned = useOwnsProduct(props.Entry.productKey)

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			local productInfo = MonetizationServiceClient:getProductInfo(props.Entry.productKey)
			if not cancelled then
				local price = if productInfo then productInfo.PriceInRobux else nil
				setPriceText(if price then "R$ " .. tostring(price) else "R$ ---")
			end
		end)

		return function()
			cancelled = true
		end
	end, { props.Entry.productKey })

	return React.createElement("Frame", {
		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		ZIndex = 34,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = Color3.fromRGB(18, 37, 48),
			Thickness = 4,
		}),
		Title = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.035, 0.035),
			Size = UDim2.fromScale(0.93, 0.23),
			Text = props.Entry.name,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 35,
		}, 3),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = props.Entry.image,
			Position = UDim2.fromScale(0.04, 0.58),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.37, 0.58),
			ZIndex = 35,
		}),
		Description = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.42, 0.29),
			Size = UDim2.fromScale(0.54, 0.34),
			Text = props.Entry.description,
			TextColor3 = Color3.fromRGB(39, 255, 49),
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextWrapped = true,
			ZIndex = 35,
		}, 3),
		Purchase = React.createElement("TextButton", {
			Active = not isOwned,
			AutoButtonColor = not isOwned,
			BackgroundColor3 = if isOwned then Color3.fromRGB(95, 128, 99) else Color3.fromRGB(42, 239, 28),
			BorderSizePixel = 0,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.46, 0.69),
			Selectable = not isOwned,
			Size = UDim2.fromScale(0.5, 0.24),
			Text = if isOwned then "OWNED" else priceText,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 36,
			[React.Event.Activated] = if not isOwned
				then function()
					UISounds.playSelect()
					MonetizationServiceClient:promptProduct(props.Entry.productKey)
				end
				else nil,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 9),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(0, 104, 15),
				Thickness = 4,
			}),
			TextStroke = React.createElement("UIStroke", {
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 3,
			}),
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 28,
				MinTextSize = 12,
			}),
		}),
	})
end

return PassCard
