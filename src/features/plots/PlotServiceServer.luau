local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local PlotServer = require(ServerScriptService.Features.Plots.Classes.PlotServer)
local Networker = require(ReplicatedStorage.Packages.Networker)
local ServicePlayerData = require(ReplicatedStorage.Packages.ServicePlayerData)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

local PlotServiceServer = {}
local EXPECTED_PLOT_COUNT = 6
local ASSIGNMENT_LOG_PREFIX = "[PlotAssignment]"

type Plot = PlotServer.Plot
type PlotSpawn = PlotTypes.PlotSpawn
type PlayerData = { plot: Plot? }
type AssignmentToken = { cancelled: boolean }

local PLAYER_DATA_TEMPLATE = { plot = nil }

local function isValidPlotIndex(index: any): boolean
	return type(index) == "number" and index % 1 == 0 and index >= 1 and index <= EXPECTED_PLOT_COUNT
end

function PlotServiceServer.init(self: PlotServiceServer)
	self.networker = Networker.server.new("PlotService", self, { self.requestPlots })
	self.plotSpawns = {}
	self.plots = {}
	self.assignmentTokens = {}

	local taggedSpawns = CollectionService:GetTagged("PlotSpawn")
	assert(#taggedSpawns == EXPECTED_PLOT_COUNT, `{ASSIGNMENT_LOG_PREFIX} Expected {EXPECTED_PLOT_COUNT} tagged PlotSpawns, found {#taggedSpawns}`)

	for _, instance in taggedSpawns do
		assert(instance:IsA("BasePart"), `{ASSIGNMENT_LOG_PREFIX} {instance:GetFullName()} must be a BasePart`)
		local index = instance:GetAttribute("Index")
		assert(isValidPlotIndex(index), `{ASSIGNMENT_LOG_PREFIX} {instance:GetFullName()} must have an integer Index from 1 to {EXPECTED_PLOT_COUNT}`)
		assert(self.plotSpawns[index] == nil, `{ASSIGNMENT_LOG_PREFIX} Duplicate PlotSpawn Index {index}`)

		local plotSpawn = instance :: BasePart
		local fakePlot: Model & any = ReplicatedStorage.Assets.Misc.Plot:Clone()
		fakePlot:PivotTo(plotSpawn.CFrame)
		local fakeLevels = fakePlot:FindFirstChild("Levels")
		if fakeLevels then fakeLevels:Destroy() end
		fakePlot.Parent = workspace
		self.plotSpawns[index] = { part = plotSpawn, owner = nil, index = index, fakePlot = fakePlot }
	end
	for index = 1, EXPECTED_PLOT_COUNT do
		assert(self.plotSpawns[index] ~= nil, `{ASSIGNMENT_LOG_PREFIX} Missing PlotSpawn Index {index}`)
	end

	self.playerData = ServicePlayerData.new(PLAYER_DATA_TEMPLATE :: PlayerData, self)
end

function PlotServiceServer.isAssignmentCurrent(self: PlotServiceServer, player: Player, token: AssignmentToken): boolean
	return player.Parent == Players and not token.cancelled and self.assignmentTokens[player] == token
end

function PlotServiceServer.releaseSpawn(_self: PlotServiceServer, plotSpawn: PlotSpawn, player: Player)
	if plotSpawn.owner == player then
		plotSpawn.owner = nil
		plotSpawn.fakePlot.Parent = workspace
	end
end

function PlotServiceServer.claimPlot(self: PlotServiceServer, player: Player, token: AssignmentToken): PlotSpawn?
	while self:isAssignmentCurrent(player, token) do
		for index = 1, EXPECTED_PLOT_COUNT do
			local plotSpawn = self.plotSpawns[index]
			if plotSpawn.owner then
				if plotSpawn.owner == player then return plotSpawn end
				continue
			end
			plotSpawn.fakePlot.Parent = ServerStorage
			plotSpawn.owner = player
			return plotSpawn
		end
		task.wait(1)
	end
	return nil
end

function PlotServiceServer.assertAssignmentInvariants(self: PlotServiceServer)
	if not RunService:IsStudio() then return end
	local seenOwners = {}
	for index = 1, EXPECTED_PLOT_COUNT do
		local plotSpawn = self.plotSpawns[index]
		local plot = self.plots[index]
		if plotSpawn.owner then
			assert(not seenOwners[plotSpawn.owner], `{ASSIGNMENT_LOG_PREFIX} Player owns multiple plot spawns`)
			seenOwners[plotSpawn.owner] = true
			assert(plot ~= nil, `{ASSIGNMENT_LOG_PREFIX} PlotSpawn {index} has an owner but no active plot`)
		end
		if plot then
			assert(plot.index == index, `{ASSIGNMENT_LOG_PREFIX} Plot registry index mismatch at {index}`)
			assert(plotSpawn.owner == plot.player, `{ASSIGNMENT_LOG_PREFIX} Plot {index} owner mismatch`)
		end
	end
end

function PlotServiceServer.playerAdded(self: PlotServiceServer, player: Player, playerData: PlayerData)
	if playerData.plot then return end
	local existingToken = self.assignmentTokens[player]
	if existingToken and not existingToken.cancelled then return end

	local token: AssignmentToken = { cancelled = false }
	self.assignmentTokens[player] = token
	while self:isAssignmentCurrent(player, token) and Data[player] == nil do task.wait() end
	if not self:isAssignmentCurrent(player, token) then return end

	local plotSpawn = self:claimPlot(player, token)
	if not plotSpawn then return end

	local success, plotOrError = xpcall(function()
		return PlotServer.new(player, plotSpawn)
	end, debug.traceback)
	if not success then
		self:releaseSpawn(plotSpawn, player)
		if self.assignmentTokens[player] == token then self.assignmentTokens[player] = nil end
		warn(`{ASSIGNMENT_LOG_PREFIX} Failed to create plot {plotSpawn.index} for {player.Name}: {plotOrError}`)
		if player.Parent == Players then player:Kick("Your plot could not be loaded safely. Please rejoin.") end
		return
	end

	local plot = plotOrError :: Plot
	if not self:isAssignmentCurrent(player, token) then
		plot:destroy()
		self:releaseSpawn(plotSpawn, player)
		return
	end

	playerData.plot = plot
	self.plots[plot.index] = plot
	self.assignmentTokens[player] = nil
	self.networker:fireAll("initPlot", plot:get())
	self:assertAssignmentInvariants()
	task.spawn(function() plot:loadPaidRandomItemsPolicy() end)
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
	local token = self.assignmentTokens[player]
	if token then
		token.cancelled = true
		self.assignmentTokens[player] = nil
	end

	local plot = playerData.plot
	if plot then
		self.plots[plot.index] = nil
		local success, destroyError = xpcall(function() plot:destroy() end, debug.traceback)
		if not success then
			warn(`{ASSIGNMENT_LOG_PREFIX} Failed to destroy plot {plot.index} for {player.Name}: {destroyError}`)
		end
		playerData.plot = nil
		self.networker:fireAll("removePlot", plot.index)
	end

	for index = 1, EXPECTED_PLOT_COUNT do
		local plotSpawn = self.plotSpawns[index]
		if plotSpawn.owner == player then
			self:releaseSpawn(plotSpawn, player)
			break
		end
	end
	self:assertAssignmentInvariants()
end

type PlotServiceServer = typeof(PlotServiceServer) & {
	networker: Networker.Server,
	playerData: ServicePlayerData.ServicePlayerData<PlayerData>,
	plotSpawns: { PlotSpawn },
	plots: { [number]: Plot },
	assignmentTokens: { [Player]: AssignmentToken },
}

return PlotServiceServer :: PlotServiceServer
