local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)
local AutoCollectSlimePromo = require(ReplicatedStorage.Source.Features.App.Hud.AutoCollectSlimePromo)
local MenuButton = require(ReplicatedStorage.Source.Features.App.Hud.MenuButton)

export type Props = {
	OnShopActivated: () -> (),
}

local SHOP_IMAGE = "rbxthumb://type=Asset&id=14736132203&w=420&h=420"

local function LeftHud(props: Props)
	local isPhone = useIsPhoneViewport()

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, if isPhone then 4 else 22, 0.5, if isPhone then 14 else 0),
		Size = UDim2.new(if isPhone then 0.07 else 0.082, 0, 0.135, 0),
	}, {
		Shop = React.createElement(MenuButton, {
			Text = "SHOP",
			Image = SHOP_IMAGE,
			HeightScale = 1,
			PlaySelectSound = false,
			OnActivated = props.OnShopActivated,
		}),
		AutoCollectSlimePromo = React.createElement(AutoCollectSlimePromo),
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = if isPhone then Vector2.new(82, 88) else Vector2.new(96, 104),
			MinSize = if isPhone then Vector2.new(54, 61) else Vector2.new(64, 72),
		}),
	})
end

return LeftHud
