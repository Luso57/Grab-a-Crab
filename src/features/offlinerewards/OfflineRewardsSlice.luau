local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Offer = {
	amount: number,
	offlineSeconds: number,
	awaitingDouble: boolean,
}

local offer: Charm.Atom<Offer?> = Charm.atom(nil)
local isOpen: Charm.Atom<boolean> = Charm.atom(false)

return {
	state = {
		offer = offer,
		isOpen = isOpen,
	},
	actions = {
		show = function(nextOffer: Offer)
			offer(nextOffer)
			isOpen(true)
		end,
		hide = function()
			isOpen(false)
		end,
		clear = function()
			offer(nil)
			isOpen(false)
		end,
	},
}
