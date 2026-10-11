--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local EggConveyorServiceServer = require(ServerScriptService.Features.EggConveyor.EggConveyorServiceServer)
local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local ShopServiceServer = require(ServerScriptService.Features.Shop.ShopServiceServer)

EggConveyorServiceServer:init()
TankServiceServer:init()
PlotServiceServer:init()
IncubatorServiceServer:init()
InventoryServiceServer:init()
ShopServiceServer:init()
