--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabRigBuilder = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabRigBuilder)

local TankServer = {}
TankServer.__index = TankServer

export type TankServer = typeof(setmetatable({} :: {
	owner: Player,
	plotModel: Model,
	instanceId: string,
	tankId: string,
	model: Model,
	floor: BasePart,
	capacity: number,
	prompt: ProximityPrompt,
	visualFolder: Folder,
	moneyPad: Model?,
	incomePerSecond: number,
	displayedEarnings: number,
	lastIncomeUpdate: number,
	wasOnMoneyPad: boolean,
	crabIds: { string },
	visuals: { [string]: BasePart },
	triggerConnection: RBXScriptConnection?,
	destroyed: boolean,
}, TankServer))

local function positions(count: number, floor: BasePart): { Vector2 }
	if count == 1 then
		return { Vector2.zero }
	end
	if count == 2 then
		local x = floor.Size.X * 0.23
		return { Vector2.new(-x, 0), Vector2.new(x, 0) }
	end
	local x = floor.Size.X * 0.23
	local z = floor.Size.Z * 0.2
	return {
		Vector2.new(-x, z),
		Vector2.new(x, z),
		Vector2.new(0, -z),
	}
end

local function maxFootprint(self: TankServer): number
	if self.capacity == 1 then
		return math.min(2.5, self.floor.Size.X * 0.65, self.floor.Size.Z * 0.65)
	elseif self.capacity == 2 then
		return math.min(2, self.floor.Size.X * 0.38, self.floor.Size.Z * 0.65)
	end
	return math.min(2, self.floor.Size.X * 0.3, self.floor.Size.Z * 0.3)
end

local function placeMoneyPad(plotModel: Model, model: Model): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = if assets then assets:FindFirstChild("MoneyPad") else nil
	local slots = plotModel:FindFirstChild("PlacementSlots")
	local slotId = model:GetAttribute("SlotId")
	if not template or not template:IsA("Model") or not slots or typeof(slotId) ~= "string" then
		warn("Money pad template or tank slot missing:", model:GetFullName())
		return nil
	end
	local side = string.match(slotId, "^(Left)") or string.match(slotId, "^(Right)")
	if not side then return nil end
	local own = slots:FindFirstChild(side .. "1")
	local opposite = slots:FindFirstChild((if side == "Left" then "Right" else "Left") .. "1")
	local slot = slots:FindFirstChild(slotId)
	if not own or not own:IsA("BasePart") or not opposite or not opposite:IsA("BasePart")
		or not slot or not slot:IsA("BasePart") then return nil end
	local inward = opposite.Position - own.Position
	inward = Vector3.new(inward.X, 0, inward.Z).Unit
	local box, size = model:GetBoundingBox()
	local halfDepth = (math.abs(box.RightVector:Dot(inward)) * size.X
		+ math.abs(box.LookVector:Dot(inward)) * size.Z) / 2
	local pad = template:Clone()
	local padPivot = pad:GetPivot()
	local bottom = math.huge
	local padRadius = 0
	for _, part in pad:GetDescendants() do
		if part:IsA("BasePart") then
			local frame = part.CFrame
			local partSize = part.Size
			local halfY = (math.abs(frame.RightVector.Y) * partSize.X
				+ math.abs(frame.UpVector.Y) * partSize.Y
				+ math.abs(frame.LookVector.Y) * partSize.Z) / 2
			bottom = math.min(bottom, part.Position.Y - halfY)
			padRadius = math.max(padRadius, partSize.Y / 2, partSize.Z / 2)
		end
	end
	if bottom == math.huge then
		pad:Destroy()
		return nil
	end
	local pivotToBottom = padPivot.Position.Y - bottom
	local surfaceY = slot.Position.Y + slot.Size.Y / 2
	local target = box.Position + inward * (halfDepth + padRadius + 0.5)
	pad:PivotTo(CFrame.new(target.X, surfaceY + pivotToBottom, target.Z) * padPivot.Rotation)
	for _, descendant in pad:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanTouch = false
		end
	end
	local green = pad:FindFirstChild("GreenInnerCircle")
	if green and green:IsA("BasePart") then
		local collectionSound = Instance.new("Sound")
		collectionSound.Name = "CollectionSound"
		collectionSound.SoundId = "rbxassetid://4612383453"
		collectionSound.Volume = 1
		collectionSound.RollOffMaxDistance = 35
		collectionSound.Parent = green
	end
	pad.Name = "MoneyPad"
	pad.Parent = model
	return pad
