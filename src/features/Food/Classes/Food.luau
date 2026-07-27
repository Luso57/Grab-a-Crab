-- This class turns plain fruit data into Food objects with useful methods.
local Food = {}
Food.__index = Food

export type Food = typeof(setmetatable(
	{} :: {
		Name: string,
		Nutrition: number,
		SellPrice: number,
		SpeedBoost: number,
	},
	Food
))

function Food.new(foodData)
	local self = setmetatable({}, Food)

	self.Name = foodData.Name
	self.Nutrition = foodData.Nutrition
	self.SellPrice = foodData.SellPrice
	self.SpeedBoost = foodData.SpeedBoost

	return self
end

function Food:GetNutrition()
	return self.Nutrition
end

function Food:GetSpeedBoost()
	return self.SpeedBoost
end

return Food
