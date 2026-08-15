local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotClient = require(ReplicatedStorage.Source.Features.Plots.Classes.PlotClient)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

export type PlotOwnerEntry = {
	adornee: Attachment,
	playerName: string,
	userId: number,
}

type Atom<T> = Charm.Atom<T>

local plotOwners: Atom<{ [number]: PlotOwnerEntry }> = Charm.atom({})

local PlotServiceClient = {
	initialized = false,
	state = {
		plotOwners = plotOwners,
	},
}

function PlotServiceClient.init(self: PlotServiceClient)
	if self.initialized then return end
	self.initialized = true
	self.plots = {}
	self.plotOwnerAttachments = {}
	self.initializingPlots = {}
	self.pendingPlotData = {}
	self.plotGenerations = {}
	self.networker = Networker.client.new("PlotService", self)
	self.networker:fire("requestPlots")
end

function PlotServiceClient.removePlotOwner(self: PlotServiceClient, index: number)
	local attachment = self.plotOwnerAttachments[index]
	self.plotOwnerAttachments[index] = nil
	if attachment then attachment:Destroy() end
	if plotOwners()[index] == nil then return end

	plotOwners(function(previousOwners)
		local nextOwners = table.clone(previousOwners)
		nextOwners[index] = nil
		return nextOwners
	end)
end

function PlotServiceClient.registerPlotOwner(self: PlotServiceClient, plotData: PlotTypes.PlotData)
	local existingEntry = plotOwners()[plotData.index]
	if existingEntry
		and existingEntry.adornee.Parent
		and existingEntry.userId == plotData.player.UserId
		and existingEntry.playerName == plotData.player.Name
	then
		return
	end

	self:removePlotOwner(plotData.index)
	local plotOrigin = plotData.plotModel:WaitForChild("PlotOrigin")
	assert(plotOrigin:IsA("BasePart"), "Plot PlotOrigin must be a BasePart")

	local attachment = Instance.new("Attachment")
	attachment.Name = "PlotOwnerBillboardAttachment"
	attachment.Position = plotOrigin.CFrame:PointToObjectSpace(plotOrigin.Position + Vector3.new(0, 90, 0))
	attachment.Parent = plotOrigin
	self.plotOwnerAttachments[plotData.index] = attachment

	plotOwners(function(previousOwners)
		local nextOwners = table.clone(previousOwners)
		nextOwners[plotData.index] = {
			adornee = attachment,
			playerName = plotData.player.Name,
			userId = plotData.player.UserId,
		}
		return nextOwners
	end)
end

function PlotServiceClient.initPlot(self: PlotServiceClient, plotData: PlotTypes.PlotData)
	local index = plotData.index
	if self.initializingPlots[index] then
		self.pendingPlotData[index] = plotData
		return
	end

	self.initializingPlots[index] = true
	local generation = self.plotGenerations[index] or 0
	local success, result = xpcall(function()
		local existingPlot = self.plots[index]
		if existingPlot and existingPlot.plotModel == plotData.plotModel then
			self:registerPlotOwner(plotData)
			existingPlot:syncPlaypenSlimes(plotData.slimes)
			existingPlot:setPlotLevel(plotData.plotLevel)
			existingPlot:syncOffers(
				plotData.currentSlimeId,
				plotData.currentMutationId,
				plotData.secondarySlimeId,
				plotData.secondaryMutationId
			)
			return existingPlot
		end

		if existingPlot then
			self:removePlotOwner(index)
			existingPlot:destroy()
			self.plots[index] = nil
		end
		return PlotClient.new(plotData)
	end, debug.traceback)

	if success then
		local plot = result :: PlotClient.PlotClient
		if self.plotGenerations[index] == nil then
			self.plotGenerations[index] = generation
		end
		if self.plotGenerations[index] ~= generation then
			if plot ~= self.plots[index] then plot:destroy() end
		elseif self.plots[index] ~= plot then
			self.plots[index] = plot
			self:registerPlotOwner(plotData)
		end
	else
		warn(`Failed to initialize plot {index}: {result}`)
	end

	self.initializingPlots[index] = nil
	local pending = self.pendingPlotData[index]
	self.pendingPlotData[index] = nil
	if pending then
		self:initPlot(pending)
	end
end

function PlotServiceClient.getPlot(self: PlotServiceClient, index: number): PlotClient.PlotClient?
	return self.plots[index]
end

function PlotServiceClient.getLocalPlayerPlot(self: PlotServiceClient): PlotClient.PlotClient?
	for _, plot in self.plots do
		if plot.player == Players.LocalPlayer then
			return plot
		end
	end

	return nil
end

function PlotServiceClient.removePlot(self: PlotServiceClient, index: number)
	self.plotGenerations[index] = (self.plotGenerations[index] or 0) + 1
	self.pendingPlotData[index] = nil
	local plot = self.plots[index]
	self:removePlotOwner(index)
	if plot then
		plot:destroy()
		self.plots[index] = nil
	end
end

type PlotServiceClient = typeof(PlotServiceClient) & {
	networker: Networker.Client,
	plots: { [number]: PlotClient.PlotClient },
	plotOwnerAttachments: { [number]: Attachment },
	initializingPlots: { [number]: boolean },
	pendingPlotData: { [number]: PlotTypes.PlotData },
	plotGenerations: { [number]: number },
}

return PlotServiceClient :: PlotServiceClient
