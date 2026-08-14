local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local MonetizationServiceClient = require(
	ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient
)
local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)
local RobuxBoardSlice = require(ReplicatedStorage.Source.Features.RobuxBoard.RobuxBoardSlice)

local e = React.createElement
type ProductKey = MonetizationTypes.ProductKey

local PASSES = {
	{
		productKey = "doubleRolls",
		name = "DOUBLE ROLLS",
		description = "Roll 2 slimes at ONCE!",
		image = "rbxassetid://124008362874496",
	},
	{
		productKey = "doubleRollSpeed",
		name = "2X ROLL SPEED",
		description = "Roll twice as fast!",
		image = "rbxassetid://97947083217374",
	},
	{
		productKey = "doublePermanentLuck",
		name = "2X PERMANENT LUCK",
		description = "Permanent 2x Luck",
		image = "rbxassetid://100469640960520",
	},
	{
		productKey = "quadruplePermanentLuck",
		name = "4X PERMANENT LUCK",
		description = "Permanent 4x Luck",
		image = "rbxassetid://82906043483694",
	},
	{
		productKey = "autoCollect",
		name = "AUTO COLLECT",
		description = "Automatically collect your earnings!",
		image = "rbxassetid://124299228503480",
	},
	{
		productKey = "doubleCash",
		name = "2X CASH",
		description = "Earn twice as much cash!",
		image = "rbxassetid://132439188223524",
	},
}
local function outlinedText(props: { [string]: any }, thickness: number?)
	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = thickness or 3,
		}),
	})
end

local function PassCard(props: {
	layoutOrder: number,
	productKey: ProductKey,
	name: string,
	description: string,
	image: string,
})
	local priceText, setPriceText = React.useState("R$ ...")

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			local productInfo = MonetizationServiceClient:getProductInfo(props.productKey)
			if not cancelled then
				local price = if productInfo then productInfo.PriceInRobux else nil
				setPriceText(if price then "R$ " .. tostring(price) else "R$ ---")
			end
		end)

		return function()
			cancelled = true
		end
	end, { props.productKey })
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(24, 20, 16),
		BackgroundTransparency = 0.16,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, -16, 0, 145),
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 24) }),
		Border = e("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4 }),
		Icon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(77, 62, 48),
			Image = props.image,
			Position = UDim2.fromScale(0.035, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(100, 100),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 22) }),
		}),
		Name = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.14, 0.12),
			Size = UDim2.fromScale(0.51, 0.27),
			Text = props.name,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, 2),

		Description = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.14, 0.48),
			Size = UDim2.fromScale(0.51, 0.3),
			Text = props.description,
			TextColor3 = Color3.fromRGB(255, 76, 255),
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, 2),

		Purchase = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.7, 0.08),
			Size = UDim2.fromScale(0.25, 0.84),
		}, {
			Price = outlinedText({
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 0.36),
				Text = priceText,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 1,
			}, 2),
			Button = e("TextButton", {
				Active = true,
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromRGB(46, 255, 63),
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0, 0.4),
				Selectable = true,
				Size = UDim2.fromScale(1, 0.6),
				Text = "GET",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 1,
				[React.Event.Activated] = function()
					MonetizationServiceClient:promptProduct(props.productKey)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0.15, 0) }),
				Border = e("UIStroke", { Color = Color3.fromRGB(0, 115, 14), Thickness = 4 }),
				TextStroke = e("UIStroke", {
					Color = Color3.new(0, 0, 0),
					LineJoinMode = Enum.LineJoinMode.Round,
					Thickness = 3,
				}),
			}),
		}),
	})
end

local function RobuxBoardEntry(props: { title: BasePart, board: BasePart })
	local cards = {
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
		}),
		Layout = e("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, pass in PASSES do
		cards[`Pass{index}`] = e(PassCard, {
			layoutOrder = index,
			productKey = pass.productKey,
			name = pass.name,
			description = pass.description,
			image = pass.image,
		})
	end

	return e(React.Fragment, nil, {
		Title = e("SurfaceGui", {
			Adornee = props.title,
			AlwaysOnTop = false,
			CanvasSize = Vector2.new(200, 900),
			Face = Enum.NormalId.Bottom,
			LightInfluence = 0,
		}, {
			Text = outlinedText({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = 90,
				Size = UDim2.fromOffset(810, 164),
				Text = "Passes",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 1,
			}, 6),
		}),
		Board = e("SurfaceGui", {
			Active = true,
			Adornee = props.board,
			AlwaysOnTop = false,
			CanvasSize = Vector2.new(1240, 654),
			Face = Enum.NormalId.Right,
			LightInfluence = 0,
		}, {
			Content = e("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				ScrollBarImageColor3 = Color3.new(1, 1, 1),
				ScrollBarThickness = 10,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(1, 1),
			}, cards),
		}),
	})
end

local function RobuxBoard()
	local boards = ReactCharm.useAtom(RobuxBoardSlice.state.boards)
	local elements = {}

	for entryId, entry in boards do
		elements[entryId] = e(RobuxBoardEntry, entry)
	end

	return e(React.Fragment, nil, elements)
end

return RobuxBoard
