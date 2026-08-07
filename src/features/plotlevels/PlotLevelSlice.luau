local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type SignEntry = {
	board: BasePart,
	plotModel: Model,
	currentLevel: number,
	canPurchase: boolean,
	onPurchase: (() -> ())?,
}

local signs: Charm.Atom<{ [string]: SignEntry }> = Charm.atom({})
local nextEntryId = 0

local PlotLevelSlice = {
	state = {
		signs = signs,
	},
	actions = {
		addSign = function(
			board: BasePart,
			plotModel: Model,
			currentLevel: number,
			canPurchase: boolean,
			onPurchase: (() -> ())?
		): string
			nextEntryId += 1
			local entryId = `plot-level-sign-{nextEntryId}`
			signs(function(previous)
				local nextSigns = table.clone(previous)
				nextSigns[entryId] = {
					board = board,
					plotModel = plotModel,
					currentLevel = currentLevel,
					canPurchase = canPurchase,
					onPurchase = onPurchase,
				}
				return nextSigns
			end)
			return entryId
		end,
		setLevel = function(entryId: string, currentLevel: number)
			signs(function(previous)
				local entry = previous[entryId]
				if entry == nil or entry.currentLevel == currentLevel then
					return previous
				end
				local nextSigns = table.clone(previous)
				nextSigns[entryId] = {
					board = entry.board,
					plotModel = entry.plotModel,
					currentLevel = currentLevel,
					canPurchase = entry.canPurchase,
					onPurchase = entry.onPurchase,
				}
				return nextSigns
			end)
		end,
		removeSign = function(entryId: string)
			signs(function(previous)
				if previous[entryId] == nil then
					return previous
				end
				local nextSigns = table.clone(previous)
				nextSigns[entryId] = nil
				return nextSigns
			end)
		end,
	},
}

return PlotLevelSlice
