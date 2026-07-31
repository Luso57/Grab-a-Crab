local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SideBar = require(ReplicatedStorage.Source.Features.App.Hud.SideBar)

export type Props = {
	OnInventoryActivated: () -> (),
}

local function HudRoot(props: Props)
	return React.createElement(React.Fragment, nil, {
		SideBar = React.createElement(SideBar, {
			OnInventoryActivated = props.OnInventoryActivated,
		}),
	})
end

return HudRoot