end

function TankServer.new(owner: Player, plotModel: Model, instanceId: string, tankId: string, model: Model, capacity: number, onPlace: (Player) -> ()): TankServer?
	local floor = model:FindFirstChild("InsideFloor", true)
	if not floor or not floor:IsA("BasePart") then
		warn("Placed tank needs InsideFloor:", model:GetFullName())
		return nil
	end

	local visualFolder = Instance.new("Folder")
	visualFolder.Name = "ContainedCrabs"
	visualFolder.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlaceCrabPrompt"
	prompt.ActionText = "Place Crab"
	prompt.ObjectText = "Tank"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = floor

	model:SetAttribute("TankCapacity", capacity)
	model:SetAttribute("ContainedCrabCount", 0)
	model:SetAttribute("IncomePerSecond", 0)
	model:SetAttribute("MoneyPadBaseAmount", 0)
	model:SetAttribute("MoneyPadCollectionSerial", 0)
	local now = Workspace:GetServerTimeNow()
	model:SetAttribute("MoneyPadUpdatedAt", now)
	local moneyPad = placeMoneyPad(plotModel, model)

	local self = setmetatable({
		owner = owner,
		plotModel = plotModel,
		instanceId = instanceId,
		tankId = tankId,
		model = model,
		floor = floor,
		capacity = capacity,
		prompt = prompt,
		visualFolder = visualFolder,
		moneyPad = moneyPad,
		incomePerSecond = 0,
		displayedEarnings = 0,
		lastIncomeUpdate = now,
		wasOnMoneyPad = false,
		crabIds = {} :: { string },
		visuals = {} :: { [string]: BasePart },
		triggerConnection = nil :: RBXScriptConnection?,
		destroyed = false,
	}, TankServer) :: TankServer

	self.triggerConnection = prompt.Triggered:Connect(onPlace)
	return self
end

function TankServer.canAdd(self: TankServer): boolean
	return not self.destroyed and #self.crabIds < self.capacity
end

function TankServer.isOccupied(self: TankServer): boolean
	return #self.crabIds > 0
end

function TankServer.enteredMoneyPad(self: TankServer): boolean
	local onPad = false
	local pad = self.moneyPad
	local green = if pad then pad:FindFirstChild("GreenInnerCircle") else nil
	local character = self.owner.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not self.destroyed and green and green:IsA("BasePart")
		and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		local offset = root.Position - green.Position
		local radius = math.min(green.Size.Y, green.Size.Z) / 2 + 0.3
		onPad = Vector2.new(offset.X, offset.Z).Magnitude <= radius
			and offset.Y >= 0 and offset.Y <= 4.5
	end
	local entered = onPad and not self.wasOnMoneyPad
	self.wasOnMoneyPad = onPad
	return entered
end

function TankServer.collectableAmount(self: TankServer): (number, number)
	local now = Workspace:GetServerTimeNow()
	local completedSeconds = math.max(0, math.floor(now - self.lastIncomeUpdate))
	return self.displayedEarnings + self.incomePerSecond * completedSeconds, now
end

function TankServer.resetMoneyPad(self: TankServer, now: number)
	self.displayedEarnings = 0
	self.lastIncomeUpdate = now
	self.model:SetAttribute("MoneyPadBaseAmount", 0)
	self.model:SetAttribute("MoneyPadUpdatedAt", now)
end

