local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local InventoryWindow = require(ReplicatedStorage.Source.Features.Inventory.UI.Screens.InventoryWindow)

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function InventoryRoot(props: Props)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.IsOpen,
		ZIndex = 20,
	}, {
		Window = React.createElement(InventoryWindow, {
			OnClose = props.OnClose,
		}),
	})
end

return InventoryRoot
