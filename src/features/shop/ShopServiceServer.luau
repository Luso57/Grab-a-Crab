--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)

local ShopServiceServer = {}
local initialized = false

function ShopServiceServer:init()
	if initialized then
		return
	end
	initialized = true

	Networker.server.new("ShopService", self, { self.buyTank, self.buyIncubator })
end

function ShopServiceServer:buyTank(player: Player, tankId: any)
	if typeof(tankId) ~= "string" then
		return
	end

	InventoryServiceServer:grantItem(player, `Tank.{tankId}`)
end

function ShopServiceServer:buyIncubator(player: Player)
	InventoryServiceServer:grantItem(player, "Incubator")
end

return ShopServiceServer