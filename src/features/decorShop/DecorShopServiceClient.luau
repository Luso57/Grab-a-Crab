--!strict

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local DecorConfig = require(script.Parent.DecorConfig)
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local ShopPurchaseEffect = require(ReplicatedStorage.Source.Features.Shop.UI.ShopPurchaseEffect)
local ShopRestockNotice = require(ReplicatedStorage.Source.Features.Shop.UI.ShopRestockNotice)
local ShopServiceClient = require(ReplicatedStorage.Source.Features.Shop.ShopServiceClient)
local EggConveyorServiceClient = require(ReplicatedStorage.Source.Features.EggConveyor.EggConveyorServiceClient)
local DecorShopRoot = require(script.Parent.UI.DecorShopRoot)
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local ProductPrices = require(ReplicatedStorage.Source.Features.Monotization.ProductPrices)

local DecorShopServiceClient = {}
local initialized = false
local pendingPurchases: { [string]: { imageId: number, position: Vector2 } } = {}
local pendingRobuxPurchases: { [number]: { imageId: number, position: Vector2 } } = {}
local playPurchase: ((number, Vector2, number?) -> ())? = nil
local playRobuxFeedback: ((Vector2) -> ())? = nil
local showFullNotice: (() -> ())? = nil
local stock = Vide.source({} :: { [string]: number })
local refreshAt = Vide.source(0)
local refreshSeconds = Vide.source(DecorConfig.restockIntervalSeconds)
local balance = Vide.source(0)

local robuxProductByItemId: { [string]: number } = {
	Umbrella = ProductIds.UmbrellaDecor,
	TreasureChest = ProductIds.TreasureDecor,
	Skull = ProductIds.SkullDecor,
	Seashell = ProductIds.SeashellDecor,
	Sandcastle = ProductIds.SandcastleDecor,
	PirateShip = ProductIds.PirateShipDecor,
}

local displayItems = {}
for _, item in DecorConfig.items do
	table.insert(displayItems, {
		id = item.id,
		name = item.name,
		price = item.price,
		robuxPrice = ProductPrices.load(robuxProductByItemId[item.id]),
		boostPercent = item.boostPercent,
		imageId = item.imageId,
	})
end

local function inventoryIsFull(): boolean
	local count = 0
	for _, item in Data.inventory() do
		if typeof(item) == "table" and item.itemId ~= InventoryConfig.hammerItemId then
			count += 1
		end
	end
	return count >= InventoryConfig.getCapacity(Data.inventoryCapacityPurchases())
end

function DecorShopServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local networker = Networker.client.new("DecorShopService", DecorShopServiceClient)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	playPurchase, playRobuxFeedback = ShopPurchaseEffect.mount(playerGui, "DecorShopPurchaseEffect")
	showFullNotice = ShopRestockNotice.mount(playerGui, "INVENTORY FULL!", "DecorShopFullNotice", true)

	local open = Vide.source(false)
	Data.money.Changed(function(value: number)
		balance(value)
	end)
	balance(Data.money())

	Vide.mount(function()
		return DecorShopRoot.create({
			items = displayItems,
			stock = function(itemId: string): number
				return stock()[itemId] or 0
			end,
			isOpen = open,
			refreshSeconds = refreshSeconds,
			onClose = function()
				open(false)
			end,
			onBuy = function(itemId: string, startPosition: Vector2): boolean
				local item = DecorConfig.get(itemId)
				if not item or (stock()[itemId] or 0) <= 0 then
					return false
				end
				if balance() < item.price then
					EggConveyorServiceClient:showNotEnoughMoney()
					return false
				end
				if inventoryIsFull() then
					if showFullNotice then
						showFullNotice()
					end
					return false
				end
				local requestId = HttpService:GenerateGUID(false)
				local pending = { imageId = item.imageId, position = startPosition }
				pendingPurchases[requestId] = pending
				task.delay(5, function()
					if pendingPurchases[requestId] == pending then
						pendingPurchases[requestId] = nil
					end
				end)
				networker:fire("buy", itemId, requestId)
				return true
			end,
			onRobuxBuy = function(itemId: string, startPosition: Vector2)
				local productId = robuxProductByItemId[itemId]
				local item = DecorConfig.get(itemId)
				if not productId or not item then
					return
				end
				local pending = { imageId = item.imageId, position = startPosition }
				pendingRobuxPurchases[productId] = pending
				task.delay(600, function()
					if pendingRobuxPurchases[productId] == pending then
						pendingRobuxPurchases[productId] = nil
					end
				end)
				local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, productId)
				if not ok then
					pendingRobuxPurchases[productId] = nil
					warn(`Could not open Robux purchase prompt: {err}`)
				end
			end,
		})
	end, playerGui)

	networker:fire("ready")
	local prompt = Workspace:WaitForChild("DecorStand"):WaitForChild("Noob"):WaitForChild("Torso"):WaitForChild("ProximityPrompt") :: ProximityPrompt
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

function DecorShopServiceClient:updateStock(newStock: any, deadline: any, restocked: any)
	if typeof(newStock) ~= "table" or typeof(deadline) ~= "number" then
		return
	end
	local cleanStock: { [string]: number } = {}
	for _, item in DecorConfig.items do
		local count = newStock[item.id]
		cleanStock[item.id] = if typeof(count) == "number" and count >= 0 and count == math.floor(count) then count else 0
	end
	stock(cleanStock)
	refreshAt(deadline)
	refreshSeconds(math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow())))
	if restocked == true then
		ShopServiceClient:showRestockNotice(deadline)
	end
end

function DecorShopServiceClient:showNotEnoughMoney(requestId: any)
	if typeof(requestId) == "string" then
		pendingPurchases[requestId] = nil
	end
	EggConveyorServiceClient:showNotEnoughMoney()
end

function DecorShopServiceClient:showInventoryFull(requestId: any)
	if typeof(requestId) == "string" then
		pendingPurchases[requestId] = nil
	end
	if showFullNotice then
		showFullNotice()
	end
end

function DecorShopServiceClient:showPurchasedItem(requestId: any)
	if typeof(requestId) ~= "string" then
		return
	end
	local pending = pendingPurchases[requestId]
	pendingPurchases[requestId] = nil
	if pending and playPurchase then
		playPurchase(pending.imageId, pending.position)
	end
end

function DecorShopServiceClient:showRobuxPurchased(itemId: any)
	if typeof(itemId) ~= "string" then
		return
	end
	local productId = robuxProductByItemId[itemId]
	if not productId then
		return
	end
	local pending = pendingRobuxPurchases[productId]
	if not pending then
		return
	end
	pendingRobuxPurchases[productId] = nil
	if playRobuxFeedback then
		playRobuxFeedback(pending.position)
	end
	if playPurchase then
		playPurchase(pending.imageId, pending.position)
	end
end

return DecorShopServiceClient
