--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local ItemCatalog = require(ReplicatedStorage.Source.Game.Items.ItemCatalog)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabServer = require(ServerScriptService.Features.Crabs.Classes.CrabServer)

type SavedItem = { itemId: string, placedSlotId: string?, incubatorInstanceId: string?, tankInstanceId: string?, hatchAtUnixMs: number? }
type SavedInventory = { [string]: SavedItem }

local InventoryServiceServer = {}
local initialized = false
local readyPlayers: { [Player]: boolean } = {}
local syncQueued: { [Player]: boolean } = {}

local function ensureHammer(data: any, player: Player): string
	local hammerId = InventoryConfig.hammerInstanceId(player.UserId)
	local inventory = data.inventory() :: SavedInventory
	for instanceId, item in inventory do
		if instanceId ~= hammerId and typeof(item) == "table" and item.itemId == InventoryConfig.hammerItemId then
			data.inventory[instanceId](nil)
		end
	end
	local saved = inventory[hammerId]
	if typeof(saved) ~= "table" or saved.itemId ~= InventoryConfig.hammerItemId or saved.placedSlotId ~= nil then
		data.inventory[hammerId]({ itemId = InventoryConfig.hammerItemId })
	end
	return hammerId
end

local function normalizeHotbar(data: any, player: Player): { string }
	local hammerId = ensureHammer(data, player)
	local inventory = data.inventory() :: SavedInventory
	local current = data.hotbar() :: { string }
	local normalized: { string } = { hammerId }
	local seen: { [string]: boolean } = { [hammerId] = true }
	local changed = #current ~= InventoryConfig.hotbarSize or current[InventoryConfig.hammerSlot] ~= hammerId

	for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
		local instanceId = current[index]
		local item = if typeof(instanceId) == "string" then inventory[instanceId] else nil
		if typeof(item) == "table" and item.itemId ~= InventoryConfig.hammerItemId
			and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil and not seen[instanceId] then
			normalized[index] = instanceId
			seen[instanceId] = true
		else
			normalized[index] = InventoryConfig.emptySlot
		end
	end

	local displacedId = current[InventoryConfig.hammerSlot]
	local displaced = if typeof(displacedId) == "string" then inventory[displacedId] else nil
	if typeof(displaced) == "table" and displaced.itemId ~= InventoryConfig.hammerItemId
		and displaced.placedSlotId == nil and displaced.incubatorInstanceId == nil and displaced.tankInstanceId == nil and not seen[displacedId] then
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if normalized[index] == InventoryConfig.emptySlot then
				normalized[index] = displacedId
				break
			end
		end
	end

	for index = 1, InventoryConfig.hotbarSize do
		if normalized[index] ~= current[index] then
			changed = true
		end
	end
	if changed then
		data.hotbar(normalized)
	end
	return normalized
end

local function createEggTool(player: Player, eggId: string, instanceId: string): Tool?
	local definition = Eggs.get(eggId)
	if not definition or player.Parent ~= Players then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local templates = if assets then assets:FindFirstChild("Eggs") else nil
	local template = if templates then templates:FindFirstChild(eggId) else nil
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("Missing egg model template:", eggId)
		return nil
	end

	local model = template:Clone()
	local height = model:GetExtentsSize().Y
	if height <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * 2 / height)

	local tool = Instance.new("Tool")
	tool.Name = definition.name
	tool.TextureId = "rbxassetid://" .. definition.imageId
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("EggId", eggId)
	tool:SetAttribute("ItemId", "Egg." .. eggId)
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
local function createTool(player: Player, itemId: string, instanceId: string): Tool?
	if itemId == InventoryConfig.hammerItemId then
		local template = ReplicatedStorage:FindFirstChild("Assets")
		local tools = if template then template:FindFirstChild("Tools") else nil
		local hammer = if tools then tools:FindFirstChild("Hammer") else nil
		if not hammer or not hammer:IsA("Tool") then
			warn("Missing ReplicatedStorage.Assets.Tools.Hammer Tool")
			return nil
		end
		local tool = hammer:Clone()
		tool.CanBeDropped = false
		tool:SetAttribute("ItemId", itemId)
		tool:SetAttribute("ItemInstanceId", instanceId)
		return tool
	end
	if itemId == "Incubator" then
		return IncubatorServiceServer:createTool(player, "Incubator", instanceId)
	end
	local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
	if eggId then
		return createEggTool(player, eggId, instanceId)
	end

	local crabId = string.match(itemId, "^Crab%.([%w_]+)$")
	if crabId and Crabs.get(crabId) then
		local crab = CrabServer.new(instanceId, crabId)
		return if crab then crab.tool else nil
	end

	local tankId = string.match(itemId, "^Tank%.([%w_]+)$")
	if tankId and Tanks.get(tankId) then
		return TankServiceServer:createTool(player, tankId, instanceId)
	end
	return nil
