local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local HudRoot = require(ReplicatedStorage.Source.Features.App.Hud.HudRoot)
local InventoryRoot = require(ReplicatedStorage.Source.Features.Inventory.UI.InventoryRoot)
local SlimeRoot = require(ReplicatedStorage.Source.Features.Slimes.UI.SlimeRoot)

local function RootUI()
	local isInventoryOpen, setInventoryOpen = React.useState(false)

	return React.createElement(React.Fragment, nil, {
		Hud = React.createElement(HudRoot, {
			OnInventoryActivated = function()
				setInventoryOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
		}),
		Inventory = React.createElement(InventoryRoot, {
			IsOpen = isInventoryOpen,
			OnClose = function()
				setInventoryOpen(false)
			end,
		}),
		Slimes = React.createElement(SlimeRoot),
	})
end

return RootUI
