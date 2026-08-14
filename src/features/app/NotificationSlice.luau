local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Notification = {
	id: number,
	text: string,
}

local current: Charm.Atom<Notification?> = Charm.atom(nil)
local nextId = 0
local INSUFFICIENT_MONEY_TEXT = "NOT ENOUGH MONEY!"

local function show(text: string)
	nextId += 1
	current({
		id = nextId,
		text = text,
	})
end

local NotificationSlice = {
	state = {
		current = current,
	},
	actions = {
		show = show,
		showInsufficientMoney = function()
			show(INSUFFICIENT_MONEY_TEXT)
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
