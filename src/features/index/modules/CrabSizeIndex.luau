--!strict

local CrabSizeIndex = {}

CrabSizeIndex.names = { "Base", "Big", "Huge", "Mega", "Jumbo" }
CrabSizeIndex.rangeText = {
	Base = "Under 10g",
	Big = "10g to 100g",
	Huge = "100g to 1,000g",
	Mega = "1,000g to 100,000g",
	Jumbo = "100,000g and up",
}

function CrabSizeIndex.fromWeight(weightGrams: number): string
	if weightGrams < 10 then
		return "Base"
	elseif weightGrams < 100 then
		return "Big"
	elseif weightGrams < 1000 then
		return "Huge"
	elseif weightGrams < 100000 then
		return "Mega"
	end
	return "Jumbo"
end

function CrabSizeIndex.key(sizeName: string, crabId: string): string
	return sizeName .. ":" .. crabId
end

return CrabSizeIndex
