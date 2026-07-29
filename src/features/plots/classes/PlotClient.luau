local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local SlimeClient = require(ReplicatedStorage.Source.Features.Slimes.Classes.SlimeClient)
local SlimeRollVFX = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeRollVFX)

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
		rollPrompt: ProximityPrompt?,
		activeRoll: SlimeRollVFX.RollHandle?,
		promptConnection: RBXScriptConnection?,
		destroyed: boolean,
	},
	PlotClient
))

function PlotClient.new(plotData: PlotTypes.PlotData): PlotClient
	local slimeSpawner = plotData.plotModel:WaitForChild("SlimeSpawner")
	local spawner = slimeSpawner:WaitForChild("Spawner")
	assert(spawner:IsA("BasePart"), "Plot SlimeSpawner.Spawner must be a BasePart")

	local self = setmetatable({
		cf = plotData.cf,
		index = plotData.index,
		player = plotData.player,
		plotModel = plotData.plotModel,
		networker = nil :: any,
		spawner = spawner,
		currentSlime = nil,
		rollPrompt = nil,
		activeRoll = nil,
		promptConnection = nil,
		destroyed = false,
	}, PlotClient)

	self.networker = Networker.client.new(`Plot{self.index}`, self)

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

	self.rollPrompt = proximityPrompt
	self.promptConnection = proximityPrompt.Triggered:Connect(function()
		self.networker:fire("rollSlime")
	end)
end

function PlotClient.slimeBought(self: PlotClient, _slimeId: string)
	if not self.currentSlime then
		return
	end

	self.currentSlime:destroy()
	self.currentSlime = nil
end

function PlotClient.playSlimeRoll(self: PlotClient, winnerId: string, animationSeed: number)
	if self.destroyed or (self.activeRoll and self.activeRoll:isActive()) then
		return
	end

	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end

	if self.rollPrompt then
		self.rollPrompt.Enabled = false
	end

	local rollHandle: SlimeRollVFX.RollHandle
	rollHandle = SlimeRollVFX.play(self.spawner, winnerId, animationSeed, function(finalRotation)
		if self.destroyed or self.activeRoll ~= rollHandle then
			return
		end

		self.activeRoll = nil
		self:showSlime(winnerId, finalRotation)

		if self.rollPrompt then
			self.rollPrompt.Enabled = true
		end
	end)

	self.activeRoll = rollHandle
end

function PlotClient.showSlime(self: PlotClient, slimeId: string, startingRotation: number?)
	if self.currentSlime then
		self.currentSlime:destroy()
	end

	local slime = SlimeClient.new({
		slimeId = slimeId,
	}, self.spawner, self.player == Players.LocalPlayer, startingRotation)

	if self.player == Players.LocalPlayer then
		slime.onBought = function()
			self.networker:fire("buySlime")
		end
	end

	self.currentSlime = slime
end

function PlotClient.destroy(self: PlotClient)
	self.destroyed = true

	if self.activeRoll then
		self.activeRoll:cancel()
		self.activeRoll = nil
	end

	if self.promptConnection then
		self.promptConnection:Disconnect()
		self.promptConnection = nil
	end

	self.rollPrompt = nil

	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end

	self.networker:destroy()
	self.plotModel:Destroy()
end

return PlotClient
