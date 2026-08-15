local ServerScriptService = game:GetService("ServerScriptService")

local MonetizationHandlers = require(ServerScriptService.Features.Monetization.Handlers.Registry)
local MonetizationServiceServer = require(ServerScriptService.Features.Monetization.MonetizationServiceServer)

MonetizationHandlers.registerAll(MonetizationServiceServer)
MonetizationServiceServer:init()
