local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Enemies = require(ReplicatedStorage.Source.Game.Enemies)
local EnemiesServer = require(ServerScriptService.Features.Enemies.Classes.EnemiesServer)

type EnemyObject = EnemiesServer.EnemiesServer

local EnemiesServiceServer = {}

function EnemiesServiceServer:init()
	for enemyName, enemyData in Enemies do
		local enemy: EnemyObject = EnemiesServer.new(enemyData)
		print(enemyName .. "Has been done")
	end
end

return EnemiesServiceServer
