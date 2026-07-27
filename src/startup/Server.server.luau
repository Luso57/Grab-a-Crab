local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)

PlotServiceServer:init()
