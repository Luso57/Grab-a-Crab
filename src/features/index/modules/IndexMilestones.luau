--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabSizeIndex = require(ReplicatedStorage.Source.Features.Index.Modules.CrabSizeIndex)

local targets = { 5, 15, 29 }
local coinsBySize: { [string]: { number } } = {
	Base = { 500, 5000, 50000 },
	Big = { 5000, 50000, 500000 },
	Huge = { 50000, 500000, 5000000 },
	Mega = { 500000, 5000000, 50000000 },
	Jumbo = { 5000000, 50000000, 500000000 },
}

local IndexMilestones = {}
IndexMilestones.targets = targets

function IndexMilestones.key(sizeName: string, target: number): string
	return sizeName .. ":" .. tostring(target)
end

function IndexMilestones.getCoins(sizeName: string, target: number): number?
	local coins = coinsBySize[sizeName]
	if not coins then
		return nil
	end
	for index, milestone in targets do
		if milestone == target then
			return coins[index]
		end
	end
	return nil
end

function IndexMilestones.nextUnclaimed(sizeName: string, claimed: { [string]: boolean }): number?
	if not coinsBySize[sizeName] then
		return nil
	end
	for _, target in targets do
		if claimed[IndexMilestones.key(sizeName, target)] ~= true then
			return target
		end
	end
	return nil
end

function IndexMilestones.growthLuck(claimed: { [string]: boolean }): number
	local luck = 1
	for _, sizeName in CrabSizeIndex.names do
		for _, target in targets do
			if claimed[IndexMilestones.key(sizeName, target)] == true then
				luck += 1
			end
		end
	end
	return luck
end

function IndexMilestones.isKnown(crabId: string, sizeName: string, discovered: { [string]: boolean }, discoveredBySize: { [string]: boolean }): boolean
	if discoveredBySize[CrabSizeIndex.key(sizeName, crabId)] == true then
		return true
	end
	if sizeName ~= "Base" or discovered[crabId] ~= true then
		return false
	end
	-- Legacy discoveries without a saved weight belong to Base only if no size is known.
	for _, name in CrabSizeIndex.names do
		if discoveredBySize[CrabSizeIndex.key(name, crabId)] == true then
			return false
		end
	end
	return true
end

function IndexMilestones.countDiscovered(sizeName: string, discovered: { [string]: boolean }, discoveredBySize: { [string]: boolean }): number
	if not coinsBySize[sizeName] then
		return 0
	end
	local count = 0
	for _, crabId in Crabs.getOrderedIds() do
		if IndexMilestones.isKnown(crabId, sizeName, discovered, discoveredBySize) then
			count += 1
		end
	end
	return count
end

return IndexMilestones
