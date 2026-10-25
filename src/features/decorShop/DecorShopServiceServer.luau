--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local DecorConfig = require(ReplicatedStorage.Source.Features.DecorShop.DecorConfig)
local ShopStock = require(ReplicatedStorage.Source.Features.Shop.Modules.ShopStock)
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)

local DecorShopServiceServer = {}
local initialized = false
local networker = nil
local stockByPlayer: { [Player]: ShopStock.Stock } = {}
local buying: { [Player]: boolean } = {}
local rng = Random.new()
local interval = DecorConfig.restockIntervalSeconds
local nextRefreshAt = math.floor(Workspace:GetServerTimeNow() / interval + 1) * interval

local function sendStock(player: Player, restocked: boolean?)
	local stock = stockByPlayer[player]
	if networker and stock and player.Parent == Players then
		networker:fire(player, "updateStock", table.clone(stock), nextRefreshAt, restocked == true)
	end
end

local function rollStock(player: Player, restocked: boolean?)
	stockByPlayer[player] = ShopStock.roll(DecorConfig.items, rng)
	sendStock(player, restocked)
end

local function sendResult(player: Player, eventName: string, requestId: string)
	if networker and player.Parent == Players then
		networker:fire(player, eventName, requestId)
	end
end

function DecorShopServiceServer:init()
	if initialized then
		return
	end
	initialized = true

	networker = Networker.server.new("DecorShopService", self, { self.buy, self.ready })
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

function DecorShopServiceServer:ready(player: Player)
	if player.Parent ~= Players then
		return
	end
	if not stockByPlayer[player] then
		rollStock(player)
	else
		sendStock(player)
	end
end

function DecorShopServiceServer:buy(player: Player, itemId: any, requestId: any)
	if typeof(itemId) ~= "string" or typeof(requestId) ~= "string" or #requestId > 64
		or not DecorConfig.get(itemId) or player.Parent ~= Players or buying[player] then
		return
	end
	local item = DecorConfig.get(itemId)
	if not item then
		return
	end
	buying[player] = true
	local ok, result = pcall(function()
		local data = Data.Service:waitForData(player)
		if not data or player.Parent ~= Players then
			return nil
		end
		local stock = stockByPlayer[player]
		if not stock or (stock[itemId] or 0) <= 0 then
			return nil
		end
		local balance = data.money()
		if typeof(balance) ~= "number" or balance ~= balance or balance < item.price then
			if typeof(balance) == "number" and balance < item.price then
				sendResult(player, "showNotEnoughMoney", requestId)
			end
			return nil
		end

		local instanceId = InventoryServiceServer:grantItem(player, "Decor." .. itemId, function()
			local currentBalance = data.money()
			return player.Parent == Players and stockByPlayer[player] == stock
				and (stock[itemId] or 0) > 0 and typeof(currentBalance) == "number"
				and currentBalance >= item.price
		end)
		if not instanceId then
			local count = 0
			for _, savedItem in data.inventory() do
				if typeof(savedItem) == "table" and savedItem.itemId ~= InventoryConfig.hammerItemId then
					count += 1
				end
			end
			if count >= InventoryConfig.maxItems then
				sendResult(player, "showInventoryFull", requestId)
			end
			return nil
		end

		data.money(function(currentBalance: number)
			return currentBalance - item.price
		end)
		stock[itemId] -= 1
		sendStock(player)
		return instanceId
	end)
	buying[player] = nil
	if not ok then
		warn(`DecorShop purchase failed for {player.Name}: {result}`)
	elseif result and networker and player.Parent == Players then
		networker:fire(player, "showPurchasedItem", requestId)
	end
end

return DecorShopServiceServer
