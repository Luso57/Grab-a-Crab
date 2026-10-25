--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local ShopServiceClient = require(ReplicatedStorage.Source.Features.Shop.ShopServiceClient)
local DecorShopServiceClient = require(ReplicatedStorage.Source.Features.DecorShop.DecorShopServiceClient)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local EggConveyorServiceClient = require(ReplicatedStorage.Source.Features.EggConveyor.EggConveyorServiceClient)
local TankServiceClient = require(ReplicatedStorage.Source.Features.Tanks.TankServiceClient)
local IncubatorServiceClient = require(ReplicatedStorage.Source.Features.Incubators.IncubatorServiceClient)
local InventoryServiceClient = require(ReplicatedStorage.Source.Features.Inventory.InventoryServiceClient)
local MoneyServiceClient = require(ReplicatedStorage.Source.Features.Money.MoneyServiceClient)
local IndexServiceClient = require(ReplicatedStorage.Source.Features.Index.IndexServiceClient)
local ShopMonoButton = require(ReplicatedStorage.Source.Features.Shopmono.UI.ShopMonoButton)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
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

ShopMonoButton.mount(playerGui)
IndexServiceClient:init()

ShopServiceClient:init()
DecorShopServiceClient:init()
PlotServiceClient:init()
EggConveyorServiceClient:init()
MoneyServiceClient:init()
TankServiceClient:init()
IncubatorServiceClient:init()
InventoryServiceClient:init()
