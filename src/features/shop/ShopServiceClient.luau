--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local ShopConfig = require(script.Parent.ShopConfig)
local ShopRoot = require(script.Parent.UI.ShopRoot)

local ShopServiceClient = {}
local initialized = false

local displayItems: { ShopRoot.ItemView } = {
	{ id = "Incubator", name = "Incubator", stock = 3, price = "50", imageId = assets.Incubator, imageScale = 1, imageOffsetX = 0.03 },
	{ id = "Small", name = "Small Tank", stock = 3, price = "150", imageId = assets.SmallTank,imageScale = 1, imageOffsetX = 0.03 },
	{ id = "Medium", name = "Medium Tank", stock = 2, price = "10K", imageId = assets.MediumTank, imageOffsetX = 0.01 },
	{ id = "Large", name = "Large Tank", stock = 1, price = "100K", imageId = assets.LargeTank },
}

function ShopServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local networker = Networker.client.new("ShopService", ShopServiceClient)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local open = Vide.source(false)
	local refreshSeconds = Vide.source(ShopConfig.restockIntervalSeconds)
	local startedAt = os.clock()

	Vide.mount(function()
		return ShopRoot({
			items = displayItems,
			isOpen = open,
			refreshSeconds = refreshSeconds,
			onClose = function()
				open(false)
			end,
			onBuy = function(itemId: string)
				if itemId == "Incubator" then
					networker:fire("buyIncubator")
				elseif Tanks.get(itemId) then
					networker:fire("buyTank", itemId)
				end
			end,
		})
	end, playerGui)

	task.spawn(function()
		while playerGui.Parent do
			local elapsed = math.floor(os.clock() - startedAt)
			refreshSeconds(ShopConfig.restockIntervalSeconds - elapsed % ShopConfig.restockIntervalSeconds)
			task.wait(0.2)
		end
	end)

	local prompt = Workspace:WaitForChild("ShopStand"):WaitForChild("Noob"):WaitForChild("Torso"):WaitForChild("ProximityPrompt") :: ProximityPrompt
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		open(true)
	end)
end

return ShopServiceClient
