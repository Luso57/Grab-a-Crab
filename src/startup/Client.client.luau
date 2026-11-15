--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local ShopServiceClient = require(ReplicatedStorage.Source.Features.Shop.ShopServiceClient)
local DecorShopServiceClient = require(ReplicatedStorage.Source.Features.DecorShop.DecorShopServiceClient)
local sellStandFolder = ReplicatedStorage.Source.Features:FindFirstChild("SellStand")
local sellStandModule = if sellStandFolder then sellStandFolder:FindFirstChild("SellStandServiceClient") else nil
local SellStandServiceClient = if sellStandModule then require(sellStandModule) else nil
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local EggConveyorServiceClient = require(ReplicatedStorage.Source.Features.EggConveyor.EggConveyorServiceClient)
local TankServiceClient = require(ReplicatedStorage.Source.Features.Tanks.TankServiceClient)
local IncubatorServiceClient = require(ReplicatedStorage.Source.Features.Incubators.IncubatorServiceClient)
local InventoryServiceClient = require(ReplicatedStorage.Source.Features.Inventory.InventoryServiceClient)
local MoneyServiceClient = require(ReplicatedStorage.Source.Features.Money.MoneyServiceClient)
local IndexServiceClient = require(ReplicatedStorage.Source.Features.Index.IndexServiceClient)
local ShopMonoServiceClient = require(ReplicatedStorage.Source.Features.Shopmono.ShopMonoServiceClient)
local LeaderboardServiceClient = require(ReplicatedStorage.Source.Features.Leaderboard.LeaderboardServiceClient)
local RewardsServiceClient = require(ReplicatedStorage.Source.Features.Rewards.RewardsServiceClient)
local SettingsServiceClient = require(ReplicatedStorage.Source.Features.Settings.SettingsServiceClient)
local TutorialServiceClient = require(ReplicatedStorage.Source.Features.Tutorial.TutorialServiceClient)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
SettingsServiceClient:init()
local hoverSound = Instance.new("Sound")
hoverSound.Name = "UIHoverSound"
hoverSound.SoundId = "rbxassetid://" .. assets.UIHoverSound
hoverSound.Volume = 1
hoverSound.Parent = playerGui

local connected: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" })
local function bindHoverSound(instance: Instance)
	if not instance:IsA("GuiButton") or connected[instance]
		or instance.Name == "Dismiss" or instance.Name == "DraggedItem" then
		return
	end
	connected[instance] = true
	instance.MouseEnter:Connect(function()
		if instance.Visible then
			hoverSound.TimePosition = 0
			hoverSound:Play()
		end
	end)
end

playerGui.DescendantAdded:Connect(bindHoverSound)
for _, descendant in playerGui:GetDescendants() do
	bindHoverSound(descendant)
end

ShopMonoServiceClient:init()
IndexServiceClient:init()

ShopServiceClient:init()
DecorShopServiceClient:init()
if SellStandServiceClient then
	SellStandServiceClient:init()
else
	warn("SellStand client modules have not synced to Studio yet")
end
PlotServiceClient:init()
RewardsServiceClient:init()
EggConveyorServiceClient:init()
MoneyServiceClient:init()
TankServiceClient:init()
IncubatorServiceClient:init()
InventoryServiceClient:init()
LeaderboardServiceClient:init()
TutorialServiceClient:init()
