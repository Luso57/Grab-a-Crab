local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)

local PlotModel = ReplicatedStorage.Assets.Misc.Plot

local PlotServer = {}

PlotServer.__index = PlotServer

type PlotSpawn = PlotTypes.PlotSpawn

local CHAR_SPAWN_OFFSET = CFrame.new(0, 10, 0) * CFrame.Angles(0, math.pi, 0)

export type Plot = typeof(setmetatable(
	{} :: {
		cf: CFrame,
		index: number,
		player: Player,
		plotModel: Model,
	},
	PlotServer
))

function PlotServer.new(player: Player, plotSpawn: PlotSpawn): Plot
	local self = setmetatable({
		player = player,
		cf = plotSpawn.part.CFrame,
		index = plotSpawn.index,
	}, PlotServer)

	local plotModel = PlotModel:Clone()
	plotModel:PivotTo(plotSpawn.part.CFrame)
	plotModel.Parent = workspace
	self.plotModel = plotModel

	self.charInit(self)

	return self
end

function PlotServer.get(self: Plot): PlotTypes.PlotData
	return {
		player = self.player,
		index = self.index,
		plotModel = self.plotModel,
		cf = self.cf,
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

function PlotServer.spawnSlime(self: Plot, player: Player)
	if not self:isOwner(player) then
		return
	end
end

function PlotServer.destroy(self: Plot)
	self.plotModel:Destroy()
end

return PlotServer
