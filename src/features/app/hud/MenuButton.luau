local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)

local HOVER_SCALE = 1.06
local PRESSED_SCALE = 0.95
local TWEEN_INFO = TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

export type Props = {
	Text: string,
	Image: string?,
	LayoutOrder: number?,
	HeightScale: number?,
	ShowAlert: boolean?,
	PlaySelectSound: boolean?,
	OnActivated: (() -> ())?,
}

local function MenuButton(props: Props)
	local scaleRef = React.useRef(nil)
	local activeTweenRef = React.useRef(nil)
	local isHoveredRef = React.useRef(false)

	local function tweenTo(targetScale: number)
		local scale = scaleRef.current
		if not scale then
			return
		end

		if activeTweenRef.current then
			activeTweenRef.current:Cancel()
		end

		local tween = TweenService:Create(scale, TWEEN_INFO, { Scale = targetScale })
		activeTweenRef.current = tween
		tween:Play()
	end

	React.useEffect(function()
		return function()
			if activeTweenRef.current then
				activeTweenRef.current:Cancel()
			end
		end
	end, {})

	return React.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(31, 33, 37),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, props.HeightScale or 0.3),
		Text = "",

		[React.Event.Activated] = function()
			if props.PlaySelectSound ~= false then
				UISounds.playSelect()
			end
			if props.OnActivated then
				props.OnActivated()
			end
		end,
		[React.Event.MouseButton1Down] = function()
			tweenTo(PRESSED_SCALE)
		end,
		[React.Event.MouseButton1Up] = function()
			tweenTo(if isHoveredRef.current then HOVER_SCALE else 1)
		end,
		[React.Event.MouseEnter] = function()
			isHoveredRef.current = true
			tweenTo(HOVER_SCALE)
		end,
		[React.Event.MouseLeave] = function()
			isHoveredRef.current = false
			tweenTo(1)
		end,
	}, {
		AspectRatio = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
			DominantAxis = Enum.DominantAxis.Height,
		}),
		OuterStroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(4, 4, 4),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 4,
		}),
		Scale = React.createElement("UIScale", {
			ref = scaleRef,
			Scale = 1,
		}),
		Alert = if props.ShowAlert then React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 91, 67),
			BorderSizePixel = 0,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.88, 0.12),
			Size = UDim2.fromScale(0.27, 0.27),
			Text = "!",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 10,
		}, {
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(70, 20, 14),
				Thickness = 2,
			}),
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 24,
				MinTextSize = 10,
			}),
		}) else nil,
		IconPlaceholder = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Image or "",
			Position = UDim2.fromScale(0.5, 0.44),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.78, 0.68),
			ZIndex = 3,
		}),
		Label = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.new(0.5, 0, 1, 7),
			Size = UDim2.new(1.18, 0, 0.3, 8),
			Text = props.Text,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			ZIndex = 5,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 2),
			}),
			TextConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 30,
				MinTextSize = 14,
			}),
			TextStroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(5, 5, 5),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 4,
			}),
		}),
	})
end

return MenuButton
