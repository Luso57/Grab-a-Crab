local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotClient = require(ReplicatedStorage.Source.Features.Plots.Classes.PlotClient)

local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

local PlotServiceClient = {}

function PlotServiceClient.init(self: PlotServiceClient)
	self.plots = {}
	self.networker = Networker.client.new("PlotService", self)
end

function PlotServiceClient.initPlot(self: PlotServiceClient, plotData: PlotTypes.PlotData)
	local plot = PlotClient.new(plotData)
	self.plots[plot.index] = plot
end

function PlotServiceClient.getPlot(self: PlotServiceClient, index: number): PlotClient.PlotClient?
	return self.plots[index]
end

function PlotServiceClient.removePlot(self: PlotServiceClient, index: number)
	local plot = self.plots[index]

	if plot then
		plot:destroy()
	end
end

type PlotServiceClient = typeof(PlotServiceClient) & {
	networker: Networker.Client,
	plots: { [number]: PlotClient.PlotClient },
}

return PlotServiceClient :: PlotServiceClient
