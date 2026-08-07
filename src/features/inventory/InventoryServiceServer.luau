local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local DataService = require(ReplicatedStorage.Source.Game.Data).server
local PlotLevelConfig = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelConfig)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

local SLIMES_PER_PLAYPEN = 7

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
	local plotLevel = PlotLevelConfig.getLevel(playerData.plotLevel())
	local savedSlimes = playerData.slimes()
	if #savedSlimes + amount > plotLevel * SLIMES_PER_PLAYPEN then
		return false
	end

	local floorCounts = {}
	for _, slimeData in savedSlimes do
		local level = PlotLevelConfig.getLevel(slimeData.playpenLevel)
		floorCounts[level] = (floorCounts[level] or 0) + 1
	end

	for _ = 1, amount do
		local playpenLevel = PlotLevelConfig.StartingLevel
		for level = PlotLevelConfig.StartingLevel, plotLevel do
			if (floorCounts[level] or 0) < SLIMES_PER_PLAYPEN then
				playpenLevel = level
				break
			end
		end
		floorCounts[playpenLevel] = (floorCounts[playpenLevel] or 0) + 1

		playerData.slimes.Insert({
			instanceId = HttpService:GenerateGUID(false),
			slimeId = slimeId,
			mutationId = "normal",
			storedSlime = 0,
			level = 1,
			upgradeInvestment = 0,
			playpenLevel = playpenLevel,
		})
	end

	return true
end

type InventoryServiceServer = typeof(InventoryServiceServer) & {
	networker: Networker.Server,
}

return InventoryServiceServer :: InventoryServiceServer
