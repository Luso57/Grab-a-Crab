local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)
local HudRoot = require(ReplicatedStorage.Source.Features.App.Hud.HudRoot)
local NotificationRoot = require(ReplicatedStorage.Source.Features.App.NotificationRoot)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local IndexRoot = require(ReplicatedStorage.Source.Features.Index.UI.IndexRoot)
local InventoryRoot = require(ReplicatedStorage.Source.Features.Inventory.UI.InventoryRoot)
local InventorySlice = require(ReplicatedStorage.Source.Features.Inventory.InventorySlice)
local OfflineRewardsRoot = require(ReplicatedStorage.Source.Features.Offlinerewards.UI.OfflineRewardsRoot)
local OfflineRewardsSlice = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsSlice)
local LeaderboardRoot = require(ReplicatedStorage.Source.Features.Leaderboards.UI.LeaderboardRoot)
local PlotLevelRoot = require(ReplicatedStorage.Source.Features.PlotLevels.UI.PlotLevelRoot)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local RebirthRoot = require(ReplicatedStorage.Source.Features.Rebirth.UI.RebirthRoot)
local RobuxBoardRoot = require(ReplicatedStorage.Source.Features.RobuxBoard.UI.RobuxBoardRoot)
local SellingRoot = require(ReplicatedStorage.Source.Features.Selling.UI.SellingRoot)
local SettingsRoot = require(ReplicatedStorage.Source.Features.Settings.UI.SettingsRoot)
local ShopRoot = require(ReplicatedStorage.Source.Features.Shop.UI.ShopRoot)
local SlimeRoot = require(ReplicatedStorage.Source.Features.Slimes.UI.SlimeRoot)
local UpgradeRoot = require(ReplicatedStorage.Source.Features.Upgrades.UI.UpgradeRoot)
local TutorialRoot = require(ReplicatedStorage.Source.Features.Tutorial.UI.TutorialRoot)

local function createPlotOwnerBillboard(entry: PlotServiceClient.PlotOwnerEntry, isPhone: boolean)
	local scale = if isPhone then 0.65 else 1

	return React.createElement("BillboardGui", {
		Adornee = entry.adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 1000,
		Size = UDim2.fromOffset(320 * scale, 125 * scale),
	}, {
		Avatar = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.userId),
			Position = UDim2.fromOffset(160 * scale, 0),
			Size = UDim2.fromOffset(72 * scale, 72 * scale),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.new(0, 0, 0),
				Thickness = 3 * scale,
			}),
		}),
		Name = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromOffset(0, 77 * scale),
			Size = UDim2.fromOffset(320 * scale, 43 * scale),
			Text = entry.playerName .. "'s Plot",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
		}, {
			TextSize = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 34 * scale,
				MinTextSize = 16 * scale,
			}),
		}),
	})
end

local function PlotOwnerBillboards()
	local isPhone = useIsPhoneViewport()
	local plotOwners = ReactCharm.useAtom(PlotServiceClient.state.plotOwners)
	local billboards = {}

	for plotIndex, entry in plotOwners do
		billboards[tostring(plotIndex)] = createPlotOwnerBillboard(entry, isPhone)
	end

	return React.createElement(React.Fragment, nil, billboards)
end

local function RootUI()
	local isInventoryOpen = ReactCharm.useAtom(InventorySlice.state.isOpen)
	local isOfflineRewardsOpen = ReactCharm.useAtom(OfflineRewardsSlice.state.isOpen)
	local isIndexOpen, setIndexOpen = React.useState(false)
	local isRebirthOpen, setRebirthOpen = React.useState(false)
	local isSettingsOpen, setSettingsOpen = React.useState(false)
	local isShopOpen, setShopOpen = React.useState(false)

	React.useEffect(function()
		if isInventoryOpen then
			setIndexOpen(false)
			setRebirthOpen(false)
			setSettingsOpen(false)
			setShopOpen(false)
		end
	end, { isInventoryOpen })

	React.useEffect(function()
		if isOfflineRewardsOpen then
			InventorySlice.actions.close()
			setIndexOpen(false)
			setRebirthOpen(false)
			setSettingsOpen(false)
			setShopOpen(false)
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
				setShopOpen(false)
				InventorySlice.actions.toggle()
			end,
			OnIndexActivated = function()
				OfflineRewardsSlice.actions.hide()
				InventorySlice.actions.close()
				setRebirthOpen(false)
				setSettingsOpen(false)
				setShopOpen(false)
				setIndexOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
			OnRebirthActivated = function()
				OfflineRewardsSlice.actions.hide()
				InventorySlice.actions.close()
				setIndexOpen(false)
				setSettingsOpen(false)
				setShopOpen(false)
				setRebirthOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
			OnSettingsActivated = function()
				OfflineRewardsSlice.actions.hide()
				InventorySlice.actions.close()
				setIndexOpen(false)
				setRebirthOpen(false)
				setShopOpen(false)
				setSettingsOpen(function(wasOpen)
					return not wasOpen
				end)
			end,
			OnShopActivated = function()
				OfflineRewardsSlice.actions.hide()
				InventorySlice.actions.close()
				setIndexOpen(false)
				setRebirthOpen(false)
				setSettingsOpen(false)
				if not isShopOpen then
					UISounds.playShopOpen()
				end
				setShopOpen(not isShopOpen)
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
		PlotOwners = React.createElement(PlotOwnerBillboards),
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
		Shop = React.createElement(ShopRoot, {
			IsOpen = isShopOpen,
			OnClose = function()
				setShopOpen(false)
			end,
		}),
		OfflineRewards = React.createElement(OfflineRewardsRoot, {
			IsOpen = isOfflineRewardsOpen,
			OnClose = OfflineRewardsSlice.actions.hide,
		}),
		Slimes = React.createElement(SlimeRoot),
		Upgrades = React.createElement(UpgradeRoot),
		Tutorial = React.createElement(TutorialRoot),
	})
end

return RootUI
