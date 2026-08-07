local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

type Atom<T> = Charm.Atom<T>

local isOpen: Atom<boolean> = Charm.atom(false)
local searchQuery: Atom<string> = Charm.atom("")
local selectedInstanceId: Atom<string?> = Charm.atom(nil)

local actions = {
	open = function()
		isOpen(true)
	end,

	close = function()
		isOpen(false)
		selectedInstanceId(nil)
	end,

	toggle = function()
		local willOpen = not isOpen()
		if not willOpen then
			selectedInstanceId(nil)
		end
		isOpen(willOpen)
	end,

	select = function(instanceId: string)
		selectedInstanceId(instanceId)
	end,

	clearSelection = function()
		selectedInstanceId(nil)
	end,

	inspectSlime = function(instanceId: string)
		selectedInstanceId(instanceId)
		isOpen(true)
	end,

	setSearchQuery = function(query: string)
		searchQuery(query)
	end,
}

return {
	state = {
		isOpen = isOpen,
		searchQuery = searchQuery,
		selectedInstanceId = selectedInstanceId,
	},
	actions = actions,
}
