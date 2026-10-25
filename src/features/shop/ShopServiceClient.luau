--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local ShopConfig = require(script.Parent.ShopConfig)
local ShopRoot = require(script.Parent.UI.ShopRoot)
local ShopPurchaseEffect = require(script.Parent.UI.ShopPurchaseEffect)
local ShopRestockNotice = require(script.Parent.UI.ShopRestockNotice)
local EggConveyorServiceClient = require(ReplicatedStorage.Source.Features.EggConveyor.EggConveyorServiceClient)

local ShopServiceClient = {}
local initialized = false
local pendingPurchases: { [string]: { imageId: number, position: Vector2 } } = {}
local playPurchase: ((number, Vector2, number?) -> ())? = nil
local showRestockNotice: (() -> ())? = nil
local lastNotifiedRestock: number? = nil
local stock = Vide.source({ Incubator = 0, Small = 0, Medium = 0, Large = 0 } :: { [string]: number })
local refreshAt = Vide.source(0)
local refreshSeconds = Vide.source(ShopConfig.restockIntervalSeconds)
local balance = Vide.source(0)

local displayItems: { ShopRoot.ItemView } = {
	{ id = "Incubator", name = "Incubator", price = ShopConfig.getPrice("Incubator"), imageId = assets.Incubator, imageScale = 1, imageOffsetX = 0.03 },
	{ id = "Small", name = "Small Tank", price = ShopConfig.getPrice("Small"), imageId = assets.SmallTank, imageScale = 1, imageOffsetX = 0.03 },
	{ id = "Medium", name = "Medium Tank", price = ShopConfig.getPrice("Medium"), imageId = assets.MediumTank, imageOffsetX = 0.01 },
	{ id = "Large", name = "Large Tank", price = ShopConfig.getPrice("Large"), imageId = assets.LargeTank },
}

function ShopServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local networker = Networker.client.new("ShopService", ShopServiceClient)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	playPurchase = ShopPurchaseEffect.mount(playerGui)
	showRestockNotice = ShopRestockNotice.mount(playerGui, "SHOP AND DECOR HAS RESTOCKED")
	local open = Vide.source(false)
	Data.money.Changed(function(value: number)
		balance(value)
	end)
	balance(Data.money())

	Vide.mount(function()
		return ShopRoot({
			items = displayItems,
			stock = function(itemId: string)
				return stock()[itemId] or 0
			end,
			isOpen = open,
			refreshSeconds = refreshSeconds,
			onClose = function()
				open(false)
			end,
			onBuy = function(itemId: string, startPosition: Vector2)
				local price = ShopConfig.getPrice(itemId)
				if not price or (stock()[itemId] or 0) <= 0 then
					return false
				end
				if balance() < price then
					EggConveyorServiceClient:showNotEnoughMoney()
					return false
				end
				local imageId: number? = nil
				for _, item in displayItems do
					if item.id == itemId then
						imageId = item.imageId
						break
					end
				end
				if not imageId then
					return false
				end
				local requestId = HttpService:GenerateGUID(false)
				local pending = { imageId = imageId, position = startPosition }
				pendingPurchases[requestId] = pending
				task.delay(5, function()
					if pendingPurchases[requestId] == pending then
						pendingPurchases[requestId] = nil
					end
				end)
				if itemId == "Incubator" then
					networker:fire("buyIncubator", requestId)
				elseif Tanks.get(itemId) then
					networker:fire("buyTank", itemId, requestId)
				else
					pendingPurchases[requestId] = nil
					return false
				end
				return true
			end,
		})
	end, playerGui)

	networker:fire("ready")
	local prompt = Workspace:WaitForChild("ShopStand"):WaitForChild("Noob"):WaitForChild("Torso"):WaitForChild("ProximityPrompt") :: ProximityPrompt
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		open(true)
	end)
	local standPart = prompt.Parent :: BasePart
	local closeDistance = prompt.MaxActivationDistance + 4
	task.spawn(function()
		while playerGui.Parent do
			local deadline = refreshAt()
			if deadline > 0 then
				refreshSeconds(math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow())))
			end
			if open() then
				local character = Players.LocalPlayer.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if not root or not root:IsA("BasePart")
					or (root.Position - standPart.Position).Magnitude > closeDistance then
					open(false)
				end
			end
			task.wait(0.2)
		end
	end)
end

function ShopServiceClient:updateStock(newStock: any, deadline: any, restocked: any)
	if typeof(newStock) ~= "table" or typeof(deadline) ~= "number" then
		return
	end
	local cleanStock = { Incubator = 0, Small = 0, Medium = 0, Large = 0 }
	for _, item in ShopConfig.items do
		local count = newStock[item.id]
		if typeof(count) == "number" and count >= 0 and count == math.floor(count) then
			cleanStock[item.id] = count
		end
	end
	stock(cleanStock)
	refreshAt(deadline)
	refreshSeconds(math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow())))
	if restocked == true then
		self:showRestockNotice(deadline)
	end
end

function ShopServiceClient:showRestockNotice(deadline: number)
	if lastNotifiedRestock == deadline then
		return
	end
	lastNotifiedRestock = deadline
	local show = showRestockNotice
	if show then
		show()
	end
end

function ShopServiceClient:showNotEnoughMoney(requestId: any)
	if typeof(requestId) == "string" then
		pendingPurchases[requestId] = nil
	end
	EggConveyorServiceClient:showNotEnoughMoney()
end

function ShopServiceClient:showPurchasedItem(requestId: any, slotIndex: any)
	if typeof(requestId) ~= "string" then
		return
	end
	local pending = pendingPurchases[requestId]
	pendingPurchases[requestId] = nil
	if pending and playPurchase then
		playPurchase(pending.imageId, pending.position, if typeof(slotIndex) == "number" and slotIndex > 0 then slotIndex else nil)
	end
end

return ShopServiceClient
