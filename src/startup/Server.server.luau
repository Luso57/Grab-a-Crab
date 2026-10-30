--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local EggConveyorServiceServer = require(ServerScriptService.Features.EggConveyor.EggConveyorServiceServer)
local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local ShopServiceServer = require(ServerScriptService.Features.Shop.ShopServiceServer)
local DecorShopServiceServer = require(ServerScriptService.Features.DecorShop.DecorShopServiceServer)
local sellStandFolder = ServerScriptService.Features:FindFirstChild("SellStand")
local sellStandModule = if sellStandFolder then sellStandFolder:FindFirstChild("SellStandServiceServer") else nil
local SellStandServiceServer = if sellStandModule then require(sellStandModule) else nil
local IndexServiceServer = require(ServerScriptService.Features.Index.IndexServiceServer)

EggConveyorServiceServer:init()
TankServiceServer:init()
PlotServiceServer:init()
IncubatorServiceServer:init()
InventoryServiceServer:init()
ShopServiceServer:init()
DecorShopServiceServer:init()
if SellStandServiceServer then
	SellStandServiceServer:init()
else
	warn("SellStand server modules have not synced to Studio yet")
end
IndexServiceServer:init()
