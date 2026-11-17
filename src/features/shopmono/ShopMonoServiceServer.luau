--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local Networker = require(ReplicatedStorage.Packages.Networker)

local ShopMonoServiceServer = {}
local initialized = false
local networker = nil
local disconnectByPlayer: { [Player]: () -> () } = {}

local function watchPlayer(player: Player)
	task.spawn(function()
		local data = Data.Service:waitForData(player)
		if not data or player.Parent ~= Players then
			return
		end

		local function recordHigh(balance: any)
			local current = Money.normalize(balance)
			local previous = Money.get(data, "maxMoney")
			if Money.compare(current, previous) > 0 then
				Money.set(data, "maxMoney", current)
			end
		end

		local disconnect = data.money.Changed(recordHigh)
		disconnectByPlayer[player] = disconnect
		recordHigh(Money.get(data, "money"))
	end)
end

function ShopMonoServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	networker = Networker.server.new("ShopMonoService", self, {})

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local disconnect = disconnectByPlayer[player]
		if disconnect then
			disconnect()
			disconnectByPlayer[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

function ShopMonoServiceServer:announceServerLuck(buyerName: string, multiplier: number)
	if not networker then
		return
	end
	for _, player in Players:GetPlayers() do
		networker:fire(player, "serverLuckBought", buyerName, multiplier)
	end
end

function ShopMonoServiceServer:showCoinsPurchased(player: Player, amount: string)
	if networker and player.Parent == Players then
		networker:fire(player, "coinsPurchased", amount)
	end
end

function ShopMonoServiceServer:showAutoCollectPurchased(player: Player)
	if networker and player.Parent == Players then
		networker:fire(player, "autoCollectPurchased")
	end
end

return ShopMonoServiceServer
