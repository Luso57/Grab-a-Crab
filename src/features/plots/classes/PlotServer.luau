--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotExtraSlots = require(ReplicatedStorage.Source.Features.Plots.Modules.PlotExtraSlots)

local SLOT_IDS = {
	Left1 = true,
	Left2 = true,
	Left3 = true,
	Right1 = true,
	Right2 = true,
	Right3 = true,
}

local PlotServer = {}
PlotServer.__index = PlotServer

export type PlotServer = typeof(setmetatable({} :: {
	index: number,
	spawn: BasePart,
	model: Model,
	spawnBase: BasePart,
	placementSlots: Folder,
	floorModels: { [number]: Model },
	extraSlotsPurchased: number,
	placedFolder: Folder,
	placedModels: { [string]: Model },
	owner: Player?,
	characterConnection: RBXScriptConnection?,
}, PlotServer))

function PlotServer.new(index: number, spawn: BasePart, template: Model, parent: Folder): PlotServer?
	local model = template:Clone()
	local spawnBase = model:FindFirstChild("PlaypenBase")
	local placementSlots = model:FindFirstChild("PlacementSlots")
	if not spawnBase or not spawnBase:IsA("BasePart")
		or not placementSlots or not placementSlots:IsA("Folder") then
		warn("Plot template needs PlaypenBase and PlacementSlots")
		model:Destroy()
		return nil
	end
	for slotId in SLOT_IDS do
		local slot = placementSlots:FindFirstChild(slotId)
		if not slot or not slot:IsA("BasePart") then
			warn("Plot template needs " .. slotId)
			model:Destroy()
			return nil
		end
	end
	local floorModels: { [number]: Model } = {}
	for floorIndex, floorName in PlotExtraSlots.floorNames do
		local floor = model:FindFirstChild(floorName)
		local deck = if floor then floor:FindFirstChild("Deck") else nil
		local mainDeck = if deck then deck:FindFirstChild("MainDeck") else nil
		if not floor or not floor:IsA("Model") or not mainDeck or not mainDeck:IsA("BasePart") then
			warn("Plot template needs " .. floorName .. ".Deck.MainDeck")
			model:Destroy()
			return nil
		end
		floorModels[floorIndex + 1] = floor
	end

	model.Name = "Plot_" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:PivotTo(spawn.CFrame)
	for _, floor in floorModels do
		floor.Parent = nil
	end
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("ConveyorLuck", 0)
	model:SetAttribute("ExtraSlotsPurchased", 0)

	local placedFolder = Instance.new("Folder")
	placedFolder.Name = "PlacedItems"
	placedFolder.Parent = model
	model.Parent = parent

	return setmetatable({
		index = index,
		spawn = spawn,
		model = model,
		spawnBase = spawnBase,
		placementSlots = placementSlots,
		floorModels = floorModels,
		extraSlotsPurchased = 0,
		placedFolder = placedFolder,
		placedModels = {} :: { [string]: Model },
		owner = nil :: Player?,
		characterConnection = nil :: RBXScriptConnection?,
	}, PlotServer) :: PlotServer
end

function PlotServer.getOwner(self: PlotServer): Player?
	return self.owner
end

function PlotServer.getSlot(self: PlotServer, slotId: string): BasePart?
	local purchaseNumber = PlotExtraSlots.getPurchaseNumber(slotId)
	if not SLOT_IDS[slotId] and (not purchaseNumber or purchaseNumber > self.extraSlotsPurchased) then
		return nil
	end
	local slot = self.placementSlots:FindFirstChild(slotId)
	return if slot and slot:IsA("BasePart") then slot else nil
end

