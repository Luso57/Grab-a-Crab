--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local EggConveyorServiceServer = require(ServerScriptService.Features.EggConveyor.EggConveyorServiceServer)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServer = require(script.Parent.Classes.PlotServer)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)

type SavedItem = { itemId: string, placedSlotId: string?, incubatorInstanceId: string?, tankInstanceId: string? }
type SavedInventory = { [string]: SavedItem }

local MAX_INTERACTION_DISTANCE = 10

local PlotServiceServer = {}
local initialized = false
local plots: { [number]: PlotServer.PlotServer } = {}
local playerPlots: { [Player]: PlotServer.PlotServer } = {}
local waiting: { Player } = {}
local waitingSet: { [Player]: boolean } = {}

local function getTemplate(itemId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local folder: Instance?
	local modelName: string?
	if itemId == "Incubator" then
		folder = assets:FindFirstChild("Incubators")
		modelName = "Incubator"
	else
		local tankId = string.match(itemId, "^Tank%.([%w_]+)$")
		local definition = if tankId then Tanks.get(tankId) else nil
		if definition then
			folder = assets:FindFirstChild("Tanks")
			modelName = definition.modelName
		end
	end
	local template = if folder and modelName then folder:FindFirstChild(modelName) else nil
	return if template and template:IsA("Model") and template.PrimaryPart then template else nil
end

local function makePlacedModel(itemId: string, instanceId: string, slot: BasePart): Model?
	local template = getTemplate(itemId)
	if not template then
		return nil
	end
	local model = template:Clone()
	local boxCFrame, boxSize = model:GetBoundingBox()
	if boxSize.Y <= 0 then
		model:Destroy()
		return nil
	end
	local pivotToBottom = model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	model:PivotTo(slot.CFrame * CFrame.new(0, slot.Size.Y / 2 + pivotToBottom, 0))
	model.Name = itemId .. "_" .. instanceId
	model:SetAttribute("ItemInstanceId", instanceId)
	model:SetAttribute("ItemId", itemId)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	return model
end

local function inRange(player: Player, slot: BasePart): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - slot.Position).Magnitude <= MAX_INTERACTION_DISTANCE
end

