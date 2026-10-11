--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopServiceClient = require(ReplicatedStorage.Source.Features.Shop.ShopServiceClient)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local EggConveyorServiceClient = require(ReplicatedStorage.Source.Features.EggConveyor.EggConveyorServiceClient)
local TankServiceClient = require(ReplicatedStorage.Source.Features.Tanks.TankServiceClient)
local IncubatorServiceClient = require(ReplicatedStorage.Source.Features.Incubators.IncubatorServiceClient)
local InventoryServiceClient = require(ReplicatedStorage.Source.Features.Inventory.InventoryServiceClient)
local MoneyServiceClient = require(ReplicatedStorage.Source.Features.Money.MoneyServiceClient)

ShopServiceClient:init()
PlotServiceClient:init()
EggConveyorServiceClient:init()
TankServiceClient:init()
IncubatorServiceClient:init()
InventoryServiceClient:init()
MoneyServiceClient:init()
