--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local ShopConfig = require(ReplicatedStorage.Source.Features.Shop.ShopConfig)

local SellConfig = {}

-- All values are whole coins. Keep these below the corresponding purchase prices.
SellConfig.eggResaleFraction = 0.25
SellConfig.equipmentResaleFraction = 0.4
SellConfig.interactionDistance = 16

function SellConfig.getValue(itemId: string): (string?, number?)
	local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
	if eggId then
		local egg = Eggs.get(eggId)
		return if egg then "Eggs" else nil, if egg then math.max(1, math.floor(egg.price * SellConfig.eggResaleFraction)) else nil
	end
	local crabId = string.match(itemId, "^Crab%.([%w_]+)$")
	if crabId then
		return "Crabs", Crabs.sellValue(crabId)
	end
	local shopId = if itemId == "Incubator" then "Incubator" else string.match(itemId, "^Tank%.([%w_]+)$")
	if shopId then
		local price = ShopConfig.getPrice(shopId)
		return if price then "Equipment" else nil, if price then math.max(1, math.floor(price * SellConfig.equipmentResaleFraction)) else nil
	end
	return nil, nil
end

return SellConfig
