local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type SlimeEntry = {
	adornee: Attachment,
	slimeId: string,
}

type Atom<T> = Charm.Atom<T>

local slimes: Atom<{ [string]: SlimeEntry }> = Charm.atom({})
local nextSlimeEntryId = 0

local actions = {
	addSlime = function(adornee: Attachment, slimeId: string): string
		nextSlimeEntryId += 1
		local entryId = `slime-{nextSlimeEntryId}`

		slimes(function(previousSlimes)
			local nextSlimes = table.clone(previousSlimes)
			nextSlimes[entryId] = {
				adornee = adornee,
				slimeId = slimeId,
			}

			return nextSlimes
		end)

		return entryId
	end,

	removeSlime = function(entryId: string)
		if slimes()[entryId] == nil then
			return
		end

		slimes(function(previousSlimes)
			local nextSlimes = table.clone(previousSlimes)
			nextSlimes[entryId] = nil

			return nextSlimes
		end)
	end,
}

return {
	state = {
		slimes = slimes,
	},
	actions = actions,
}
