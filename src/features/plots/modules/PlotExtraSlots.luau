--!strict

local SLOT_ORDER = { "Left1", "Right1", "Left2", "Right2", "Left3", "Right3" }
local FLOOR_NAMES = { "PlotSecondFloor", "PlotThirdFloor", "PlotFourthFloor" }
local SLOTS_PER_FLOOR = #SLOT_ORDER

local PlotExtraSlots = {}

PlotExtraSlots.maxCount = #FLOOR_NAMES * SLOTS_PER_FLOOR
PlotExtraSlots.floorNames = FLOOR_NAMES

local purchaseNumbers: { [string]: number } = {}
for floorIndex = 1, #FLOOR_NAMES do
	for slotIndex, baseId in SLOT_ORDER do
		purchaseNumbers[baseId .. "_F" .. (floorIndex + 1)] = (floorIndex - 1) * SLOTS_PER_FLOOR + slotIndex
	end
end

function PlotExtraSlots.normalizeCount(value: any): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, PlotExtraSlots.maxCount)
end

function PlotExtraSlots.getPrice(purchasedCount: number): number?
	local count = PlotExtraSlots.normalizeCount(purchasedCount)
	if count >= PlotExtraSlots.maxCount then
		return nil
	end
	return math.floor(2500 * 1.966 ^ count + 0.5) * 2
end

function PlotExtraSlots.getSlotInfo(purchaseNumber: number): (number?, string?, string?)
	if purchaseNumber % 1 ~= 0 or purchaseNumber < 1 or purchaseNumber > PlotExtraSlots.maxCount then
		return nil, nil, nil
	end
	local floorNumber = math.floor((purchaseNumber - 1) / SLOTS_PER_FLOOR) + 2
	local baseId = SLOT_ORDER[(purchaseNumber - 1) % SLOTS_PER_FLOOR + 1]
	return floorNumber, baseId, baseId .. "_F" .. floorNumber
end

function PlotExtraSlots.getPurchaseNumber(slotId: string): number?
	return purchaseNumbers[slotId]
end

return PlotExtraSlots
