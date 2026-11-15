--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local EggConveyorServiceServer = require(ServerScriptService.Features.EggConveyor.EggConveyorServiceServer)
local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local ShopServiceServer = require(ServerScriptService.Features.Shop.ShopServiceServer)
local DecorShopServiceServer = require(ServerScriptService.Features.DecorShop.DecorShopServiceServer)
local MonotizationServiceServer = require(ServerScriptService.Features.Monotization.MonotizationServiceServer)
local sellStandFolder = ServerScriptService.Features:FindFirstChild("SellStand")
local sellStandModule = if sellStandFolder then sellStandFolder:FindFirstChild("SellStandServiceServer") else nil
local SellStandServiceServer = if sellStandModule then require(sellStandModule) else nil
local IndexServiceServer = require(ServerScriptService.Features.Index.IndexServiceServer)
local ShopMonoServiceServer = require(ServerScriptService.Features.Shopmono.ShopMonoServiceServer)
local LeaderboardServiceServer = require(ServerScriptService.Features.Leaderboard.LeaderboardServiceServer)
local RewardsServiceServer = require(ServerScriptService.Features.Rewards.RewardsServiceServer)
local SettingsServiceServer = require(ServerScriptService.Features.Settings.SettingsServiceServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)

SettingsServiceServer:init()
ShopMonoServiceServer:init()
EggConveyorServiceServer:init()
TutorialServiceServer:init()
TankServiceServer:init()
PlotServiceServer:init()
IncubatorServiceServer:init()
InventoryServiceServer:init()
ShopServiceServer:init()
DecorShopServiceServer:init()
MonotizationServiceServer:init()
if SellStandServiceServer then
	SellStandServiceServer:init()
else
	warn("SellStand server modules have not synced to Studio yet")
end
IndexServiceServer:init()
LeaderboardServiceServer:init()
RewardsServiceServer:init()
