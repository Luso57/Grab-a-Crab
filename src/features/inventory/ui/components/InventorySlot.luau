local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type Props = {
	Name: string,
	Image: string?,
	Quantity: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function InventorySlot(props: Props)
	return React.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
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
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Image or "",
			Position = UDim2.fromScale(0.5, 0.42),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.72, 0.62),
		}),
		Name = props.Name ~= "" and React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.new(0.92, 0, 0.24, 0),
			Text = props.Name,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
		}, {
			Constraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 18,
				MinTextSize = 10,
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
