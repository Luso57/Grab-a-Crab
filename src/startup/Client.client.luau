local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)

-- Startup calls init() once so the client service can connect the fruits.
PlotServiceClient:init()