end

local function syncTools(player: Player)
	if not readyPlayers[player] or player.Parent ~= Players then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local hotbar = data.hotbar() :: { string }
	local wanted: { [string]: string } = {}
	for index = 1, InventoryConfig.hotbarSize do
		local instanceId = hotbar[index]
		local item = if typeof(instanceId) == "string" then inventory[instanceId] else nil
		if typeof(item) == "table" and typeof(item.itemId) == "string" and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil and ItemCatalog.get(item.itemId) then
			wanted[instanceId] = item.itemId
		end
	end

	local found: { [string]: boolean } = {}
	local function scan(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if not child:IsA("Tool") then
				continue
			end
			local instanceId = child:GetAttribute("ItemInstanceId")
			if typeof(instanceId) ~= "string" then
				continue
			end
			if wanted[instanceId] == child:GetAttribute("ItemId") and not found[instanceId] then
				found[instanceId] = true
			else
				child:Destroy()
			end
		end
	end

	scan(backpack)
	scan(player.Character)

	for instanceId, itemId in wanted do
		if not found[instanceId] then
			local tool = createTool(player, itemId, instanceId)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

local function scheduleSync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		syncTools(player)
	end)
end

local function setupPlayer(player: Player)
	local function watchToolRemoval(container: Instance)
		container.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("ItemId") == InventoryConfig.hammerItemId then
				scheduleSync(player)
			end
		end)
	end
	player.CharacterAdded:Connect(function(character)
		watchToolRemoval(character)
		scheduleSync(player)
	end)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchToolRemoval(child)
			scheduleSync(player)
		end
	end)
	if player.Character then
		watchToolRemoval(player.Character)
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchToolRemoval(backpack)
	end
	task.spawn(function()
		local data = Data.Service:waitForData(player)
		if player.Parent ~= Players then
			return
		end
		normalizeHotbar(data, player)
		readyPlayers[player] = true
		scheduleSync(player)
	end)
end

