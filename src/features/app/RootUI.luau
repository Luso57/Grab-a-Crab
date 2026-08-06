local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local HudRoot = require(ReplicatedStorage.Source.Features.App.Hud.HudRoot)
local IndexRoot = require(ReplicatedStorage.Source.Features.Index.UI.IndexRoot)
local InventoryRoot = require(ReplicatedStorage.Source.Features.Inventory.UI.InventoryRoot)
local SellingRoot = require(ReplicatedStorage.Source.Features.Selling.UI.SellingRoot)
local SlimeRoot = require(ReplicatedStorage.Source.Features.Slimes.UI.SlimeRoot)
local UpgradeRoot = require(ReplicatedStorage.Source.Features.Upgrades.UI.UpgradeRoot)

local function RootUI()
	local openWindow, setOpenWindow = React.useState(nil :: string?)

	return React.createElement(React.Fragment, nil, {
		Hud = React.createElement(HudRoot, {
			OnInventoryActivated = function()
				setOpenWindow(function(currentWindow)
					return if currentWindow == "Inventory" then nil else "Inventory"
				end)
			end,
			OnIndexActivated = function()
				setOpenWindow(function(currentWindow)
					return if currentWindow == "Index" then nil else "Index"
				end)
			end,
		}),
		Index = React.createElement(IndexRoot, {
			IsOpen = openWindow == "Index",
			OnClose = function()
				setOpenWindow(nil)
			end,
		}),
		Inventory = React.createElement(InventoryRoot, {
			IsOpen = openWindow == "Inventory",
			OnClose = function()
				setOpenWindow(nil)
			end,
		}),
		Selling = React.createElement(SellingRoot),
		Slimes = React.createElement(SlimeRoot),
		Upgrades = React.createElement(UpgradeRoot),
	})
end

return RootUI