function TankServer.relayout(self: TankServer)
	local slots = positions(#self.crabIds, self.floor)
	for index, crabInstanceId in self.crabIds do
		local anchor = self.visuals[crabInstanceId]
		local position = slots[index]
		local pivotToBottom = anchor:GetAttribute("PivotToBottom")
		if typeof(pivotToBottom) == "number" then
			anchor.CFrame = self.floor.CFrame * CFrame.new(
				position.X,
				self.floor.Size.Y / 2 + pivotToBottom,
				position.Y
			)
		end
	end
end

function TankServer.addCrab(self: TankServer, crabInstanceId: string, crabId: string): boolean
	if not self:canAdd() or self.visuals[crabInstanceId] then
		return false
	end

	local definition = Crabs.get(crabId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crabs = if assets then assets:FindFirstChild("Crabs") else nil
	local template = if definition and crabs then crabs:FindFirstChild(definition.modelName) else nil
	if not template or not template:IsA("Model") then
		warn("Missing crab model for tank:", crabId)
		return false
	end

	local sample = template:Clone()
	if not CrabRigBuilder.rig(sample) then
		sample:Destroy()
		return false
	end
	local _, size = sample:GetBoundingBox()
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		sample:Destroy()
		return false
	end
	local footprint = maxFootprint(self)
	local scale = math.min(footprint / size.X, 2 / size.Y, footprint / size.Z)
	sample:ScaleTo(sample:GetScale() * scale)
	local boxCFrame, boxSize = sample:GetBoundingBox()
	local pivotToBottom = sample:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	local displayScale = sample:GetScale()
	sample:Destroy()

	local anchor = Instance.new("Part")
	anchor.Name = "ContainedCrabAnchor"
	anchor.Size = Vector3.new(0.05, 0.05, 0.05)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor:SetAttribute("ItemInstanceId", crabInstanceId)
	anchor:SetAttribute("CrabId", crabId)
	anchor:SetAttribute("DisplayScale", displayScale)
	anchor:SetAttribute("PivotToBottom", pivotToBottom)
	anchor.Parent = self.visualFolder

	self.visuals[crabInstanceId] = anchor
	table.insert(self.crabIds, crabInstanceId)
	self:relayout()
	self.model:SetAttribute("ContainedCrabCount", #self.crabIds)
	local now = Workspace:GetServerTimeNow()
	if self.incomePerSecond > 0 then
		local completedSeconds = math.max(0, math.floor(now - self.lastIncomeUpdate))
		self.displayedEarnings += self.incomePerSecond * completedSeconds
		self.lastIncomeUpdate += completedSeconds
	else
		self.lastIncomeUpdate = now
	end
	self.model:SetAttribute("MoneyPadBaseAmount", self.displayedEarnings)
	self.model:SetAttribute("MoneyPadUpdatedAt", self.lastIncomeUpdate)
	self.incomePerSecond += definition.incomePerSecond
	self.model:SetAttribute("IncomePerSecond", self.incomePerSecond)
	self.prompt.Enabled = self:canAdd()
	return true
end

function TankServer.removeCrab(self: TankServer, crabInstanceId: string, crabId: string): boolean
	local anchor = self.visuals[crabInstanceId]
	local index = table.find(self.crabIds, crabInstanceId)
	local definition = Crabs.get(crabId)
	if self.destroyed or not anchor or not index or not definition or anchor:GetAttribute("CrabId") ~= crabId then
		return false
	end

	local now = Workspace:GetServerTimeNow()
	local completedSeconds = math.max(0, math.floor(now - self.lastIncomeUpdate))
	self.displayedEarnings += self.incomePerSecond * completedSeconds
	self.lastIncomeUpdate = now
	self.incomePerSecond = math.max(0, self.incomePerSecond - definition.incomePerSecond)

	self.visuals[crabInstanceId] = nil
	table.remove(self.crabIds, index)
	anchor:Destroy()
	self:relayout()
	self.model:SetAttribute("ContainedCrabCount", #self.crabIds)
	self.model:SetAttribute("MoneyPadBaseAmount", self.displayedEarnings)
	self.model:SetAttribute("MoneyPadUpdatedAt", now)
	self.model:SetAttribute("IncomePerSecond", self.incomePerSecond)
	self.prompt.Enabled = self:canAdd()
	return true
end

function TankServer.destroy(self: TankServer)
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.triggerConnection then
		self.triggerConnection:Disconnect()
		self.triggerConnection = nil
	end
	self.prompt:Destroy()
	if self.moneyPad then
		self.moneyPad:Destroy()
		self.moneyPad = nil
	end
	self.visualFolder:Destroy()
	table.clear(self.visuals)
	table.clear(self.crabIds)
end

return TankServer
