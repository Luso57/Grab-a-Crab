local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type BoardEntry = {
	title: BasePart,
	board: BasePart,
	plotModel: Model,
	canPurchase: boolean,
	onBuyLuckOne: (() -> ())?,
	onBuyLuckMax: (() -> ())?,
	onBuyCashOne: (() -> ())?,
	onBuyCashMax: (() -> ())?,
}

type Atom<T> = Charm.Atom<T>

local boards: Atom<{ [string]: BoardEntry }> = Charm.atom({})
local nextBoardEntryId = 0

local actions = {
	addBoard = function(
		title: BasePart,
		board: BasePart,
		plotModel: Model,
		canPurchase: boolean,
		onBuyLuckOne: (() -> ())?,
		onBuyLuckMax: (() -> ())?,
		onBuyCashOne: (() -> ())?,
		onBuyCashMax: (() -> ())?
	): string
		nextBoardEntryId += 1
		local entryId = `upgrade-board-{nextBoardEntryId}`

		boards(function(previousBoards)
			local nextBoards = table.clone(previousBoards)
			nextBoards[entryId] = {
				title = title,
				board = board,
				plotModel = plotModel,
				canPurchase = canPurchase,
				onBuyLuckOne = onBuyLuckOne,
				onBuyLuckMax = onBuyLuckMax,
				onBuyCashOne = onBuyCashOne,
				onBuyCashMax = onBuyCashMax,
			}

			return nextBoards
		end)

		return entryId
	end,

	removeBoard = function(entryId: string)
		if boards()[entryId] == nil then
			return
		end

		boards(function(previousBoards)
			local nextBoards = table.clone(previousBoards)
			nextBoards[entryId] = nil

			return nextBoards
		end)
	end,
}

return {
	state = {
		boards = boards,
	},
	actions = actions,
}
