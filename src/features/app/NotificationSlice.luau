local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Notification = {
	id: number,
	text: string,
}

local current: Charm.Atom<Notification?> = Charm.atom(nil)
local nextId = 0

local NotificationSlice = {
	state = {
		current = current,
	},
	actions = {
		show = function(text: string)
			nextId += 1
			current({
				id = nextId,
				text = text,
			})
		end,
		clear = function(id: number?)
			local notification = current()
			if notification and (id == nil or notification.id == id) then
				current(nil)
			end
		end,
	},
}

return NotificationSlice
