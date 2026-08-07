local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local MenuButton = require(ReplicatedStorage.Source.Features.App.Hud.MenuButton)

local BASE_BUTTON_COUNT = 3
local BASE_HEIGHT_SCALE = 0.54
local BASE_BUTTON_HEIGHT_SCALE = 0.3
local BASE_LIST_PADDING_SCALE = 0.035
local BASE_MAX_HEIGHT = 415
local BASE_MIN_HEIGHT = 275

export type Props = {
	OnInventoryActivated: () -> (),
	OnIndexActivated: () -> (),
	OnRebirthActivated: () -> (),
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
		Text = "Rebirth",
		Image = "rbxthumb://type=Asset&id=95323324259523&w=420&h=420",
	},
	{
		Text = "Settings",
		Image = "rbxassetid://18209577633",
	},
}

local function SideBar(props: Props)
	local buttons = {}
	local buttonCountScale = #BUTTONS / BASE_BUTTON_COUNT
	local buttonHeightScale = BASE_BUTTON_HEIGHT_SCALE / buttonCountScale
	local listPaddingScale = BASE_LIST_PADDING_SCALE / buttonCountScale

	for layoutOrder, buttonInfo in BUTTONS do
		buttons[buttonInfo.Text] = React.createElement(MenuButton, {
			Text = buttonInfo.Text,
			Image = buttonInfo.Image,
			LayoutOrder = layoutOrder,
			HeightScale = buttonHeightScale,
			OnActivated = function()
				if buttonInfo.Text == "Inventory" then
					props.OnInventoryActivated()
				elseif buttonInfo.Text == "Index" then
					props.OnIndexActivated()
				elseif buttonInfo.Text == "Rebirth" then
					props.OnRebirthActivated()
				end
			end,
		})
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.new(0.082, 0, BASE_HEIGHT_SCALE * buttonCountScale, 0),
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(listPaddingScale, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
		}),
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = Vector2.new(96, math.round(BASE_MAX_HEIGHT * buttonCountScale)),
			MinSize = Vector2.new(64, math.round(BASE_MIN_HEIGHT * buttonCountScale)),
		}),
	}, buttons)
end

return SideBar
