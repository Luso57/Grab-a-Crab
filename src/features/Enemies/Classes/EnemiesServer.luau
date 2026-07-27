local EnemiesServer = {}
EnemiesServer.__index = EnemiesServer

export type EnemiesServer = typeof(setmetatable(
	{} :: {
		name: string,
		health: number,
		damage: number,
	},
	EnemiesServer
))

function EnemiesServer.new(EnemiesData)
	local self = setmetatable({}, EnemiesServer)

	self.health = EnemiesData.health
	self.damage = EnemiesData.damage
	self.name = EnemiesData.name

	return self
end

function EnemiesServer:getDamage()
	return self.damage
end

function EnemiesServer:GetHealth()
	return self.health
end

function EnemiesServer:GetName()
	return self.name
end

return EnemiesServer
