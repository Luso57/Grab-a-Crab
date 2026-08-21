local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local BottomBar = require(ReplicatedStorage.Source.Features.App.Hud.BottomBar)
local ESCUI = require(ReplicatedStorage.Source.Features.App.Hud.ESCUI)
local HomeButton = require(ReplicatedStorage.Source.Features.App.Hud.HomeButton)
local LeftHud = require(ReplicatedStorage.Source.Features.App.Hud.LeftHud)
local LeftBottom = require(ReplicatedStorage.Source.Features.App.Hud.LeftBottom)
local MultiplierBadges = require(ReplicatedStorage.Source.Features.App.Hud.MultiplierBadges)
local SideBar = require(ReplicatedStorage.Source.Features.App.Hud.SideBar)
local useTutorialState = require(ReplicatedStorage.Source.Features.Tutorial.Hooks.useTutorialState)

export type Props = {
	OnInventoryActivated: () -> (),
	OnIndexActivated: () -> (),
	OnRebirthActivated: () -> (),
	OnShopActivated: () -> (),
	OnSettingsActivated: () -> (),
}

local function HudRoot(props: Props)
	local _, isTutorialActive = useTutorialState()

	return React.createElement(React.Fragment, nil, {
		BottomBar = React.createElement(BottomBar),
		ESCUI = React.createElement(ESCUI),
		HomeButton = if isTutorialActive then nil else React.createElement(HomeButton),
		LeftHud = if isTutorialActive then nil else React.createElement(LeftHud, {
			OnShopActivated = props.OnShopActivated,
		}),
		LeftBottom = React.createElement(LeftBottom),
		MultiplierBadges = if isTutorialActive then nil else React.createElement(MultiplierBadges),
		SideBar = if isTutorialActive then nil else React.createElement(SideBar, {
			OnInventoryActivated = props.OnInventoryActivated,
			OnIndexActivated = props.OnIndexActivated,
			OnRebirthActivated = props.OnRebirthActivated,
			OnSettingsActivated = props.OnSettingsActivated,
		}),
	})
end

return HudRoot
