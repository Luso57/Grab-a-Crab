local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local NotificationSlice = require(ReplicatedStorage.Source.Features.App.NotificationSlice)

local DISPLAY_DURATION = 3
local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"

local function NotificationRoot()
	local notification = ReactCharm.useAtom(NotificationSlice.state.current)
	local notificationId = if notification then notification.id else 0

	React.useEffect(function()
		if not notification then
			return
		end

		local cancelled = false
		task.delay(DISPLAY_DURATION, function()
			if not cancelled then
				NotificationSlice.actions.clear(notification.id)
			end
		end)

		return function()
			cancelled = true
		end
	end, { notificationId })

	if not notification then
		return nil
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(218, 48, 48),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.055),
		Size = UDim2.fromScale(0.42, 0.075),
		ZIndex = 100,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),
		Gradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 91, 58)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(174, 25, 37)),
			}),
			Rotation = 90,
		}),
		Pattern = React.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Image = STUD_BACKGROUND_IMAGE,
			ImageTransparency = 0.83,
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.fromScale(1, 1),
			TileSize = UDim2.fromOffset(30, 30),
			ZIndex = 100,
		}),
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = Vector2.new(560, 68),
			MinSize = Vector2.new(290, 48),
		}),
		Stroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(45, 8, 12),
			Thickness = 4,
		}),
		Text = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.04, 0.12),
			Size = UDim2.fromScale(0.92, 0.76),
			Text = notification.text,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			ZIndex = 101,
		}, {
			Constraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 28,
				MinTextSize = 13,
			}),
		}),
	})
end

return NotificationRoot
