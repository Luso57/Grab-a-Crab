--!strict

local TankPlacement = {}

function TankPlacement.canPlace(_plotModel: Model, _tankModel: Model, _worldCFrame: CFrame): boolean
	-- Validate plot ownership, bounds, overlap, and placement limits here.
	-- Fail closed until placement is implemented.
	return false
end

return TankPlacement
