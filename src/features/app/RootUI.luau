local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local HudRoot = require(ReplicatedStorage.Source.Features.App.Hud.HudRoot)
local NotificationRoot = require(ReplicatedStorage.Source.Features.App.NotificationRoot)
local IndexRoot = require(ReplicatedStorage.Source.Features.Index.UI.IndexRoot)
local InventoryRoot = require(ReplicatedStorage.Source.Features.Inventory.UI.InventoryRoot)
local InventorySlice = require(ReplicatedStorage.Source.Features.Inventory.InventorySlice)
local LeaderboardRoot = require(ReplicatedStorage.Source.Features.Leaderboards.UI.LeaderboardRoot)
local PlotLevelRoot = require(ReplicatedStorage.Source.Features.PlotLevels.UI.PlotLevelRoot)
local RebirthRoot = require(ReplicatedStorage.Source.Features.Rebirth.UI.RebirthRoot)
local SellingRoot = require(ReplicatedStorage.Source.Features.Selling.UI.SellingRoot)
local SlimeRoot = require(ReplicatedStorage.Source.Features.Slimes.UI.SlimeRoot)
local UpgradeRoot = require(ReplicatedStorage.Source.Features.Upgrades.UI.UpgradeRoot)

local function RootUI()
	local isInventoryOpen = ReactCharm.useAtom(InventorySlice.state.isOpen)
	local isIndexOpen, setIndexOpen = React.useState(false)
	local isRebirthOpen, setRebirthOpen = React.useState(false)

	React.useEffect(function()
		if isInventoryOpen then
			setIndexOpen(false)
			setRebirthOpen(false)
		end
	end, { isInventoryOpen })

	return React.createElement(React.Fragment, nil, {
		Notifications = React.createElement(NotificationRoot),
		Hud = React.createElement(HudRoot, {
			OnInventoryActivated = function()
				setIndexOpen(false)
				setRebirthOpen(false)
				InventorySlice.actions.toggle()
			end,
			OnIndexActivated = function()
				InventorySlice.actions.close()
				setRebirthOpen(false)
				setIndexOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
			OnRebirthActivated = function()
				InventorySlice.actions.close()
				setIndexOpen(false)
				setRebirthOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
		}),
		Index = React.createElement(IndexRoot, {
			IsOpen = isIndexOpen,
			OnClose = function()
				setIndexOpen(false)
			end,
		}),
		Inventory = React.createElement(InventoryRoot, {
			IsOpen = isInventoryOpen,
			OnClose = function()
				InventorySlice.actions.close()
			end,
		}),
		Leaderboards = React.createElement(LeaderboardRoot),
		PlotLevels = React.createElement(PlotLevelRoot),
		Rebirth = React.createElement(RebirthRoot, {
			IsOpen = isRebirthOpen,
			OnClose = function()
				setRebirthOpen(false)
			end,
		}),
		Selling = React.createElement(SellingRoot),
		Slimes = React.createElement(SlimeRoot),
		Upgrades = React.createElement(UpgradeRoot),
	})
end

return RootUI