function InventoryServiceServer:init()
	if initialized then
		return
	end
	initialized = true

	Networker.server.new("InventoryService", self, { self.setHotbarSlot, self.removeHotbarSlot })
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		readyPlayers[player] = nil
		syncQueued[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

function InventoryServiceServer:grantItem(player: Player, itemId: string, canGrant: (() -> boolean)?): string?
	if itemId == InventoryConfig.hammerItemId or not ItemCatalog.get(itemId) or player.Parent ~= Players then
		return nil
	end

	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players or (canGrant and not canGrant()) then
		return nil
	end

	local inventory = data.inventory() :: SavedInventory
	local count = 0
	for _, item in inventory do
		if typeof(item) == "table" and item.itemId ~= InventoryConfig.hammerItemId then
			count += 1
		end
	end
	if count >= InventoryConfig.maxItems then
		return nil
	end

	local instanceId = HttpService:GenerateGUID(false)
	data.inventory[instanceId]({ itemId = itemId })
	local hotbar = normalizeHotbar(data, player)
	for index = 1, InventoryConfig.hotbarSize do
		if hotbar[index] == InventoryConfig.emptySlot then
			local updated = table.clone(hotbar)
			updated[index] = instanceId
			data.hotbar(updated)
			break
		end
	end

	readyPlayers[player] = true
	scheduleSync(player)
	return instanceId
end

function InventoryServiceServer:setHotbarSlot(player: Player, instanceId: any, slotIndex: any)
	if typeof(instanceId) ~= "string" or typeof(slotIndex) ~= "number" then
		return
	end
	if slotIndex % 1 ~= 0 or slotIndex <= InventoryConfig.hammerSlot or slotIndex > InventoryConfig.hotbarSize then
		return
	end
	if not readyPlayers[player] or player.Parent ~= Players then
		return
	end

	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	if typeof(item) ~= "table" or typeof(item.itemId) ~= "string" or item.placedSlotId ~= nil or item.incubatorInstanceId ~= nil or item.tankInstanceId ~= nil or item.itemId == InventoryConfig.hammerItemId or not ItemCatalog.get(item.itemId) then
		return
	end
	local hotbar = normalizeHotbar(data, player)
	local sourceIndex: number? = nil
	for index, assignedId in hotbar do
		if assignedId == instanceId then
			sourceIndex = index
			break
		end
	end
	if sourceIndex == slotIndex then
		return
	end

	local updated = table.clone(hotbar)
	if sourceIndex then
		updated[sourceIndex] = hotbar[slotIndex]
	end
	updated[slotIndex] = instanceId
	data.hotbar(updated)
	scheduleSync(player)
end

function InventoryServiceServer:removeHotbarSlot(player: Player, instanceId: any)
	if typeof(instanceId) ~= "string" or not readyPlayers[player] or player.Parent ~= Players then
		return
	end

	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	if not inventory[instanceId] or inventory[instanceId].itemId == InventoryConfig.hammerItemId then
		return
	end

	local hotbar = normalizeHotbar(data, player)
	for index, assignedId in hotbar do
		if assignedId == instanceId then
			local updated = table.clone(hotbar)
			updated[index] = InventoryConfig.emptySlot
			data.hotbar(updated)
			scheduleSync(player)
			return
		end
	end
end

function InventoryServiceServer:startIncubation(player: Player, incubatorInstanceId: string): (string?, string?, number?)
	if not readyPlayers[player] or player.Parent ~= Players then
		return nil, nil, nil
	end
	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local incubatorItem = inventory[incubatorInstanceId]
	if typeof(incubatorItem) ~= "table" or incubatorItem.itemId ~= "Incubator"
		or typeof(incubatorItem.placedSlotId) ~= "string" then
		return nil, nil, nil
	end
	for _, item in inventory do
		if typeof(item) == "table" and item.incubatorInstanceId == incubatorInstanceId then
			return nil, nil, nil
		end
	end
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local hotbar = data.hotbar() :: { string }
	for _, child in character:GetChildren() do
		if not child:IsA("Tool") then
			continue
		end
		local instanceId = child:GetAttribute("ItemInstanceId")
		local itemId = child:GetAttribute("ItemId")
		if typeof(instanceId) ~= "string" or typeof(itemId) ~= "string" then
			continue
		end
		local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
		local item = inventory[instanceId]
		if not eggId or not Eggs.get(eggId) or typeof(item) ~= "table" or item.itemId ~= itemId
			or item.placedSlotId ~= nil or item.incubatorInstanceId ~= nil or item.tankInstanceId ~= nil
			or table.find(hotbar, instanceId) == nil then
			continue
		end
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local eggs = if assets then assets:FindFirstChild("Eggs") else nil
		local template = if eggs then eggs:FindFirstChild(eggId) else nil
		local crabId = if template then template:GetAttribute("CrabId") else nil
		if typeof(crabId) ~= "string" or not Crabs.get(crabId) then
			return nil, nil, nil
		end
		local crabs = if assets then assets:FindFirstChild("Crabs") else nil
		local crabTemplate = if crabs then crabs:FindFirstChild(crabId) else nil
		if not crabTemplate or not crabTemplate:IsA("Model") then
			return nil, nil, nil
		end

		local hatchAtUnixMs = DateTime.now().UnixTimestampMillis + 3000
		local updated = table.clone(item)
		updated.incubatorInstanceId = incubatorInstanceId
		updated.hatchAtUnixMs = hatchAtUnixMs
		data.inventory[instanceId](updated)
		local updatedHotbar = table.clone(hotbar)
		for index, assignedId in updatedHotbar do
			if assignedId == instanceId then
				updatedHotbar[index] = InventoryConfig.emptySlot
			end
		end
		data.hotbar(updatedHotbar)
		child:Destroy()
		scheduleSync(player)
		return instanceId, eggId, hatchAtUnixMs
	end
	return nil, nil, nil
end

function InventoryServiceServer:completeIncubation(player: Player, eggInstanceId: string, incubatorInstanceId: string, hatchAtUnixMs: number): boolean
	if player.Parent ~= Players or DateTime.now().UnixTimestampMillis < hatchAtUnixMs then
		return false
	end
	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[eggInstanceId]
	if typeof(item) ~= "table" or item.incubatorInstanceId ~= incubatorInstanceId
		or item.hatchAtUnixMs ~= hatchAtUnixMs then
		return false
	end
	local eggId = string.match(item.itemId, "^Egg%.([%w_]+)$")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local eggs = if assets then assets:FindFirstChild("Eggs") else nil
	local template = if eggId and eggs then eggs:FindFirstChild(eggId) else nil
	local crabId = if template then template:GetAttribute("CrabId") else nil
	local crabDefinition = if typeof(crabId) == "string" then Crabs.get(crabId) else nil
	local crabs = if assets then assets:FindFirstChild("Crabs") else nil
	local crabTemplate = if crabDefinition and crabs then crabs:FindFirstChild(crabDefinition.modelName) else nil
	if not crabTemplate or not crabTemplate:IsA("Model") then
		warn("Cannot hatch egg without a valid crab model:", item.itemId)
		local recovered = table.clone(item)
		recovered.incubatorInstanceId = nil
		recovered.hatchAtUnixMs = nil
		data.inventory[eggInstanceId](recovered)
		scheduleSync(player)
		return true
	end
	local updated = table.clone(item)
	updated.itemId = "Crab." .. crabId
	updated.incubatorInstanceId = nil
	updated.hatchAtUnixMs = nil
	data.inventory[eggInstanceId](updated)
	local hotbar = normalizeHotbar(data, player)
	for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
		if hotbar[index] == InventoryConfig.emptySlot then
			local updatedHotbar = table.clone(hotbar)
			updatedHotbar[index] = eggInstanceId
			data.hotbar(updatedHotbar)
			break
		end
	end
	scheduleSync(player)
	return true
end

function InventoryServiceServer:repairIncubations(player: Player, active: { [string]: string })
	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local repaired = {}
	for instanceId, item in inventory do
		if typeof(item) == "table" and item.incubatorInstanceId ~= nil
			and (active[item.incubatorInstanceId] ~= instanceId
				or string.match(item.itemId, "^Egg%.([%w_]+)$") == nil
				or typeof(item.hatchAtUnixMs) ~= "number") then
			local updated = table.clone(item)
			updated.incubatorInstanceId = nil
			updated.hatchAtUnixMs = nil
			data.inventory[instanceId](updated)
			table.insert(repaired, instanceId)
		end
	end
	if #repaired == 0 then
		return
	end
	table.sort(repaired)
	local hotbar = normalizeHotbar(data, player)
	local updatedHotbar = table.clone(hotbar)
	for _, instanceId in repaired do
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if updatedHotbar[index] == InventoryConfig.emptySlot then
				updatedHotbar[index] = instanceId
				break
			end
		end
	end
	data.hotbar(updatedHotbar)
	scheduleSync(player)
end

function InventoryServiceServer:refreshTools(player: Player)
	if not readyPlayers[player] or player.Parent ~= Players then
		return
	end
	normalizeHotbar(Data[player], player)
	scheduleSync(player)
end
return InventoryServiceServer
