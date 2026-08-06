local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type DepositEntry = {
	adornee: Attachment,
}

export type CashCollectorEntry = {
	adornee: Attachment,
	plotModel: Model,
}

export type SlimeSignEntry = {
	display: BasePart,
	plotModel: Model,
}

export type UpgradePadEntry = {
	adornee: Attachment,
	plotModel: Model,
}

type Atom<T> = Charm.Atom<T>

local deposits: Atom<{ [string]: DepositEntry }> = Charm.atom({})
local cashCollectors: Atom<{ [string]: CashCollectorEntry }> = Charm.atom({})
local slimeSigns: Atom<{ [string]: SlimeSignEntry }> = Charm.atom({})
local upgradePads: Atom<{ [string]: UpgradePadEntry }> = Charm.atom({})
local nextDepositEntryId = 0
local nextCashCollectorEntryId = 0
local nextSlimeSignEntryId = 0
local nextUpgradePadEntryId = 0

local actions = {
	addDeposit = function(adornee: Attachment): string
		nextDepositEntryId += 1
		local entryId = `deposit-{nextDepositEntryId}`

		deposits(function(previousDeposits)
			local nextDeposits = table.clone(previousDeposits)
			nextDeposits[entryId] = {
				adornee = adornee,
			}

			return nextDeposits
		end)

		return entryId
	end,

	removeDeposit = function(entryId: string)
		if deposits()[entryId] == nil then
			return
		end

		deposits(function(previousDeposits)
			local nextDeposits = table.clone(previousDeposits)
			nextDeposits[entryId] = nil

			return nextDeposits
		end)
	end,

	addCashCollector = function(adornee: Attachment, plotModel: Model): string
		nextCashCollectorEntryId += 1
		local entryId = `cash-collector-{nextCashCollectorEntryId}`

		cashCollectors(function(previousCashCollectors)
			local nextCashCollectors = table.clone(previousCashCollectors)
			nextCashCollectors[entryId] = {
				adornee = adornee,
				plotModel = plotModel,
			}

			return nextCashCollectors
		end)

		return entryId
	end,

	removeCashCollector = function(entryId: string)
		if cashCollectors()[entryId] == nil then
			return
		end

		cashCollectors(function(previousCashCollectors)
			local nextCashCollectors = table.clone(previousCashCollectors)
			nextCashCollectors[entryId] = nil

			return nextCashCollectors
		end)
	end,

	addSlimeSign = function(display: BasePart, plotModel: Model): string
		nextSlimeSignEntryId += 1
		local entryId = `slime-sign-{nextSlimeSignEntryId}`

		slimeSigns(function(previousSlimeSigns)
			local nextSlimeSigns = table.clone(previousSlimeSigns)
			nextSlimeSigns[entryId] = {
				display = display,
				plotModel = plotModel,
			}

			return nextSlimeSigns
		end)

		return entryId
	end,

	removeSlimeSign = function(entryId: string)
		if slimeSigns()[entryId] == nil then
			return
		end

		slimeSigns(function(previousSlimeSigns)
			local nextSlimeSigns = table.clone(previousSlimeSigns)
			nextSlimeSigns[entryId] = nil

			return nextSlimeSigns
		end)
	end,

	addUpgradePad = function(adornee: Attachment, plotModel: Model): string
		nextUpgradePadEntryId += 1
		local entryId = `upgrade-pad-{nextUpgradePadEntryId}`

		upgradePads(function(previousUpgradePads)
			local nextUpgradePads = table.clone(previousUpgradePads)
			nextUpgradePads[entryId] = {
				adornee = adornee,
				plotModel = plotModel,
			}

			return nextUpgradePads
		end)

		return entryId
	end,

	removeUpgradePad = function(entryId: string)
		if upgradePads()[entryId] == nil then
			return
		end

		upgradePads(function(previousUpgradePads)
			local nextUpgradePads = table.clone(previousUpgradePads)
			nextUpgradePads[entryId] = nil

			return nextUpgradePads
		end)
	end,
}

return {
	state = {
		cashCollectors = cashCollectors,
		deposits = deposits,
		slimeSigns = slimeSigns,
		upgradePads = upgradePads,
	},
	actions = actions,
}
