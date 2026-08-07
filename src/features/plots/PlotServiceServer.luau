local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlotServer = require(ServerScriptService.Features.Plots.Classes.PlotServer)
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local ServicePlayerData = require(ReplicatedStorage.Packages.ServicePlayerData)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

local PlotServiceServer = {}

type Plot = PlotServer.Plot
type PlotSpawn = PlotTypes.PlotSpawn

local PLAYER_DATA_TEMPLATE = {
	plot = nil,
}

type PlayerData = {
	plot: Plot?,
}

function PlotServiceServer.init(self: PlotServiceServer)
	self.networker = Networker.server.new("PlotService", self, {
		self.requestPlots,
	})
	self.plotSpawns = {}
	self.plots = {}

	for _, plotSpawn: BasePart in CollectionService:GetTagged("PlotSpawn") do
		local index = plotSpawn:GetAttribute("Index") :: number
		local fakePlot: Model & any = ReplicatedStorage.Assets.Misc.Plot:Clone()
		fakePlot:PivotTo(plotSpawn.CFrame)
		local fakeLevels = fakePlot:FindFirstChild("Levels")
		if fakeLevels then
			fakeLevels:Destroy()
		end
		fakePlot.Parent = workspace
		self.plotSpawns[index] = { part = plotSpawn, owner = nil, index = index, fakePlot = fakePlot }
	end

	self.playerData = ServicePlayerData.new(PLAYER_DATA_TEMPLATE :: PlayerData, self)
end

function PlotServiceServer.claimPlot(self: PlotServiceServer, player: Player): PlotSpawn?
	while player.Parent do
		for _, plotSpawn in self.plotSpawns do
			if plotSpawn.owner then
				if plotSpawn.owner == player then
					return
				end

				continue
			end

			plotSpawn.fakePlot.Parent = ServerStorage
			plotSpawn.owner = player
			return plotSpawn
		end

		task.wait(1)
	end

	return
end

function PlotServiceServer.playerAdded(self: PlotServiceServer, player: Player, playerData: PlayerData)
	local plotSpawn = self:claimPlot(player)
	if not plotSpawn then
		return
	end

	local plot = PlotServer.new(player, plotSpawn)
	playerData.plot = plot
	self.plots[plot.index] = plot

	self.networker:fireAll("initPlot", plot:get())
end

function PlotServiceServer.requestPlots(self: PlotServiceServer, player: Player)
	for _, plot in self.plots do
		self.networker:fire(player, "initPlot", plot:get())
	end
end

function PlotServiceServer.getPlayerPlot(self: PlotServiceServer, player: Player): Plot?
	local playerData = self.playerData:get(player)
	return playerData.plot
end

function PlotServiceServer.playerRemoving(self: PlotServiceServer, player: Player, playerData: PlayerData)
	for _, plotSpawn in self.plotSpawns do
		if plotSpawn.owner == player then
			plotSpawn.owner = nil
			plotSpawn.fakePlot.Parent = workspace
			break
		end
	end

	local plot = playerData.plot

	if plot then
		self.plots[plot.index] = nil
		plot:destroy()
		playerData.plot = nil
		self.networker:fireAll("removePlot", plot.index)
	end
end

type PlotServiceServer = typeof(PlotServiceServer) & {
	networker: Networker.Server,
	playerData: ServicePlayerData.ServicePlayerData<PlayerData>,
	plotSpawns: { PlotSpawn },
	plots: { [number]: Plot },
}

return PlotServiceServer :: PlotServiceServer
