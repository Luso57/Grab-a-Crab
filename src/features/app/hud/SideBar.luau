local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local MenuButton = require(ReplicatedStorage.Source.Features.App.Hud.MenuButton)

export type Props = {
	OnInventoryActivated: () -> (),
}

local BUTTONS = {
	{
		Text = "Inventory",
		Image = "rbxthumb://type=Asset&id=121178791801369&w=420&h=420",
	},
	{
		Text = "Index",
		Image = "rbxassetid://127110909372919",
	},
	{
		Text = "Settings",
		Image = "rbxassetid://18209577633",
	},
}

local function SideBar(props: Props)
	local buttons = {}

	for layoutOrder, buttonInfo in BUTTONS do
		buttons[buttonInfo.Text] = React.createElement(MenuButton, {
			Text = buttonInfo.Text,
			Image = buttonInfo.Image,
			LayoutOrder = layoutOrder,
			OnActivated = function()
				if buttonInfo.Text == "Inventory" then
					props.OnInventoryActivated()
				end
			end,
		})
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.new(0.082, 0, 0.54, 0),
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.035, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
		}),
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = Vector2.new(96, 415),
			MinSize = Vector2.new(64, 275),
		}),
	}, buttons)
end

return SideBar
