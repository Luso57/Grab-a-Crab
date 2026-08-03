local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local DataService = require(ReplicatedStorage.Source.Game.Data).server
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

local InventoryServiceServer = {}

function InventoryServiceServer.init(self: InventoryServiceServer)
	self.networker = Networker.server.new("InventoryService", self, {})
end

function InventoryServiceServer.addSlime(
	_self: InventoryServiceServer,
	player: Player,
	slimeId: string,
	amount: number
): boolean
	if not Slimes.isValidSlimeId(slimeId) or amount <= 0 or amount % 1 ~= 0 then
		return false
	end

	local playerData = DataService[player]
	if not playerData then
		return false
	end

	for _ = 1, amount do
		playerData.slimes.Insert({
			instanceId = HttpService:GenerateGUID(false),
			slimeId = slimeId,
			mutationId = "normal",
			storedSlime = 0,
		})
	end

	return true
end

type InventoryServiceServer = typeof(InventoryServiceServer) & {
	networker: Networker.Server,
}

return InventoryServiceServer :: InventoryServiceServer
