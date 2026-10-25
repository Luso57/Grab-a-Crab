--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local IndexMilestones = require(ReplicatedStorage.Source.Features.Index.Modules.IndexMilestones)

local IndexServiceServer = {}
local initialized = false

function IndexServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	Networker.server.new("IndexService", self, { self.claim })
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
	local balance = data.money()
	if typeof(balance) ~= "number" or balance ~= balance or balance == math.huge or balance == -math.huge then
		return
	end
	data.claimedIndexMilestones[IndexMilestones.key(sizeName, target)](true)
	data.money(balance + coins)
end

return IndexServiceServer
