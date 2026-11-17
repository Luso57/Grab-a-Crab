--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local ShopConfig = require(ReplicatedStorage.Source.Features.Shop.ShopConfig)
local ShopStock = require(ReplicatedStorage.Source.Features.Shop.Modules.ShopStock)

local ShopServiceServer = {}
local initialized = false
local networker = nil
local stockByPlayer: { [Player]: ShopStock.Stock } = {}
local buying: { [Player]: boolean } = {}
local rng = Random.new()
local interval = ShopConfig.restockIntervalSeconds
local nextRefreshAt = math.floor(Workspace:GetServerTimeNow() / interval + 1) * interval

local function sendStock(player: Player, restocked: boolean?)
	local stock = stockByPlayer[player]
	if networker and stock and player.Parent == Players then
		networker:fire(player, "updateStock", table.clone(stock), nextRefreshAt, restocked == true)
	end
end

local function rollStock(player: Player, restocked: boolean?)
	stockByPlayer[player] = ShopStock.roll(ShopConfig.items, rng)
	sendStock(player, restocked)
end

local function confirmPurchase(player: Player, requestId: any, instanceId: string?)
	if not instanceId or typeof(requestId) ~= "string" or #requestId > 64
		or not networker or player.Parent ~= Players then
		return
	end
	local slotIndex = InventoryServiceServer:getHotbarSlot(player, instanceId) or 0
	networker:fire(player, "showPurchasedItem", requestId, slotIndex)
end

local function showNotEnoughMoney(player: Player, requestId: any)
	if networker and player.Parent == Players and typeof(requestId) == "string" and #requestId <= 64 then
		networker:fire(player, "showNotEnoughMoney", requestId)
	end
end

local function purchase(player: Player, itemId: string, inventoryId: string, requestId: any)
	if player.Parent ~= Players or buying[player] then
		return
	end
	local price = ShopConfig.getPrice(itemId)
	if not price then
		return
	end

	buying[player] = true
	local ok, instanceId = pcall(function()
		local data = Data.Service:waitForData(player)
		if not data or player.Parent ~= Players then
			return nil
		end
		local stock = stockByPlayer[player]
		local balance = Money.get(data, "money")
		if not stock or (stock[itemId] or 0) <= 0 then
			return nil
		end
		if Money.compare(balance, tostring(price)) < 0 then
			showNotEnoughMoney(player, requestId)
			return nil
		end

		local grantedId = InventoryServiceServer:grantItem(player, inventoryId, function()
			local currentBalance = Money.get(data, "money")
			return player.Parent == Players and stockByPlayer[player] == stock
				and (stock[itemId] or 0) > 0 and Money.compare(currentBalance, tostring(price)) >= 0
		end)
		if not grantedId then
			local currentBalance = Money.get(data, "money")
			if Money.compare(currentBalance, tostring(price)) < 0 then
				showNotEnoughMoney(player, requestId)
			elseif InventoryServiceServer:isFull(player) then
				InventoryServiceServer:showInventoryFull(player)
			end
			return nil
		end
		Money.set(data, "money", Money.subtract(Money.get(data, "money"), tostring(price)))
		stock[itemId] -= 1
		sendStock(player)
		return grantedId
	end)
	buying[player] = nil
	if not ok then
		warn(`Shop purchase failed for {player.Name}: {instanceId}`)
	elseif instanceId then
		confirmPurchase(player, requestId, instanceId)
	end
end

function ShopServiceServer:init()
	if initialized then
		return
	end
	initialized = true

	networker = Networker.server.new("ShopService", self, { self.buyTank, self.buyIncubator, self.ready })
	Players.PlayerAdded:Connect(function(player)
		rollStock(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		stockByPlayer[player] = nil
		buying[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		rollStock(player)
	end

	task.spawn(function()
		while true do
			task.wait(math.max(0, nextRefreshAt - Workspace:GetServerTimeNow()))
			nextRefreshAt += interval
			for _, player in Players:GetPlayers() do
				rollStock(player, true)
			end
		end
	end)
end

function ShopServiceServer:ready(player: Player)
	if player.Parent ~= Players then
		return
	end
	if not stockByPlayer[player] then
		rollStock(player)
	else
		sendStock(player)
	end
end

function ShopServiceServer:buyTank(player: Player, tankId: any, requestId: any)
	if typeof(tankId) ~= "string" or not Tanks.get(tankId) then
		return
	end
	purchase(player, tankId, `Tank.{tankId}`, requestId)
end

function ShopServiceServer:buyIncubator(player: Player, requestId: any)
	purchase(player, "Incubator", "Incubator", requestId)
end

function ShopServiceServer:showRobuxPurchased(player: Player, itemId: string, instanceId: string)
	if networker and player.Parent == Players then
		local slotIndex = InventoryServiceServer:getHotbarSlot(player, instanceId) or 0
		networker:fire(player, "showRobuxPurchased", itemId, slotIndex)
	end
end

return ShopServiceServer
