local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local Players = game:GetService("Players")

local PlotClient = {}
PlotClient.__index = PlotClient

export type PlotClient = typeof(setmetatable(
	{} :: {
		cf: CFrame,
		index: number,
		player: Player,
		plotModel: Model,
	},
	PlotClient
))

function PlotClient.new(plotData: PlotTypes.PlotData): PlotClient
	local self = setmetatable({
		cf = plotData.cf,
		index = plotData.index,
		player = plotData.player,
		plotModel = plotData.plotModel,
	}, PlotClient)

	if self.player == Players.LocalPlayer then
		self:initModel()
	end

	return self
end

function PlotClient:initModel()
	local buttonModel = self.plotModel:WaitForChild("Button") :: Model
	local spawnerButton = buttonModel:WaitForChild("SpawnerButton") :: BasePart
	local proximityPrompt = spawnerButton:WaitForChild("ProximityPrompt") :: ProximityPrompt

	proximityPrompt.Triggered:Connect(function()
		print("Spawner button triggered")
	end)
end

function PlotClient:destroy()
	self.plotModel:Destroy()
end

return PlotClient
