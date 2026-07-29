local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

type Atom<T> = Charm.Atom<T>

local isOpen: Atom<boolean> = Charm.atom(false)
local searchQuery: Atom<string> = Charm.atom("")

local actions = {
	open = function()
		isOpen(true)
	end,

	close = function()
		isOpen(false)
	end,

	toggle = function()
		isOpen(function(previous)
			return not previous
		end)
	end,

	setSearchQuery = function(query: string)
		searchQuery(query)
	end,
}

return {
	state = {
		isOpen = isOpen,
		searchQuery = searchQuery,
	},
	actions = actions,
}
