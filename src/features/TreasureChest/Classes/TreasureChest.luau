--[[
	TreasureChest is a small OOP class.

	The class represents ONE treasure chest in the world.
	It remembers which Model it belongs to, its reward, and whether it is open.
]]

local TreasureChest = {}
TreasureChest.__index = TreasureChest

-- Creates and returns a new TreasureChest object.
function TreasureChest.new(model, reward)
	local self = setmetatable({}, TreasureChest)

	self.Model = model
	self.Reward = reward
	self.Opened = false

	return self
end

-- Returns true when this chest has not been opened yet.
function TreasureChest:CanOpen()
	return not self.Opened
end

-- Opens the chest once. The return value tells the service whether it opened.
function TreasureChest:Open()
	if not self:CanOpen() then
		return false
	end

	self.Opened = true
	return true
end

return TreasureChest
