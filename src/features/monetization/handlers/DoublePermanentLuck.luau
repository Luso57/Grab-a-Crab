local grantPermanentProduct = require(script.Parent.GrantPermanentProduct)

return function(player: Player): boolean
	return grantPermanentProduct(player, "doublePermanentLuck")
end
