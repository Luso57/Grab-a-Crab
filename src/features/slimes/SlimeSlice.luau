local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type SlimeEntry = {
	adornee: Attachment,
	billboardType: "purchase" | "playpen",
	instanceId: string?,
	slimeId: string,
	storedSlime: number,
}

type Atom<T> = Charm.Atom<T>

local slimes: Atom<{ [string]: SlimeEntry }> = Charm.atom({})
local nextSlimeEntryId = 0

local actions = {
	addSlime = function(
		adornee: Attachment,
		slimeId: string,
		billboardType: "purchase" | "playpen",
		instanceId: string?,
		storedSlime: number?
	): string
		nextSlimeEntryId += 1
		local entryId = `slime-{nextSlimeEntryId}`

		slimes(function(previousSlimes)
			local nextSlimes = table.clone(previousSlimes)
			nextSlimes[entryId] = {
				adornee = adornee,
				billboardType = billboardType,
				instanceId = instanceId,
				slimeId = slimeId,
				storedSlime = storedSlime or 0,
			}

			return nextSlimes
		end)

		return entryId
	end,

	setStoredSlime = function(entryId: string, amount: number)
		if slimes()[entryId] == nil then
			return
		end

		slimes(function(previousSlimes)
			local nextSlimes = table.clone(previousSlimes)
			local nextEntry = table.clone(nextSlimes[entryId])
			nextEntry.storedSlime = amount
			nextSlimes[entryId] = nextEntry

			return nextSlimes
		end)
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
