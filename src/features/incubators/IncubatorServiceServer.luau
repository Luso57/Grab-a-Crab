--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)

local IncubatorServer = require(script.Parent.Classes.IncubatorServer)
local PlacedIncubatorServer = require(script.Parent.Classes.PlacedIncubatorServer)
local Incubators = require(ReplicatedStorage.Source.Features.Incubators.Modules.Incubators)

local IncubatorServiceServer = {}
local initialized = false
local networker = nil
local ownedIncubators: { [Player]: { [string]: IncubatorServer.IncubatorServer } } = {}
local placedIncubators: { [Model]: PlacedIncubatorServer.PlacedIncubatorServer } = {}

local function playerRemoving(player: Player)
	local playerIncubators = ownedIncubators[player]
	ownedIncubators[player] = nil
	if playerIncubators then
		local held = {}
		for _, incubator in playerIncubators do
			table.insert(held, incubator)
		end
		for _, incubator in held do
			incubator:destroy()
		end
	end
	local toRemove = {}
	for model, incubator in placedIncubators do
		if incubator.owner == player then
			table.insert(toRemove, model)
		end
	end
	for _, model in toRemove do
		placedIncubators[model]:destroy()
		placedIncubators[model] = nil
	end
end

function IncubatorServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	networker = Networker.server.new("IncubatorService", self)
	Players.PlayerRemoving:Connect(playerRemoving)
end

function IncubatorServiceServer:showHatch(
	player: Player,
	crabId: string,
	weightGrams: number,
	eggId: string?,
	eggPivot: CFrame?,
	eggScale: number?,
	viewDirection: Vector3?,
	instanceId: string
)
	if networker and player.Parent == Players then
		networker:fire(player, "showHatch", crabId, weightGrams, eggId, eggPivot, eggScale, viewDirection, instanceId)
	end
end

function IncubatorServiceServer:createTool(player: Player, incubatorId: string, instanceId: string): Tool?
	local definition = Incubators.get(incubatorId)
	if not definition or player.Parent ~= Players then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local templates = if assets then assets:FindFirstChild("Incubators") else nil
	local modelTemplate = if templates then templates:FindFirstChild(definition.modelName) else nil
	if not modelTemplate or not modelTemplate:IsA("Model") or not modelTemplate.PrimaryPart then
		warn("Missing incubator model template:", definition.modelName)
		return nil
	end
	local incubator = IncubatorServer.new(player, instanceId, incubatorId, definition.name, modelTemplate)
	if not incubator then
		return nil
	end
	local playerIncubators = ownedIncubators[player]
	if not playerIncubators then
		playerIncubators = {}
		ownedIncubators[player] = playerIncubators
	end
	playerIncubators[incubator.instanceId] = incubator
	incubator.tool.Destroying:Connect(function()
		playerIncubators[incubator.instanceId] = nil
	end)
	return incubator.tool
end

function IncubatorServiceServer:getIncubator(player: Player, instanceId: string): IncubatorServer.IncubatorServer?
	local playerIncubators = ownedIncubators[player]
	return if playerIncubators then playerIncubators[instanceId] else nil
end

function IncubatorServiceServer:registerPlaced(owner: Player, plotModel: Model, model: Model, instanceId: string): boolean
	if placedIncubators[model] then
		return false
	end
	local incubator = PlacedIncubatorServer.new(owner, plotModel, model, instanceId)
	if not incubator then
		return false
	end
	placedIncubators[model] = incubator
	incubator:restore()
	return true
end

function IncubatorServiceServer:unregisterPlaced(model: Model)
	local incubator = placedIncubators[model]
	if incubator then
		placedIncubators[model] = nil
		incubator:destroy()
	end
end

function IncubatorServiceServer:isOccupied(model: Model): boolean
	local incubator = placedIncubators[model]
	return incubator ~= nil and incubator.eggInstanceId ~= nil
end

function IncubatorServiceServer:getPlacedEggId(model: Model): string?
	local incubator = placedIncubators[model]
	return if incubator then incubator.eggInstanceId else nil
end

function IncubatorServiceServer:clearPlacedForPlayer(player: Player)
	local toRemove = {}
	for model, incubator in placedIncubators do
		if incubator.owner == player then
			table.insert(toRemove, model)
		end
	end
	for _, model in toRemove do
		self:unregisterPlaced(model)
	end
end

return IncubatorServiceServer
