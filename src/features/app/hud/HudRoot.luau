local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local BottomBar = require(ReplicatedStorage.Source.Features.App.Hud.BottomBar)
local HomeButton = require(ReplicatedStorage.Source.Features.App.Hud.HomeButton)
local LeftBottom = require(ReplicatedStorage.Source.Features.App.Hud.LeftBottom)
local MultiplierBadges = require(ReplicatedStorage.Source.Features.App.Hud.MultiplierBadges)
local SideBar = require(ReplicatedStorage.Source.Features.App.Hud.SideBar)

export type Props = {
	OnInventoryActivated: () -> (),
	OnIndexActivated: () -> (),
	OnRebirthActivated: () -> (),
	OnSettingsActivated: () -> (),
}

local function HudRoot(props: Props)
	return React.createElement(React.Fragment, nil, {
		BottomBar = React.createElement(BottomBar),
		HomeButton = React.createElement(HomeButton),
		LeftBottom = React.createElement(LeftBottom),
		MultiplierBadges = React.createElement(MultiplierBadges),
		SideBar = React.createElement(SideBar, {
			OnInventoryActivated = props.OnInventoryActivated,
			OnIndexActivated = props.OnIndexActivated,
			OnRebirthActivated = props.OnRebirthActivated,
			OnSettingsActivated = props.OnSettingsActivated,
		}),
	})
end

return HudRoot
