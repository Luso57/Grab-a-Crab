--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local Networker = require(ReplicatedStorage.Packages.Networker)
local IndexMilestones = require(ReplicatedStorage.Source.Features.Index.Modules.IndexMilestones)

local IndexServiceServer = {}
local initialized = false
local networker = nil

function IndexServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	networker = Networker.server.new("IndexService", self, { self.claim })
end

function IndexServiceServer:claim(player: Player, sizeName: any, target: any)
	if player.Parent ~= Players or typeof(sizeName) ~= "string" or typeof(target) ~= "number" then
		return
	end
	local coins = IndexMilestones.getCoins(sizeName, target)
	if not coins then
		return
	end
	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players then
		return
	end
	local claimed = data.claimedIndexMilestones()
	if IndexMilestones.nextUnclaimed(sizeName, claimed) ~= target then
		return
	end
	local discoveredCount = IndexMilestones.countDiscovered(sizeName, data.discoveredCrabs(), data.discoveredCrabSizes())
	if discoveredCount < target then
		return
	end
	local balance = Money.get(data, "money")
	data.claimedIndexMilestones[IndexMilestones.key(sizeName, target)](true)
	Money.set(data, "money", Money.add(balance, tostring(coins)))
	if networker and player.Parent == Players then
		networker:fire(player, "claimSucceeded", sizeName, target, IndexMilestones.growthLuck(data.claimedIndexMilestones(), data.starterPackClaimed()))
	end
end

return IndexServiceServer
