local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local MonetizationServiceClient = require(
	ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient
)
local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)
local PassCatalog = require(ReplicatedStorage.Source.Features.Monetization.Modules.PassCatalog)
local useOwnsProduct = require(ReplicatedStorage.Source.Features.Monetization.Hooks.useOwnsProduct)
local RobuxBoardSlice = require(ReplicatedStorage.Source.Features.RobuxBoard.RobuxBoardSlice)

local e = React.createElement
type ProductKey = MonetizationTypes.ProductKey

local CARD_HEIGHT = 145
local CARD_SPACING = 12
local CONTENT_PADDING = 8
local BOARD_VIEWPORT_HEIGHT = 654
local SNAP_DELAY = 0.18
local SNAP_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BOARD_GUI_NAME = "RobuxPassesBoard"
local mountedBoardGuis: { [BasePart]: SurfaceGui } = {}

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
	local isOwned = useOwnsProduct(props.productKey)

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
		Size = UDim2.new(1, -16, 0, CARD_HEIGHT),
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
				Active = not isOwned,
				AutoButtonColor = not isOwned,
				BackgroundColor3 = Color3.fromRGB(46, 255, 63),
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0, 0.4),
				Selectable = not isOwned,
				Size = UDim2.fromScale(1, 0.6),
				Text = if isOwned then "OWNED" else "GET",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 1,
				[React.Event.Activated] = if not isOwned
					then function()
						MonetizationServiceClient:promptProduct(props.productKey)
					end
					else nil,
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
	local boardGuiRef = React.useRef(nil)
	local scrollingFrameRef = React.useRef(nil)
	local snapGenerationRef = React.useRef(0)
	local snapTweenRef = React.useRef(nil)
	local cardStep = CARD_HEIGHT + CARD_SPACING
	local naturalCanvasHeight = #PassCatalog * CARD_HEIGHT
		+ math.max(0, #PassCatalog - 1) * CARD_SPACING
		+ CONTENT_PADDING * 2
	local maxNaturalScroll = math.max(0, naturalCanvasHeight - BOARD_VIEWPORT_HEIGHT)
	local maxSnapPosition = math.ceil(maxNaturalScroll / cardStep) * cardStep
	local canvasHeight = BOARD_VIEWPORT_HEIGHT + maxSnapPosition

	React.useEffect(function()
		local current = boardGuiRef.current :: SurfaceGui?
		if not current then return end

		local previous = mountedBoardGuis[props.board]
		if previous and previous ~= current then
			previous:Destroy()
		end
		mountedBoardGuis[props.board] = current

		return function()
			if mountedBoardGuis[props.board] == current then
				mountedBoardGuis[props.board] = nil
			end
		end
	end, { props.board })

	React.useEffect(function()
		return function()
			local tween = snapTweenRef.current
			if tween then tween:Cancel() end
		end
	end, {})

	local function scheduleSnap(scrollingFrame: ScrollingFrame)
		snapGenerationRef.current += 1
		local generation = snapGenerationRef.current

		task.delay(SNAP_DELAY, function()
			if snapGenerationRef.current ~= generation or scrollingFrameRef.current ~= scrollingFrame then
				return
			end

			local targetY = math.clamp(math.round(scrollingFrame.CanvasPosition.Y / cardStep) * cardStep, 0, maxSnapPosition)
			if math.abs(scrollingFrame.CanvasPosition.Y - targetY) < 0.5 then return end

			local previousTween = snapTweenRef.current
			if previousTween then previousTween:Cancel() end
			local tween = TweenService:Create(scrollingFrame, SNAP_TWEEN_INFO, {
				CanvasPosition = Vector2.new(0, targetY),
			})
			snapTweenRef.current = tween
			tween:Play()
		end)
	end

	local cards = {
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, CONTENT_PADDING),
			PaddingLeft = UDim.new(0, CONTENT_PADDING),
			PaddingRight = UDim.new(0, CONTENT_PADDING),
			PaddingTop = UDim.new(0, CONTENT_PADDING),
		}),
		Layout = e("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, CARD_SPACING),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, pass in PassCatalog do
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
		[BOARD_GUI_NAME] = e("SurfaceGui", {
			Active = true,
			Adornee = props.board,
			AlwaysOnTop = false,
			CanvasSize = Vector2.new(1240, 654),
			Face = Enum.NormalId.Right,
			LightInfluence = 0,
			ref = boardGuiRef,
		}, {
			Content = e("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.None,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, canvasHeight),
				ClipsDescendants = true,
				ScrollBarImageColor3 = Color3.new(1, 1, 1),
				ScrollBarImageTransparency = 0,
				ScrollBarThickness = 14,
				ScrollingEnabled = true,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(1, 1),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ref = scrollingFrameRef,
				[React.Change.CanvasPosition] = scheduleSnap,
			}, cards),
		}),
	})
end

local function RobuxBoard()
	local boards = ReactCharm.useAtom(RobuxBoardSlice.state.boards)
	local elements = {}
	local renderedBoards: { [BasePart]: boolean } = {}

	for entryId, entry in boards do
		if not renderedBoards[entry.board] then
			renderedBoards[entry.board] = true
			elements[entryId] = e(RobuxBoardEntry, entry)
		end
	end

	return e(React.Fragment, nil, elements)
end

return RobuxBoard
