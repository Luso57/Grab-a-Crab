--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).server

local IncubatorServer = require(script.Parent.Classes.IncubatorServer)
local PlacedIncubatorServer = require(script.Parent.Classes.PlacedIncubatorServer)
local Incubators = require(ReplicatedStorage.Source.Features.Incubators.Modules.Incubators)
local HttpService = game:GetService("HttpService")

local IncubatorServiceServer = {}
local initialized = false
local networker = nil
local ownedIncubators: { [Player]: { [string]: IncubatorServer.IncubatorServer } } = {}
local placedIncubators: { [Model]: PlacedIncubatorServer.PlacedIncubatorServer } = {}
local hatchScenes: { [Player]: { instanceId: string, crabId: string, eggId: string?, eggPivot: CFrame?, eggScale: number?, viewDirection: Vector3? } } = {}

local function playerRemoving(player: Player)
	hatchScenes[player] = nil
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
	networker = Networker.server.new("IncubatorService", self, { self.prepareRollAgain, self.cancelRollAgain, self.prepareHatchNow, self.cancelHatchNow })
	Players.PlayerRemoving:Connect(playerRemoving)
end

function IncubatorServiceServer:prepareHatchNow(player: Player, incubatorInstanceId: any, eggInstanceId: any, hatchAtUnixMs: any)
	local incubator = if typeof(incubatorInstanceId) == "string" then self:getPlacedByInstanceId(player, incubatorInstanceId) else nil
	if not incubator or typeof(eggInstanceId) ~= "string" or typeof(hatchAtUnixMs) ~= "number"
		or not incubator:canStartHatchNow(player, eggInstanceId, hatchAtUnixMs) then return end
	local data = Data[player]
	if not data then return end
	local token = HttpService:GenerateGUID(false)
	local intent = { incubatorInstanceId = incubatorInstanceId, eggInstanceId = eggInstanceId, hatchAtUnixMs = hatchAtUnixMs, intentToken = token }
	data.pendingHatchNowPurchase(intent)
	incubator:setHatchNowPending(true)
	local profile = Data.Service:getProfile(player)
	if not profile or not profile:IsActive() then
		self:cancelHatchNow(player, token)
		return
	end
	local deadline = os.clock() + 15
	while profile:IsActive() and player.Parent == Players and os.clock() < deadline do
		local saved = profile.LastSavedData.pendingHatchNowPurchase
		if saved and saved.intentToken == token then
			if networker then networker:fire(player, "hatchNowReady", incubatorInstanceId, eggInstanceId, token) end
			return
		end
		profile:Save()
		task.wait(1)
	end
	self:cancelHatchNow(player, token)
end

function IncubatorServiceServer:cancelHatchNow(player: Player, token: any)
	local data = Data[player]
	local pending = if data then data.pendingHatchNowPurchase() else nil
	if typeof(token) ~= "string" or not pending or pending.intentToken ~= token then return end
	data.pendingHatchNowPurchase({ incubatorInstanceId = "", eggInstanceId = "", hatchAtUnixMs = 0, intentToken = "" })
	local incubator = self:getPlacedByInstanceId(player, pending.incubatorInstanceId)
	if incubator then incubator:setHatchNowPending(false) end
end

function IncubatorServiceServer:getPlacedByInstanceId(player: Player, instanceId: string)
	for _, incubator in placedIncubators do
		if incubator.owner == player and incubator.instanceId == instanceId then return incubator end
	end
	return nil
end

function IncubatorServiceServer:grantHatchNowReceipt(player: Player, purchaseId: string): (string?, string?, number?, string?, CFrame?, number?, Vector3?, string?)
	local data = Data[player]
	if not data then return nil end
	local receipt = data.processedProductReceipts()[purchaseId]
	if receipt then return nil end
	local pending = data.pendingHatchNowPurchase()
	if not pending or pending.intentToken == "" then return nil end
	local incubator = self:getPlacedByInstanceId(player, pending.incubatorInstanceId)
	if not incubator or not incubator:canCompleteHatchNow(pending.eggInstanceId, pending.hatchAtUnixMs) then return nil end
	local crabId, weight, eggId, pivot, scale, direction = incubator:completeHatchNow()
	if not crabId or not weight then return nil end
	data.processedProductReceipts[purchaseId](`HatchNow:{pending.eggInstanceId}`)
	data.pendingHatchNowPurchase({ incubatorInstanceId = "", eggInstanceId = "", hatchAtUnixMs = 0, intentToken = "" })
	return pending.eggInstanceId, crabId, weight, eggId, pivot, scale, direction, `HatchNow:{pending.eggInstanceId}`
end

function IncubatorServiceServer:showHatch(
	player: Player,
	crabId: string,
	weightGrams: number,
	eggId: string?,
	eggPivot: CFrame?,
	eggScale: number?,
	viewDirection: Vector3?,
	instanceId: string,
	isRollAgain: boolean?
)
	if networker and player.Parent == Players then
		hatchScenes[player] = { instanceId = instanceId, crabId = crabId, eggId = eggId, eggPivot = eggPivot, eggScale = eggScale, viewDirection = viewDirection }
		networker:fire(player, "showHatch", crabId, weightGrams, eggId, eggPivot, eggScale, viewDirection, instanceId, isRollAgain)
	end
end

function IncubatorServiceServer:prepareRollAgain(player: Player, instanceId: any)
	local scene = hatchScenes[player]
	if typeof(instanceId) ~= "string" or not scene or scene.instanceId ~= instanceId or player.Parent ~= Players then
		return
	end
	local data = Data[player]
	local profile = Data.Service:getProfile(player)
	local item = if data then data.inventory()[instanceId] else nil
	if not data or not profile or not profile:IsActive()
		or typeof(item) ~= "table" or item.itemId ~= "Crab." .. scene.crabId then
		return
	end
	data.pendingRollAgainInstanceId(instanceId)
	local deadline = os.clock() + 15
	while profile:IsActive() and player.Parent == Players and os.clock() < deadline do
		local savedData = profile.LastSavedData
		if savedData and savedData.pendingRollAgainInstanceId == instanceId then
			networker:fire(player, "rollAgainReady", instanceId)
			return
		end
		profile:Save()
		task.wait(1)
	end
	if player.Parent == Players then
		networker:fire(player, "rollAgainUnavailable", instanceId)
	end
end

function IncubatorServiceServer:cancelRollAgain(player: Player, instanceId: any)
	local data = Data[player]
	if typeof(instanceId) == "string" and data and data.pendingRollAgainInstanceId() == instanceId then
		data.pendingRollAgainInstanceId("")
	end
end

function IncubatorServiceServer:showRollAgain(player: Player, instanceId: string, crabId: string, weightGrams: number)
	local scene = hatchScenes[player]
	if scene and scene.instanceId == instanceId and scene.crabId == crabId then
		self:showHatch(player, crabId, weightGrams, scene.eggId, scene.eggPivot, scene.eggScale, scene.viewDirection, instanceId, true)
		return
	end
	local data = Data[player]
	local item = if data then data.inventory()[instanceId] else nil
	local eggId = if item then item.hatchedEggId else nil
	self:showHatch(player, crabId, weightGrams, eggId, nil, nil, nil, instanceId, true)
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
	local data = Data[owner]
	local pending = if data then data.pendingHatchNowPurchase() else nil
	if pending and pending.incubatorInstanceId == instanceId and pending.eggInstanceId == incubator.eggInstanceId
		and pending.hatchAtUnixMs == incubator.hatchAtUnixMs then
		incubator:setHatchNowPending(true)
	end
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
