local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotClient = require(ReplicatedStorage.Source.Features.Plots.Classes.PlotClient)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

local PlotServiceClient = {}

function PlotServiceClient.init(self: PlotServiceClient)
	self.plots = {}
	self.networker = Networker.client.new("PlotService", self)
	self.networker:fire("requestPlots")
end

function PlotServiceClient.initPlot(self: PlotServiceClient, plotData: PlotTypes.PlotData)
	local existingPlot = self.plots[plotData.index]
	if existingPlot then
		if existingPlot.plotModel == plotData.plotModel then
			existingPlot:syncPlaypenSlimes(plotData.slimes)
			if plotData.currentSlimeId then
				existingPlot:showSlime(plotData.currentSlimeId)
			end
			return
		end

		existingPlot:destroy()
	end

	local plot = PlotClient.new(plotData)
	self.plots[plot.index] = plot
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
	local plot = self.plots[index]
	if plot then
		plot:destroy()
		self.plots[index] = nil
	end
end

type PlotServiceClient = typeof(PlotServiceClient) & {
	networker: Networker.Client,
	plots: { [number]: PlotClient.PlotClient },
}

return PlotServiceClient :: PlotServiceClient
