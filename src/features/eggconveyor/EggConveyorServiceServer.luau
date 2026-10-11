--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local EggConveyorServer = require(ServerScriptService.Features.EggConveyor.Classes.EggConveyorServer)

local EggConveyorServiceServer = {}
local initialized = false
local templates: { Model } = {}
local active: { [Model]: EggConveyorServer.EggConveyorServer } = {}

function EggConveyorServiceServer:init()
	if initialized then
		return
	end
	templates = Eggs.getTemplates()
	Networker.server.new("EggConveyor", self, { self.ready })
	initialized = true
end

function EggConveyorServiceServer:start(plotModel: Model)
	if active[plotModel] then
		return
	end
	if not initialized or #templates == 0 then
		warn("Egg conveyor is unavailable: no egg templates loaded")
		return
	end
	local conveyor = EggConveyorServer.new(plotModel, templates)
	if not conveyor then
		return
	end
	active[plotModel] = conveyor
	conveyor:start()
end

function EggConveyorServiceServer:ready(player: Player)
	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	if plot and plot:getOwner() == player then
		self:start(plot.model)
	end
end
function EggConveyorServiceServer:stop(plotModel: Model)
	local conveyor = active[plotModel]
	if conveyor then
		active[plotModel] = nil
		conveyor:stop()
	end
end

return EggConveyorServiceServer
