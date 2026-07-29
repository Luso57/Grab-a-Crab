local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

local PlotModel = ReplicatedStorage.Assets.Misc.Plot

local PlotServer = {}

PlotServer.__index = PlotServer

type PlotSpawn = PlotTypes.PlotSpawn

local CHAR_SPAWN_OFFSET = CFrame.new(0, 10, 0) * CFrame.Angles(0, math.pi, 0)
local ROLL_LOCK_DURATION = 6.25

export type Plot = typeof(setmetatable(
	{} :: {
		cf: CFrame,
		index: number,
		player: Player,
		plotModel: Model,
		currentSlimeId: string?,
		networker: Networker.Server,
		activeRollSeed: number?,
		random: Random,
	},
	PlotServer
))

function PlotServer.new(player: Player, plotSpawn: PlotSpawn): Plot
	local self = setmetatable({
		player = player,
		cf = plotSpawn.part.CFrame,
		index = plotSpawn.index,
		currentSlimeId = nil,
		networker = nil :: any,
		activeRollSeed = nil,
		random = Random.new(),
	}, PlotServer)

	local plotModel = PlotModel:Clone()
	plotModel:PivotTo(plotSpawn.part.CFrame)
	plotModel.Parent = workspace
	self.plotModel = plotModel
	self.networker = Networker.server.new(`Plot{self.index}`, self, {
		self.rollSlime,
		self.buySlime,
	})

	self.charInit(self)

	return self
end

function PlotServer.get(self: Plot): PlotTypes.PlotData
	return {
		player = self.player,
		index = self.index,
		plotModel = self.plotModel,
		cf = self.cf,
		currentSlimeId = self.currentSlimeId,
	}
end

function PlotServer.charInit(self: Plot)
	local character = self.player.Character or self.player.CharacterAdded:Wait()

	character:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	self.player.CharacterAdded:Connect(function(newCharacter)
		newCharacter:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	end)
end

function PlotServer.isOwner(self: Plot, player: Player): boolean
	return self.player == player
end

function PlotServer.rollSlime(self: Plot, player: Player): boolean
	if not self:isOwner(player) or self.activeRollSeed then
		return false
	end

	local slimeId = Slimes.getRandomSlimeId()
	local animationSeed = self.random:NextInteger(1, 2_147_483_647)
	self.currentSlimeId = slimeId
	self.activeRollSeed = animationSeed

	self.networker:fireAll("playSlimeRoll", slimeId, animationSeed)

	task.delay(ROLL_LOCK_DURATION, function()
		if self.activeRollSeed == animationSeed then
			self.activeRollSeed = nil
		end
	end)

	return true
end

function PlotServer.buySlime(self: Plot, player: Player): boolean
	if not self:isOwner(player) then
		return false
	end

	local slimeId = self.currentSlimeId
	if not slimeId or not Slimes.isValidSlimeId(slimeId) then
		return false
	end

	local slimeInfo = Slimes.getSlimeInfo(slimeId)
	local cost = slimeInfo.cost
	local playerData = Data[player]
	if not playerData then
		return false
	end

	local currency = playerData.currency()

	print(`{player.Name} has {currency} currency; {slimeInfo.name} costs {cost}`)

	if currency < cost then
		return false
	end

	playerData.currency(function(value)
		return value - cost
	end)

	self.currentSlimeId = nil
	self.networker:fireAll("slimeBought", slimeId)

	return true
end

function PlotServer.destroy(self: Plot)
	self.activeRollSeed = nil
	self.networker:destroy()
	self.plotModel:Destroy()
end

return PlotServer
