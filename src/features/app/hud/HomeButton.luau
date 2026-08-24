local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local SlimeEventConfig = require(ReplicatedStorage.Source.Features.Events.Events.Slimedrop.SlimeDropConfig)

local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"
local ACTIVATION_COOLDOWN = 0.75
local HOVER_SCALE = 1.04
local PRESSED_SCALE = 0.96
local TWEEN_INFO = TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function HomeButton()
	local player = Players.LocalPlayer
	local isPhone = useIsPhoneViewport()
	local isCarrying, setIsCarrying = React.useState(player:GetAttribute(SlimeEventConfig.CarryingAttribute) == true)
	local scaleRef = React.useRef(nil)
	local activeTweenRef = React.useRef(nil)
	local isHoveredRef = React.useRef(false)
	local lastActivatedRef = React.useRef(0)

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

	React.useEffect(function()
		local function update()
			setIsCarrying(player:GetAttribute(SlimeEventConfig.CarryingAttribute) == true)
		end
		local connection = player:GetAttributeChangedSignal(SlimeEventConfig.CarryingAttribute):Connect(update)
		update()
		return function() connection:Disconnect() end
	end, { player })

	if isCarrying then return nil end

	return React.createElement("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(15, 102, 45),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(if isPhone then 0.13 else 0.15, 0, 0, if isPhone then 64 else 73),
		Text = "",
		ZIndex = 10,
		[React.Event.Activated] = function()
			local now = os.clock()
			if now - lastActivatedRef.current < ACTIVATION_COOLDOWN then
				return
			end
			lastActivatedRef.current = now
			UISounds.playSelect()
			local plot = PlotServiceClient:getLocalPlayerPlot()
			if plot then
				plot:teleportHome()
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
			AspectRatio = 4.2,
			DominantAxis = Enum.DominantAxis.Width,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		OuterStroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(3, 32, 17),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = 4,
		}),
		Scale = React.createElement("UIScale", {
			ref = scaleRef,
			Scale = 1,
		}),
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = if isPhone then Vector2.new(235, 63) else Vector2.new(275, 74),
			MinSize = if isPhone then Vector2.new(155, 38) else Vector2.new(180, 44),
		}),
		Face = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(39, 174, 76),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -12),
			ZIndex = 11,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 2),
			}),
			Studs = React.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				Image = STUD_BACKGROUND_IMAGE,
				ImageColor3 = Color3.fromRGB(105, 242, 126),
				ImageTransparency = 0.18,
				ScaleType = Enum.ScaleType.Tile,
				Position = UDim2.fromOffset(0, -4),
				Size = UDim2.new(1, 0, 1, 4),
				TileSize = UDim2.fromOffset(116, 116),
				ZIndex = 11,
			}),
			Highlight = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(176, 255, 188),
				BackgroundTransparency = 0.58,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 4),
				ZIndex = 12,
			}),
		}),
		Label = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(0.68, 0.6),
			Text = "Home",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 13,
		}, {
			Constraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = if isPhone then 33 else 38,
				MinTextSize = if isPhone then 18 else 21,
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 4,
			}),
		}),
	})
end

return HomeButton
