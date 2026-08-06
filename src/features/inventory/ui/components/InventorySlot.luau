local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type Props = {
	Name: string,
	Image: string?,
	Rarity: string?,
	RarityColor: Color3?,
	Quantity: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function InventorySlot(props: Props)
	local rarityColor = props.RarityColor or Color3.fromRGB(125, 128, 135)

	return React.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(25, 27, 32),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Text = "",
		[React.Event.Activated] = function()
			if props.OnActivated then
				props.OnActivated()
			end
		end,
	}, {
		AspectRatio = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		Gradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 45, 52)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 22, 27)),
			}),
			Rotation = 90,
		}),
		RarityStroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = rarityColor,
			Thickness = 2,
			Transparency = 0.12,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Image or "",
			Position = UDim2.fromScale(0.5, 0.36),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.76, 0.56),
		}),
		Rarity = props.Rarity and React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.72),
			Size = UDim2.fromScale(0.88, 0.15),
			Text = props.Rarity,
			TextColor3 = rarityColor,
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
		}, {
			Constraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 17,
				MinTextSize = 9,
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 2,
			}),
		}),
		Name = props.Name ~= "" and React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.96),
			Size = UDim2.new(0.9, 0, 0.18, 0),
			Text = props.Name,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
		}, {
			Constraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 17,
				MinTextSize = 8,
			}),
		}),
		Quantity = props.Quantity and React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.94, 0.06),
			Size = UDim2.fromScale(0.36, 0.2),
			Text = `x{props.Quantity}`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
		}, {
			Constraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 16,
				MinTextSize = 9,
			}),
		}),
	})
end

return InventorySlot
