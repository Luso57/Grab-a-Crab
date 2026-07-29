local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"

local BUTTONS = {
	{
		label = "Inventory",
		background = Color3.fromRGB(55, 156, 226),
	},
	{
		label = "Index",
		background = Color3.fromRGB(246, 194, 52),
	},
	{
		label = "Shop",
		background = Color3.fromRGB(238, 82, 71),
	},
	{
		label = "Home",
		background = Color3.fromRGB(55, 156, 226),
	},
	{
		label = "Upgrade",
		background = Color3.fromRGB(246, 194, 52),
	},
}

local function createButton(buttonInfo, layoutOrder: number)
	local label = buttonInfo.label

	return React.createElement("TextButton", {
		AutoButtonColor = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(0.2, -5, 1, 0),
		Text = "",
	}, {
		Background = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = buttonInfo.background,
			BorderSizePixel = 0,
			Image = STUD_BACKGROUND_IMAGE,
			ImageColor3 = buttonInfo.background,
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1.35, 1.35),
			ZIndex = 1,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 10),
			}),
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		Label = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Size = UDim2.fromScale(1, 1),
			Text = label,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(18, 28, 55),
			TextStrokeTransparency = 0,
			ZIndex = 3,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 10),
			}),
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 24,
				MinTextSize = 13,
			}),
		}),
		Stroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(17, 41, 57),
			Thickness = 3,
		}),
	})
end

local function BottomBar()
	local buttons = {}

	for layoutOrder, buttonInfo in BUTTONS do
		buttons[buttonInfo.label] = createButton(buttonInfo, layoutOrder)
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.76, 0, 0, 68),
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = Vector2.new(600, 68),
			MinSize = Vector2.new(330, 58),
		}),
	}, buttons)
end

return BottomBar
