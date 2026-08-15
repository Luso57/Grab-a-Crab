local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local HudRoot = require(ReplicatedStorage.Source.Features.App.Hud.HudRoot)
local NotificationRoot = require(ReplicatedStorage.Source.Features.App.NotificationRoot)
local IndexRoot = require(ReplicatedStorage.Source.Features.Index.UI.IndexRoot)
local InventoryRoot = require(ReplicatedStorage.Source.Features.Inventory.UI.InventoryRoot)
local InventorySlice = require(ReplicatedStorage.Source.Features.Inventory.InventorySlice)
local OfflineRewardsRoot = require(ReplicatedStorage.Source.Features.Offlinerewards.UI.OfflineRewardsRoot)
local OfflineRewardsSlice = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsSlice)
local LeaderboardRoot = require(ReplicatedStorage.Source.Features.Leaderboards.UI.LeaderboardRoot)
local PlotLevelRoot = require(ReplicatedStorage.Source.Features.PlotLevels.UI.PlotLevelRoot)
local RebirthRoot = require(ReplicatedStorage.Source.Features.Rebirth.UI.RebirthRoot)
local RobuxBoardRoot = require(ReplicatedStorage.Source.Features.RobuxBoard.UI.RobuxBoardRoot)
local SellingRoot = require(ReplicatedStorage.Source.Features.Selling.UI.SellingRoot)
local SettingsRoot = require(ReplicatedStorage.Source.Features.Settings.UI.SettingsRoot)
local SlimeRoot = require(ReplicatedStorage.Source.Features.Slimes.UI.SlimeRoot)
local UpgradeRoot = require(ReplicatedStorage.Source.Features.Upgrades.UI.UpgradeRoot)

local function RootUI()
	local isInventoryOpen = ReactCharm.useAtom(InventorySlice.state.isOpen)
	local isOfflineRewardsOpen = ReactCharm.useAtom(OfflineRewardsSlice.state.isOpen)
	local isIndexOpen, setIndexOpen = React.useState(false)
	local isRebirthOpen, setRebirthOpen = React.useState(false)
	local isSettingsOpen, setSettingsOpen = React.useState(false)

	React.useEffect(function()
		if isInventoryOpen then
			setIndexOpen(false)
			setRebirthOpen(false)
			setSettingsOpen(false)
		end
	end, { isInventoryOpen })

	React.useEffect(function()
		if isOfflineRewardsOpen then
			InventorySlice.actions.close()
			setIndexOpen(false)
			setRebirthOpen(false)
			setSettingsOpen(false)
		end
	end, { isOfflineRewardsOpen })

	return React.createElement(React.Fragment, nil, {
		Notifications = React.createElement(NotificationRoot),
		Hud = React.createElement(HudRoot, {
			OnInventoryActivated = function()
				OfflineRewardsSlice.actions.hide()
				setIndexOpen(false)
				setRebirthOpen(false)
				setSettingsOpen(false)
				InventorySlice.actions.toggle()
			end,
			OnIndexActivated = function()
				OfflineRewardsSlice.actions.hide()
				InventorySlice.actions.close()
				setRebirthOpen(false)
				setSettingsOpen(false)
				setIndexOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
			OnRebirthActivated = function()
				OfflineRewardsSlice.actions.hide()
				InventorySlice.actions.close()
				setIndexOpen(false)
				setSettingsOpen(false)
				setRebirthOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
			OnSettingsActivated = function()
				OfflineRewardsSlice.actions.hide()
				InventorySlice.actions.close()
				setIndexOpen(false)
				setRebirthOpen(false)
				setSettingsOpen(function(wasOpen)
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
		RobuxBoard = React.createElement(RobuxBoardRoot),
		Selling = React.createElement(SellingRoot),
		Settings = React.createElement(SettingsRoot, {
			IsOpen = isSettingsOpen,
			OnClose = function()
				setSettingsOpen(false)
			end,
		}),
		OfflineRewards = React.createElement(OfflineRewardsRoot, {
			IsOpen = isOfflineRewardsOpen,
			OnClose = OfflineRewardsSlice.actions.hide,
		}),
		Slimes = React.createElement(SlimeRoot),
		Upgrades = React.createElement(UpgradeRoot),
	})
end

return RootUI