function PlotServer.unlockNextSlot(self: PlotServer): boolean
	local purchaseNumber = self.extraSlotsPurchased + 1
	local floorNumber, baseId, slotId = PlotExtraSlots.getSlotInfo(purchaseNumber)
	if not floorNumber or not baseId or not slotId then
		return false
	end
	local floor = self.floorModels[floorNumber]
	local deck = if floor then floor:FindFirstChild("Deck") else nil
	local mainDeck = if deck then deck:FindFirstChild("MainDeck") else nil
	local baseSlot = self.placementSlots:FindFirstChild(baseId)
	if not floor or not mainDeck or not mainDeck:IsA("BasePart")
		or not baseSlot or not baseSlot:IsA("BasePart") or self.placementSlots:FindFirstChild(slotId) then
		return false
	end

	local slot = baseSlot:Clone()
	slot.Name = slotId
	local deckTop = mainDeck.Position.Y + mainDeck.Size.Y / 2
	local baseTop = baseSlot.Position.Y + baseSlot.Size.Y / 2
	slot.CFrame = baseSlot.CFrame + Vector3.new(0, deckTop - baseTop + 0.05, 0)
	if floor.Parent ~= self.model then
		floor.Parent = self.model
	end
	slot.Parent = self.placementSlots
	self.extraSlotsPurchased = purchaseNumber
	self.model:SetAttribute("ExtraSlotsPurchased", purchaseNumber)
	return true
end

function PlotServer.unlockThrough(self: PlotServer, purchasedCount: number): boolean
	local target = PlotExtraSlots.normalizeCount(purchasedCount)
	while self.extraSlotsPurchased < target do
		if not self:unlockNextSlot() then
			return false
		end
	end
	return true
end

function PlotServer.getPlaced(self: PlotServer, slotId: string): Model?
	return self.placedModels[slotId]
end

function PlotServer.addPlaced(self: PlotServer, slotId: string, placedModel: Model): boolean
	if not self:getSlot(slotId) or self.placedModels[slotId] then
		return false
	end
	self.placedModels[slotId] = placedModel
	placedModel:SetAttribute("SlotId", slotId)
	placedModel.Parent = self.placedFolder
	return true
end

function PlotServer.removePlaced(self: PlotServer, slotId: string)
	local placedModel = self.placedModels[slotId]
	if placedModel then
		self.placedModels[slotId] = nil
		placedModel:Destroy()
	end
end

function PlotServer.clearPlaced(self: PlotServer)
	for slotId in self.placedModels do
		self:removePlaced(slotId)
	end
end

function PlotServer.teleportCharacter(self: PlotServer, player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or self.owner ~= player or player.Character ~= character or not character.Parent then
		return
	end

	character:PivotTo(self.spawnBase.CFrame * CFrame.new(0, self.spawnBase.Size.Y / 2 + 4, 0))
end

function PlotServer.claim(self: PlotServer, player: Player): boolean
	if self.owner then
		return false
	end

	self.owner = player
	self.model:SetAttribute("OwnerUserId", player.UserId)
	self.model:SetAttribute("ConveyorLuck", 0)
	self.characterConnection = player.CharacterAdded:Connect(function(character)
		task.spawn(PlotServer.teleportCharacter, self, player, character)
	end)

	if player.Character then
		task.spawn(PlotServer.teleportCharacter, self, player, player.Character)
	end

	return true
end

function PlotServer.release(self: PlotServer)
	if self.characterConnection then
		self.characterConnection:Disconnect()
		self.characterConnection = nil
	end
	self:clearPlaced()
	for purchaseNumber = 1, self.extraSlotsPurchased do
		local _, _, slotId = PlotExtraSlots.getSlotInfo(purchaseNumber)
		local slot = if slotId then self.placementSlots:FindFirstChild(slotId) else nil
		if slot then
			slot:Destroy()
		end
	end
	for _, floor in self.floorModels do
		floor.Parent = nil
	end
	self.extraSlotsPurchased = 0
	self.owner = nil
	self.model:SetAttribute("OwnerUserId", 0)
	self.model:SetAttribute("ConveyorLuck", 0)
	self.model:SetAttribute("ExtraSlotsPurchased", 0)
end

function PlotServer.destroy(self: PlotServer)
	self:release()
	for _, floor in self.floorModels do
		floor:Destroy()
	end
	self.model:Destroy()
end

return PlotServer
