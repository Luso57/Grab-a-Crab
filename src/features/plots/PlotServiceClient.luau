local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotClient = require(ReplicatedStorage.Source.Features.Plots.Classes.PlotClient)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

local PlotServiceClient = {}

function PlotServiceClient.init(self: PlotServiceClient)
	self.plots = {}
	self.pendingSlimes = {}
	self.networker = Networker.client.new("PlotService", self)
	self.networker:fire("requestPlots")
end

function PlotServiceClient.initPlot(self: PlotServiceClient, plotData: PlotTypes.PlotData)
	local existingPlot = self.plots[plotData.index]
	if existingPlot then
		if existingPlot.plotModel == plotData.plotModel then
			if plotData.currentSlimeId then
				existingPlot:showSlime(plotData.currentSlimeId)
			end
			return
		end

		existingPlot:destroy()
	end

	local plot = PlotClient.new(plotData, self.networker)
	self.plots[plot.index] = plot

	local pendingSlimeId = self.pendingSlimes[plot.index]
	if pendingSlimeId then
		self.pendingSlimes[plot.index] = nil
		plot:showSlime(pendingSlimeId)
	end
end

function PlotServiceClient.showSlime(self: PlotServiceClient, plotIndex: number, slimeId: string)
	local plot = self.plots[plotIndex]
	if not plot then
		self.pendingSlimes[plotIndex] = slimeId
		return
	end

	plot:showSlime(slimeId)
end

function PlotServiceClient.getPlot(self: PlotServiceClient, index: number): PlotClient.PlotClient?
	return self.plots[index]
end

function PlotServiceClient.removePlot(self: PlotServiceClient, index: number)
	self.pendingSlimes[index] = nil

	local plot = self.plots[index]
	if plot then
		plot:destroy()
		self.plots[index] = nil
	end
end

type PlotServiceClient = typeof(PlotServiceClient) & {
	networker: Networker.Client,
	plots: { [number]: PlotClient.PlotClient },
	pendingSlimes: { [number]: string },
}

return PlotServiceClient :: PlotServiceClient
