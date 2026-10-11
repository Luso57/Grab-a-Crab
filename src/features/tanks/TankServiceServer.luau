--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local TankServer = require(script.Parent.Classes.TankServer)

type SavedItem = {
	itemId: string,
	placedSlotId: string?,
	incubatorInstanceId: string?,
	tankInstanceId: string?,
}
type SavedInventory = { [string]: SavedItem }

local TankServiceServer = {}
local initialized = false
local placedByPlayer: { [Player]: { [string]: TankServer.TankServer } } = {}
local placedByModel: { [Model]: TankServer.TankServer } = {}

local function inRange(player: Player, target: BasePart): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - target.Position).Magnitude <= 10
end

local function equippedCrab(player: Player, inventory: SavedInventory, hotbar: { string }): (Tool?, string?, string?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	for _, child in character:GetChildren() do
		if not child:IsA("Tool") then
			continue
		end
		local itemId = child:GetAttribute("ItemId")
		local instanceId = child:GetAttribute("ItemInstanceId")
		local crabId = if typeof(itemId) == "string" then string.match(itemId, "^Crab%.([%w_]+)$") else nil
		local item = if typeof(instanceId) == "string" then inventory[instanceId] else nil
		if crabId and Crabs.get(crabId) and typeof(instanceId) == "string"
			and typeof(item) == "table" and item.itemId == itemId
			and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil
			and table.find(hotbar, instanceId) ~= nil then
			return child, instanceId, crabId
		end
	end
	return nil, nil, nil
end

function TankServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	Networker.server.new("TankService", self, { self.pickupCrab })
	Players.PlayerRemoving:Connect(function(player)
		self:clearPlacedForPlayer(player)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.05 then
			return
		end
		elapsed = 0
		for _, tank in placedByModel do
			if tank:enteredMoneyPad() then
				self:collectMoneyPad(tank)
			end
		end
	end)
end

function TankServiceServer:createTool(player: Player, tankId: string, instanceId: string): Tool?
	local definition = Tanks.get(tankId)
	if not definition or player.Parent ~= Players then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local templates = if assets then assets:FindFirstChild("Tanks") else nil
	local template = if templates then templates:FindFirstChild(definition.modelName) else nil
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("Missing tank model template:", definition.modelName)
		return nil
	end

	local model = template:Clone()
	local height = model:GetExtentsSize().Y
	if height <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(2 / height)

	local tool = Instance.new("Tool")
	tool.Name = definition.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("TankId", tankId)
	tool:SetAttribute("TankInstanceId", instanceId)
	tool:SetAttribute("ItemId", "Tank." .. tankId)
	tool:SetAttribute("ItemInstanceId", instanceId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.CFrame = model:GetPivot()
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = handle
		end
	end
	model.Parent = tool
	return tool
end

function TankServiceServer:registerPlaced(owner: Player, plotModel: Model, model: Model, instanceId: string): boolean
	if placedByModel[model] or owner.Parent ~= Players or not model:IsDescendantOf(plotModel) then
		return false
	end
	local itemId = model:GetAttribute("ItemId")
	local tankId = if typeof(itemId) == "string" then string.match(itemId, "^Tank%.([%w_]+)$") else nil
	local definition = if tankId then Tanks.get(tankId) else nil
	if not definition or model:GetAttribute("ItemInstanceId") ~= instanceId then
		return false
	end
	local playerTanks = placedByPlayer[owner]
	if playerTanks and playerTanks[instanceId] then
		return false
	end
	local tank = TankServer.new(owner, plotModel, instanceId, tankId :: string, model, definition.capacity, function(player)
		self:placeCrab(player, model)
	end)
	if not tank then
		return false
	end
	if not playerTanks then
		playerTanks = {}
		placedByPlayer[owner] = playerTanks
	end
	playerTanks[instanceId] = tank
	placedByModel[model] = tank
	return true
end

function TankServiceServer:getPlacedTank(player: Player, instanceId: string): TankServer.TankServer?
	local playerTanks = placedByPlayer[player]
	return if playerTanks then playerTanks[instanceId] else nil
end

function TankServiceServer:isOccupied(model: Model): boolean
	local tank = placedByModel[model]
	return tank ~= nil and tank:isOccupied()
end

function TankServiceServer:unregisterPlaced(model: Model)
	local tank = placedByModel[model]
	if not tank then
		return
	end
	placedByModel[model] = nil
	local playerTanks = placedByPlayer[tank.owner]
	if playerTanks then
		playerTanks[tank.instanceId] = nil
	end
	tank:destroy()
end

function TankServiceServer:clearPlacedForPlayer(player: Player)
	local playerTanks = placedByPlayer[player]
	if not playerTanks then
		return
	end
	local models = {}
	for _, tank in playerTanks do
		table.insert(models, tank.model)
	end
	for _, model in models do
		self:unregisterPlaced(model)
	end
	placedByPlayer[player] = nil
end

function TankServiceServer:collectMoneyPad(tank: TankServer.TankServer)
	local player = tank.owner
	local model = tank.model
	if tank.destroyed or placedByModel[model] ~= tank or player.Parent ~= Players
		or not model:IsDescendantOf(tank.plotModel) then
		return
	end
	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= model then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local savedTank = (data.inventory() :: SavedInventory)[tank.instanceId]
	if typeof(savedTank) ~= "table" or savedTank.itemId ~= "Tank." .. tank.tankId
		or savedTank.placedSlotId ~= slotId then
		return
	end
	local amount, now = tank:collectableAmount()
	if amount <= 0 then
		return
	end
	data.money(function(balance: number)
		return balance + amount
	end)
	tank:resetMoneyPad(now)
	model:SetAttribute("MoneyPadCollectionSerial", (model:GetAttribute("MoneyPadCollectionSerial") or 0) + 1)
	local pad = tank.moneyPad
	local green = if pad then pad:FindFirstChild("GreenInnerCircle") else nil
	local collectionSound = if green then green:FindFirstChild("CollectionSound") else nil
	if collectionSound and collectionSound:IsA("Sound") then
		collectionSound.TimePosition = 0
		collectionSound:Play()
	end
end

function TankServiceServer:placeCrab(player: Player, model: Model)
	local tank = placedByModel[model]
	if not tank or tank.owner ~= player or player.Parent ~= Players or not tank:canAdd()
		or not model:IsDescendantOf(tank.plotModel) or not inRange(player, tank.floor) then
		return
	end
	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= model then
		return
	end

	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local savedTank = inventory[tank.instanceId]
	if typeof(savedTank) ~= "table" or savedTank.itemId ~= "Tank." .. tank.tankId
		or savedTank.placedSlotId ~= slotId then
		return
	end
	local hotbar = data.hotbar() :: { string }
	local tool, crabInstanceId, crabId = equippedCrab(player, inventory, hotbar)
	if not tool or not crabInstanceId or not crabId or not tank:addCrab(crabInstanceId, crabId) then
		return
	end

	local crabItem = inventory[crabInstanceId]
	local updatedCrab = table.clone(crabItem)
	updatedCrab.tankInstanceId = tank.instanceId
	data.inventory[crabInstanceId](updatedCrab)

	local updatedHotbar = table.clone(hotbar)
	for index, assignedId in updatedHotbar do
		if assignedId == crabInstanceId then
			updatedHotbar[index] = InventoryConfig.emptySlot
		end
	end
	data.hotbar(updatedHotbar)
	tool:Destroy()
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
end

function TankServiceServer:pickupCrab(player: Player, tankInstanceId: any, crabInstanceId: any)
	if typeof(tankInstanceId) ~= "string" or typeof(crabInstanceId) ~= "string"
		or player.Parent ~= Players then
		return
	end
	local tank = self:getPlacedTank(player, tankInstanceId)
	if not tank or tank.destroyed or not tank.model:IsDescendantOf(tank.plotModel)
		or not inRange(player, tank.floor) then
		return
	end

	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = tank.model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= tank.model then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local savedTank = inventory[tankInstanceId]
	local savedCrab = inventory[crabInstanceId]
	local crabId = if typeof(savedCrab) == "table" and typeof(savedCrab.itemId) == "string"
		then string.match(savedCrab.itemId, "^Crab%.([%w_]+)$") else nil
	if typeof(savedTank) ~= "table" or savedTank.itemId ~= "Tank." .. tank.tankId
		or savedTank.placedSlotId ~= slotId or typeof(savedCrab) ~= "table"
		or savedCrab.tankInstanceId ~= tankInstanceId or savedCrab.placedSlotId ~= nil
		or savedCrab.incubatorInstanceId ~= nil or not crabId or not Crabs.get(crabId)
		or not tank:removeCrab(crabInstanceId, crabId) then
		return
	end

	local updatedCrab = table.clone(savedCrab)
	updatedCrab.tankInstanceId = nil
	data.inventory[crabInstanceId](updatedCrab)

	local hotbar = data.hotbar() :: { string }
	if table.find(hotbar, crabInstanceId) == nil then
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if hotbar[index] == InventoryConfig.emptySlot then
				local updatedHotbar = table.clone(hotbar)
				updatedHotbar[index] = crabInstanceId
				data.hotbar(updatedHotbar)
				break
			end
		end
	end
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
end

function TankServiceServer:restoreContents(player: Player)
	local playerTanks = placedByPlayer[player]
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local crabInstanceIds = {}
	for instanceId, item in inventory do
		if typeof(item) == "table" and item.tankInstanceId ~= nil then
			table.insert(crabInstanceIds, instanceId)
		end
	end
	table.sort(crabInstanceIds)

	local repaired = {}
	for _, instanceId in crabInstanceIds do
		local item = inventory[instanceId]
		local tank = if typeof(item.tankInstanceId) == "string" and playerTanks then playerTanks[item.tankInstanceId] else nil
		local tankItem = if tank then inventory[tank.instanceId] else nil
		local crabId = if typeof(item.itemId) == "string" then string.match(item.itemId, "^Crab%.([%w_]+)$") else nil
		local slotId = if tank then tank.model:GetAttribute("SlotId") else nil
		if not tank or not tankItem or tankItem.itemId ~= "Tank." .. tank.tankId
			or tankItem.placedSlotId ~= slotId or not crabId or not Crabs.get(crabId)
			or item.placedSlotId ~= nil or item.incubatorInstanceId ~= nil
			or not tank:addCrab(instanceId, crabId) then
			local updated = table.clone(item)
			updated.tankInstanceId = nil
			data.inventory[instanceId](updated)
			table.insert(repaired, instanceId)
		end
	end

	if #repaired > 0 then
		local hotbar = data.hotbar() :: { string }
		local updatedHotbar = table.clone(hotbar)
		for _, instanceId in repaired do
			if table.find(updatedHotbar, instanceId) == nil then
				for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
					if updatedHotbar[index] == InventoryConfig.emptySlot then
						updatedHotbar[index] = instanceId
						break
					end
				end
			end
		end
		data.hotbar(updatedHotbar)
	end
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
end

return TankServiceServer