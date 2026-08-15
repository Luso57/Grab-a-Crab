local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotClient = require(ReplicatedStorage.Source.Features.Plots.Classes.PlotClient)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

local PlotServiceClient = { initialized = false }

function PlotServiceClient.init(self: PlotServiceClient)
	if self.initialized then return end
	self.initialized = true
	self.plots = {}
	self.initializingPlots = {}
	self.pendingPlotData = {}
	self.plotGenerations = {}
	self.networker = Networker.client.new("PlotService", self)
	self.networker:fire("requestPlots")
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
	if plot then
		plot:destroy()
		self.plots[index] = nil
	end
end

type PlotServiceClient = typeof(PlotServiceClient) & {
	networker: Networker.Client,
	plots: { [number]: PlotClient.PlotClient },
	initializingPlots: { [number]: boolean },
	pendingPlotData: { [number]: PlotTypes.PlotData },
	plotGenerations: { [number]: number },
}

return PlotServiceClient :: PlotServiceClient
