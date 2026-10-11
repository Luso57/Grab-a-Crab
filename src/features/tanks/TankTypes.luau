--!strict

export type TankId = string

export type OwnedTank = {
	instanceId: string,
	tankId: TankId,
	-- Twelve CFrame components relative to the owner's plot when placed.
	placement: { number }?,
}

return {}
