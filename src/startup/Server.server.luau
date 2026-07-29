local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)

local DataService = require(ReplicatedStorage.Source.Game.Data).server

type PlayerData = typeof(DataTemplate)

function DataService.Service:onPlayerInit(_player: Player, data: PlayerData)
	data.currency = 100_000_000_000
end

PlotServiceServer:init()
