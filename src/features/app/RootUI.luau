local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local HudRoot = require(ReplicatedStorage.Source.Features.App.Hud.HudRoot)
local InventoryRoot = require(ReplicatedStorage.Source.Features.Inventory.UI.InventoryRoot)
local SlimeRoot = require(ReplicatedStorage.Source.Features.Slimes.UI.SlimeRoot)

local function RootUI()
	return React.createElement(React.Fragment, nil, {
		Hud = React.createElement(HudRoot),
		Inventory = React.createElement(InventoryRoot),
		Slimes = React.createElement(SlimeRoot),
	})
end

return RootUI
