--!strict

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local CrabSizeIndex = require(ReplicatedStorage.Source.Features.Index.Modules.CrabSizeIndex)
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)

local RewardsServiceServer = {}
local initialized = false
local networker = nil
local granting: { [Player]: boolean } = {}
local announcePending: { [Player]: boolean } = {}

local function grantStarterPack(player: Player, announce: boolean)
	if announce then
		announcePending[player] = true
	end
	if granting[player] or player.Parent ~= Players then
		return
	end
	granting[player] = true
	local ok, err = pcall(function()
		local data = Data.Service:waitForData(player)
		if not data or player.Parent ~= Players or data.starterPackClaimed() then
			return
		end

		local inventory = table.clone(data.inventory())
		local crabId = HttpService:GenerateGUID(false)
		local firstTankId = HttpService:GenerateGUID(false)
		local secondTankId = HttpService:GenerateGUID(false)
		inventory[crabId] = { itemId = "Crab.BasicCrab", weightGrams = 10 }
		inventory[firstTankId] = { itemId = "Tank.Large" }
		inventory[secondTankId] = { itemId = "Tank.Large" }

		local hotbar = table.clone(data.hotbar())
		for _, instanceId in { crabId, firstTankId } do
			for slot = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
				if hotbar[slot] == InventoryConfig.emptySlot then
					hotbar[slot] = instanceId
					break
				end
			end
		end

		data.inventory(inventory)
		data.hotbar(hotbar)
		data.money(function(previous: number)
			return previous + 50000
		end)
		data.biggestCrabGrams(function(previous: number)
			return math.max(previous, 10)
		end)
		data.discoveredCrabs.BasicCrab(true)
		data.discoveredCrabSizes[CrabSizeIndex.key("Big", "BasicCrab")](true)
		data.starterPackClaimed(true)
		InventoryServiceServer:refreshTools(player)
		if announcePending[player] and networker and player.Parent == Players then
			networker:fire(player, "showStarterPackAcquired")
		end
	end)
	granting[player] = nil
	announcePending[player] = nil
	if not ok then
		warn(`Could not grant Starter Pack to {player.Name}: {err}`)
	end
end

local function checkOwnership(player: Player, announce: boolean)
	local ok, ownsPass = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, ProductIds.StarterPack)
	if not ok then
		warn(`Could not check Starter Pack ownership for {player.Name}: {ownsPass}`)
		return
	end
	if ownsPass then
		grantStarterPack(player, announce)
	end
end

function RewardsServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	networker = Networker.server.new("RewardsService", self, {})
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		if passId == ProductIds.StarterPack and wasPurchased and player.Parent == Players then
			task.spawn(checkOwnership, player, true)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkOwnership, player, false)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkOwnership, player, false)
	end
	Players.PlayerRemoving:Connect(function(player)
		granting[player] = nil
		announcePending[player] = nil
	end)
end

return RewardsServiceServer
