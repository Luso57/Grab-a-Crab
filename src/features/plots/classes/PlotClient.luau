local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local SlimeClient = require(ReplicatedStorage.Source.Features.Slimes.Classes.SlimeClient)

local PlotClient = {}
PlotClient.__index = PlotClient

export type PlotClient = typeof(setmetatable(
	{} :: {
		cf: CFrame,
		index: number,
		player: Player,
		plotModel: Model,
		networker: Networker.Client,
		spawner: BasePart,
		currentSlime: SlimeClient.SlimeClient?,
		promptConnection: RBXScriptConnection?,
	},
	PlotClient
))

function PlotClient.new(plotData: PlotTypes.PlotData, networker: Networker.Client): PlotClient
	local slimeSpawner = plotData.plotModel:WaitForChild("SlimeSpawner")
	local spawner = slimeSpawner:WaitForChild("Spawner")
	assert(spawner:IsA("BasePart"), "Plot SlimeSpawner.Spawner must be a BasePart")

	local self = setmetatable({
		cf = plotData.cf,
		index = plotData.index,
		player = plotData.player,
		plotModel = plotData.plotModel,
		networker = networker,
		spawner = spawner,
		currentSlime = nil,
		promptConnection = nil,
	}, PlotClient)

	if self.player == Players.LocalPlayer then
		self:initModel()
	end

	if plotData.currentSlimeId then
		self:showSlime(plotData.currentSlimeId)
	end

	return self
end

function PlotClient.initModel(self: PlotClient)
	local buttonModel = self.plotModel:WaitForChild("Button")
	local spawnerButton = buttonModel:WaitForChild("SpawnerButton")
	local proximityPrompt = spawnerButton:WaitForChild("ProximityPrompt")

	assert(proximityPrompt:IsA("ProximityPrompt"), "Plot roll button is missing its ProximityPrompt")

	self.promptConnection = proximityPrompt.Triggered:Connect(function()
		self.networker:fire("rollSlime", self.index)
	end)
end

function PlotClient.showSlime(self: PlotClient, slimeId: string)
	if self.currentSlime then
		self.currentSlime:destroy()
	end

	self.currentSlime = SlimeClient.new({
		slimeId = slimeId,
	}, self.spawner, self.player == Players.LocalPlayer)
end

function PlotClient.destroy(self: PlotClient)
	if self.promptConnection then
		self.promptConnection:Disconnect()
		self.promptConnection = nil
	end

	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end

	self.plotModel:Destroy()
end

return PlotClient
