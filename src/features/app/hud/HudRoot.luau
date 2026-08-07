local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local BottomBar = require(ReplicatedStorage.Source.Features.App.Hud.BottomBar)
local LeftBottom = require(ReplicatedStorage.Source.Features.App.Hud.LeftBottom)
local MultiplierBadges = require(ReplicatedStorage.Source.Features.App.Hud.MultiplierBadges)
local SideBar = require(ReplicatedStorage.Source.Features.App.Hud.SideBar)

export type Props = {
	OnInventoryActivated: () -> (),
	OnIndexActivated: () -> (),
	OnRebirthActivated: () -> (),
}

local function HudRoot(props: Props)
	return React.createElement(React.Fragment, nil, {
		BottomBar = React.createElement(BottomBar),
		LeftBottom = React.createElement(LeftBottom),
		MultiplierBadges = React.createElement(MultiplierBadges),
		SideBar = React.createElement(SideBar, {
			OnInventoryActivated = props.OnInventoryActivated,
			OnIndexActivated = props.OnIndexActivated,
			OnRebirthActivated = props.OnRebirthActivated,
		}),
	})
end

return HudRoot