local function equippedTool(player: Player, instanceId: string, itemId: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ItemInstanceId") == instanceId and child:GetAttribute("ItemId") == itemId then
			return child
		end
	end
	return nil
end

local function clearPlacement(data: any, instanceId: string, item: SavedItem)
	local updated = table.clone(item)
	updated.placedSlotId = nil
	data.inventory[instanceId](updated)
end

local function restorePlayer(player: Player, plot: PlotServer.PlotServer)
	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players or playerPlots[player] ~= plot or plot:getOwner() ~= player then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local instanceIds: { string } = {}
	for instanceId, item in inventory do
		if typeof(item) == "table" and typeof(item.placedSlotId) == "string" then
			table.insert(instanceIds, instanceId)
		end
	end
	table.sort(instanceIds)

	local repaired = false
	for _, instanceId in instanceIds do
		if player.Parent ~= Players or playerPlots[player] ~= plot or plot:getOwner() ~= player then
			return
		end
		local item = inventory[instanceId]
		local slotId = item.placedSlotId
		local slot = if slotId then plot:getSlot(slotId) else nil
		if not slot or plot:getPlaced(slotId :: string) then
			clearPlacement(data, instanceId, item)
			repaired = true
			continue
		end
		local model = makePlacedModel(item.itemId, instanceId, slot)
		if not model or not plot:addPlaced(slotId :: string, model) then
			if model then
				model:Destroy()
			end
			clearPlacement(data, instanceId, item)
			repaired = true
		elseif item.itemId == "Incubator" then
			if not IncubatorServiceServer:registerPlaced(player, plot.model, model, instanceId) then
				plot:removePlaced(slotId :: string)
				clearPlacement(data, instanceId, item)
				repaired = true
			end
		elseif string.match(item.itemId, "^Tank%.([%w_]+)$") then
			if not TankServiceServer:registerPlaced(player, plot.model, model, instanceId) then
				plot:removePlaced(slotId :: string)
				clearPlacement(data, instanceId, item)
				repaired = true
			end
		end
	end
	local active: { [string]: string } = {}
	for _, model in plot.placedModels do
		if model:GetAttribute("ItemId") == "Incubator" then
			local incubatorId = model:GetAttribute("ItemInstanceId")
			local eggId = IncubatorServiceServer:getPlacedEggId(model)
			if typeof(incubatorId) == "string" and eggId then
				active[incubatorId] = eggId
			end
		end
	end
	InventoryServiceServer:repairIncubations(player, active)
	TankServiceServer:restoreContents(player)
	if repaired then
		InventoryServiceServer:refreshTools(player)
	end
end

local function assignWaiting()
	while #waiting > 0 do
		local freePlot: PlotServer.PlotServer? = nil
		for index = 1, 6 do
			local plot = plots[index]
			if plot and not plot:getOwner() then
				freePlot = plot
				break
			end
		end
		if not freePlot then
			return
		end

		local player = table.remove(waiting, 1)
		waitingSet[player] = nil
		if player.Parent == Players and not playerPlots[player] and freePlot:claim(player) then
			playerPlots[player] = freePlot
			task.spawn(restorePlayer, player, freePlot)
		end
	end
end

local function playerAdded(player: Player)
	if playerPlots[player] or waitingSet[player] then
		return
	end
	table.insert(waiting, player)
	waitingSet[player] = true
	assignWaiting()
end

local function playerRemoving(player: Player)
	if waitingSet[player] then
		local position = table.find(waiting, player)
		if position then
			table.remove(waiting, position)
		end
		waitingSet[player] = nil
	end

	local plot = playerPlots[player]
	if plot then
		playerPlots[player] = nil
		EggConveyorServiceServer:stop(plot.model)
		TankServiceServer:clearPlacedForPlayer(player)
		IncubatorServiceServer:clearPlacedForPlayer(player)
		plot:release()
		assignWaiting()
	end
end

function PlotServiceServer:init()
	if initialized then
		return
	end

	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Plot") :: Model
	local folder = Workspace:FindFirstChild("SpawnedPlots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpawnedPlots"
		folder.Parent = Workspace
	end
	if not folder:IsA("Folder") then
		warn("SpawnedPlots must be a Folder")
		return
	end

	for _, tagged in CollectionService:GetTagged("PlotSpawn") do
		if not tagged:IsA("BasePart") then
			warn("Skipping PlotSpawn that is not a BasePart")
			continue
		end
		local index = tagged:GetAttribute("Index")
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 6 then
			warn("Skipping PlotSpawn with invalid Index")
			continue
		end
		if plots[index] then
			warn("Skipping duplicate PlotSpawn Index", index)
			continue
		end
		local plot = PlotServer.new(index, tagged, template, folder)
		if plot then
			plots[index] = plot
		end
	end
	for index = 1, 6 do
		if not plots[index] then
			warn("Missing PlotSpawn Index", index)
		end
	end

	Networker.server.new("PlotPlacement", self, { self.place, self.pickup })
	initialized = true
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)
	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end
end

function PlotServiceServer:getPlot(player: Player): PlotServer.PlotServer?
	return playerPlots[player]
end

function PlotServiceServer:place(player: Player, instanceId: any, slotId: any)
	if typeof(instanceId) ~= "string" or typeof(slotId) ~= "string" then
		return
	end
	local plot = playerPlots[player]
	local slot = if plot then plot:getSlot(slotId) else nil
	if not plot or plot:getOwner() ~= player or not slot or plot:getPlaced(slotId) or not inRange(player, slot) then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	if typeof(item) ~= "table" or typeof(item.itemId) ~= "string" or item.placedSlotId ~= nil
		or item.incubatorInstanceId ~= nil or item.tankInstanceId ~= nil then
		return
	end
	if not equippedTool(player, instanceId, item.itemId) then
		return
	end
	for _, other in inventory do
		if typeof(other) == "table" and other.placedSlotId == slotId then
			return
		end
	end

	local model = makePlacedModel(item.itemId, instanceId, slot)
	if not model then
		return
	end
	if not plot:addPlaced(slotId, model) then
		model:Destroy()
		return
	end
	local tankId = string.match(item.itemId, "^Tank%.([%w_]+)$")
	if tankId and not TankServiceServer:registerPlaced(player, plot.model, model, instanceId) then
		plot:removePlaced(slotId)
		return
	end

	local updatedItem = table.clone(item)
	updatedItem.placedSlotId = slotId
	data.inventory[instanceId](updatedItem)
	if item.itemId == "Incubator" then
		IncubatorServiceServer:registerPlaced(player, plot.model, model, instanceId)
	end
	local hotbar = data.hotbar() :: { string }
	local updatedHotbar = table.clone(hotbar)
	local hotbarChanged = false
	for index = 1, InventoryConfig.hotbarSize do
		if updatedHotbar[index] == instanceId then
			updatedHotbar[index] = InventoryConfig.emptySlot
			hotbarChanged = true
		end
	end
	if hotbarChanged then
		data.hotbar(updatedHotbar)
	end
	InventoryServiceServer:refreshTools(player)
end

function PlotServiceServer:pickup(player: Player, slotId: any)
	if typeof(slotId) ~= "string" then
		return
	end
	local plot = playerPlots[player]
	local slot = if plot then plot:getSlot(slotId) else nil
	local model = if plot then plot:getPlaced(slotId) else nil
	if not plot or plot:getOwner() ~= player or not slot or not model or not inRange(player, slot) then
		return
	end
	local instanceId = model:GetAttribute("ItemInstanceId")
	if typeof(instanceId) ~= "string" then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local hammerId = InventoryConfig.hammerInstanceId(player.UserId)
	local hammer = inventory[hammerId]
	local hotbar = data.hotbar() :: { string }
	if not hammer or hammer.itemId ~= InventoryConfig.hammerItemId
		or hotbar[InventoryConfig.hammerSlot] ~= hammerId
		or not equippedTool(player, hammerId, InventoryConfig.hammerItemId) then
		return
	end
	local item = inventory[instanceId]
	if typeof(item) ~= "table" or item.placedSlotId ~= slotId then
		return
	end
	if item.itemId == "Incubator" then
		if IncubatorServiceServer:isOccupied(model) then
			return
		end
		for _, other in inventory do
			if typeof(other) == "table" and other.incubatorInstanceId == instanceId then
				return
			end
		end
		IncubatorServiceServer:unregisterPlaced(model)
	end
	if string.match(item.itemId, "^Tank%.([%w_]+)$") then
		if TankServiceServer:isOccupied(model) then
			return
		end
		for _, other in inventory do
			if typeof(other) == "table" and other.tankInstanceId == instanceId then
				return
			end
		end
		TankServiceServer:unregisterPlaced(model)
	end

	clearPlacement(data, instanceId, item)
	plot:removePlaced(slotId)
	for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
		if hotbar[index] == InventoryConfig.emptySlot then
			local updatedHotbar = table.clone(hotbar)
			updatedHotbar[index] = instanceId
			data.hotbar(updatedHotbar)
			break
		end
	end
	InventoryServiceServer:refreshTools(player)
end

return PlotServiceServer
