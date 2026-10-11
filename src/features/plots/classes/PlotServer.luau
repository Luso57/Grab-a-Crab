--!strict

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

	model.Name = "Plot_" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:PivotTo(spawn.CFrame)
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerUserId", 0)

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
	if not SLOT_IDS[slotId] then
		return nil
	end
	local slot = self.placementSlots:FindFirstChild(slotId)
	return if slot and slot:IsA("BasePart") then slot else nil
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
	self.owner = nil
	self.model:SetAttribute("OwnerUserId", 0)
end

function PlotServer.destroy(self: PlotServer)
	self:release()
	self.model:Destroy()
end

return PlotServer
