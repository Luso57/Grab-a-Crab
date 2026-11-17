--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local GiganticEggConfig = require(ReplicatedStorage.Source.Features.EggConveyor.Modules.GiganticEggConfig)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local Incubators = require(ReplicatedStorage.Source.Features.Incubators.Modules.Incubators)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)

type SavedItem = {
	itemId: string,
	incubatorInstanceId: string?,
	hatchAtUnixMs: number?,
	isGiganticEgg: boolean?,
}

local PlacedIncubatorServer = {}
PlacedIncubatorServer.__index = PlacedIncubatorServer

export type PlacedIncubatorServer = typeof(setmetatable({} :: {
	owner: Player,
	plotModel: Model,
	model: Model,
	instanceId: string,
	prompt: ProximityPrompt,
	hatchPrompt: ProximityPrompt?,
	eggInstanceId: string?,
	eggId: string?,
	hatchAtUnixMs: number?,
	visual: Model?,
	destroyed: boolean,
	hatchNowPending: boolean,
}, PlacedIncubatorServer))

local function inventoryService()
	return require(ServerScriptService.Features.Inventory.InventoryServiceServer)
end

local HATCH_NOW_MIN_DURATION_MS = 3 * 60 * 1000

local function canOfferHatchNow(self: PlacedIncubatorServer, eggId: string): boolean
	local itemId = self.model:GetAttribute("ItemId")
	local incubatorId = if itemId == "Incubator" then "Incubator"
		elseif typeof(itemId) == "string" then string.match(itemId, "^Incubator%.([%w_]+)$") else nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local eggTemplates = if assets then assets:FindFirstChild("Eggs") else nil
	local eggTemplate = if eggTemplates then eggTemplates:FindFirstChild(eggId) else nil
	local crabId = if eggTemplate then eggTemplate:GetAttribute("CrabId") else nil
	local crab = if typeof(crabId) == "string" then Crabs.get(crabId) else nil
	local duration = if incubatorId and crab then Incubators.getHatchDurationMs(incubatorId, eggId, crab.rarity) else nil
	return duration ~= nil and duration >= HATCH_NOW_MIN_DURATION_MS
end

local function moneyPadSide(self: PlacedIncubatorServer): Vector3?
	local slotId = self.model:GetAttribute("SlotId")
	local slots = self.plotModel:FindFirstChild("PlacementSlots")
	if typeof(slotId) ~= "string" or not slots then
		return nil
	end
	local side = string.match(slotId, "^(Left)") or string.match(slotId, "^(Right)")
	if not side then
		return nil
	end
	local own = slots:FindFirstChild(side .. "1")
	local opposite = slots:FindFirstChild((if side == "Left" then "Right" else "Left") .. "1")
	if not own or not own:IsA("BasePart") or not opposite or not opposite:IsA("BasePart") then
		return nil
	end
	local offset = opposite.Position - own.Position
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	return if horizontal.Magnitude > 0.01 then horizontal.Unit else nil
end

local function isOwnerInRange(self: PlacedIncubatorServer, player: Player): boolean
	if player ~= self.owner or player.Parent ~= Players or self.destroyed or not self.model.Parent then
		return false
	end
	local plotService = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = plotService:getPlot(player)
	if not plot or plot.model ~= self.plotModel or plot:getOwner() ~= player then
		return false
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local surface = self.prompt.Parent :: BasePart
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - surface.Position).Magnitude <= 10
end

function PlacedIncubatorServer.new(owner: Player, plotModel: Model, model: Model, instanceId: string): PlacedIncubatorServer?
	local surface = model:FindFirstChild("InsideFloor", true)
	if not surface or not surface:IsA("BasePart") then
		surface = model.PrimaryPart
	end
	if not surface or not surface:IsA("BasePart") then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlaceEggPrompt"
	prompt.ActionText = "Place Egg"
	prompt.ObjectText = "Incubator"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = surface

	local self = setmetatable({
		owner = owner,
		plotModel = plotModel,
		model = model,
		instanceId = instanceId,
		prompt = prompt,
		hatchPrompt = nil :: ProximityPrompt?,
		eggInstanceId = nil :: string?,
		eggId = nil :: string?,
		hatchAtUnixMs = nil :: number?,
		visual = nil :: Model?,
		destroyed = false,
		hatchNowPending = false,
	}, PlacedIncubatorServer) :: PlacedIncubatorServer

	prompt.Triggered:Connect(function(player)
		if self.eggInstanceId or not isOwnerInRange(self, player) then
			return
		end
		-- Set occupancy before creating the visual or scheduling a timer.
		local eggInstanceId, eggId, hatchAtUnixMs = inventoryService():startIncubation(player, instanceId)
		if not eggInstanceId or not eggId or not hatchAtUnixMs then
			return
		end
		self:occupy(eggInstanceId, eggId, hatchAtUnixMs)
		TutorialServiceServer:eggIncubated(player, eggInstanceId)
		if self.model:GetAttribute("ItemId") == "Incubator.InstantHatch" then
			local completed, crabId, weightGrams = inventoryService():completeIncubation(player, eggInstanceId, instanceId, hatchAtUnixMs)
			if completed then
				TutorialServiceServer:eggOpened(player, eggInstanceId)
				local eggVisual = self.visual
				local eggPivot = if eggVisual then eggVisual:GetPivot() else nil
				local eggScale = if eggVisual then eggVisual:GetScale() else nil
				self:clear()
				if crabId and weightGrams then
					local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
					IncubatorServiceServer:showHatch(player, crabId, weightGrams, eggId, eggPivot, eggScale, moneyPadSide(self), eggInstanceId)
				end
			end
		end
	end)
	return self
end

function PlacedIncubatorServer.showEgg(self: PlacedIncubatorServer, eggId: string, isGiganticEgg: boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local eggs = if assets then assets:FindFirstChild("Eggs") else nil
	local template = if eggs then eggs:FindFirstChild(eggId) else nil
	if not template or not template:IsA("Model") then
		warn("Missing egg model for incubator:", eggId)
		return
	end
	local visual = template:Clone()
	local height = visual:GetExtentsSize().Y
	if height <= 0 then
		visual:Destroy()
		return
	end
	visual:ScaleTo(visual:GetScale() * 2 * (if isGiganticEgg then GiganticEggConfig.VISUAL_SCALE else 1) / height)
	local surface = self.prompt.Parent :: BasePart
	local boxCFrame, boxSize = visual:GetBoundingBox()
	local pivotToBottom = visual:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	visual:PivotTo(surface.CFrame * CFrame.new(0, surface.Size.Y / 2 + pivotToBottom, 0))
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
	visual.Name = "IncubatingEgg"
	visual.Parent = self.model
	self.visual = visual
	local eggPart = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
	if eggPart and eggPart:IsA("BasePart") then
		local hatchPrompt = Instance.new("ProximityPrompt")
		hatchPrompt.Name = "HatchEggPrompt"
		hatchPrompt.ActionText = "Hatch"
		hatchPrompt.ObjectText = if isGiganticEgg then "Gigantic Egg" else "Egg"
		hatchPrompt.KeyboardKeyCode = Enum.KeyCode.E
		hatchPrompt.HoldDuration = 0
		hatchPrompt.MaxActivationDistance = 10
		hatchPrompt.RequiresLineOfSight = false
		hatchPrompt.Enabled = false
		hatchPrompt.Parent = eggPart
		hatchPrompt.Triggered:Connect(function(player)
			local eggInstanceId = self.eggInstanceId
			local hatchAtUnixMs = self.hatchAtUnixMs
			if not eggInstanceId or not hatchAtUnixMs or not hatchPrompt.Enabled or self.hatchNowPending
				or not isOwnerInRange(self, player)
				or DateTime.now().UnixTimestampMillis < hatchAtUnixMs then
				return
			end
			local completed, crabId, weightGrams = inventoryService():completeIncubation(player, eggInstanceId, self.instanceId, hatchAtUnixMs)
			if completed then
				TutorialServiceServer:eggOpened(player, eggInstanceId)
				local hatchedEggId = self.eggId
				local eggVisual = self.visual
				local eggPivot = if eggVisual then eggVisual:GetPivot() else nil
				local eggScale = if eggVisual then eggVisual:GetScale() else nil
				self:clear()
				if crabId and weightGrams then
					local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
					IncubatorServiceServer:showHatch(player, crabId, weightGrams, hatchedEggId, eggPivot, eggScale, moneyPadSide(self), eggInstanceId)
				end
			end
		end)
		self.hatchPrompt = hatchPrompt
		if canOfferHatchNow(self, eggId) then
			local hatchNowPrompt = Instance.new("ProximityPrompt")
			hatchNowPrompt.Name = "HatchNowPrompt"
			hatchNowPrompt.ActionText = "Hatch Now"
			hatchNowPrompt.ObjectText = "Incubating Egg"
			hatchNowPrompt.KeyboardKeyCode = Enum.KeyCode.F
			hatchNowPrompt.HoldDuration = 0
			hatchNowPrompt.MaxActivationDistance = 10
			hatchNowPrompt.RequiresLineOfSight = false
			hatchNowPrompt.Enabled = true
			hatchNowPrompt.Parent = eggPart
			hatchNowPrompt.Triggered:Connect(function(player)
				if self.eggInstanceId and self.hatchAtUnixMs and DateTime.now().UnixTimestampMillis < self.hatchAtUnixMs then
					local service = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
					service:prepareHatchNow(player, self.instanceId, self.eggInstanceId, self.hatchAtUnixMs)
				end
			end)
		end
	end
end

function PlacedIncubatorServer.canStartHatchNow(self: PlacedIncubatorServer, player: Player, eggId: string, hatchAt: number): boolean
	return not self.destroyed and self.eggInstanceId == eggId and self.hatchAtUnixMs == hatchAt
		and self.eggId ~= nil and canOfferHatchNow(self, self.eggId)
		and DateTime.now().UnixTimestampMillis < hatchAt and not self.hatchNowPending and isOwnerInRange(self, player)
end

function PlacedIncubatorServer.setHatchNowPending(self: PlacedIncubatorServer, pending: boolean)
	self.hatchNowPending = pending
	if self.hatchPrompt then self.hatchPrompt.Enabled = not pending and (self.hatchAtUnixMs ~= nil and DateTime.now().UnixTimestampMillis >= self.hatchAtUnixMs) end
end

function PlacedIncubatorServer:canCompleteHatchNow(eggId: string, hatchAt: number): boolean
	return not self.destroyed and self.eggInstanceId == eggId and self.hatchAtUnixMs == hatchAt
end

function PlacedIncubatorServer:completeHatchNow(): (string?, number?, string?, CFrame?, number?, Vector3?)
	local player, eggInstanceId, hatchAtUnixMs = self.owner, self.eggInstanceId, self.hatchAtUnixMs
	if not eggInstanceId or not hatchAtUnixMs then return nil end
	local eggId = self.eggId
	local visual = self.visual
	local pivot = if visual then visual:GetPivot() else nil
	local scale = if visual then visual:GetScale() else nil
	local direction = moneyPadSide(self)
	local completed, crabId, weight = inventoryService():completeIncubation(player, eggInstanceId, self.instanceId, hatchAtUnixMs, true)
	if not completed then return nil end
	TutorialServiceServer:eggOpened(player, eggInstanceId)
	self:clear()
	return crabId, weight, eggId, pivot, scale, direction
end

function PlacedIncubatorServer.clear(self: PlacedIncubatorServer)
	self.hatchNowPending = false
	if self.visual then
		self.visual:Destroy()
		self.visual = nil
	end
	self.hatchPrompt = nil
	self.eggInstanceId = nil
	self.eggId = nil
	self.hatchAtUnixMs = nil
	self.model:SetAttribute("IncubatingEggId", nil)
	self.model:SetAttribute("IncubatingHatchAtUnixMs", nil)
	self.prompt.Enabled = not self.destroyed
end

function PlacedIncubatorServer.occupy(self: PlacedIncubatorServer, eggInstanceId: string, eggId: string, hatchAtUnixMs: number)
	if self.destroyed or self.eggInstanceId then
		return
	end
	self.eggInstanceId = eggInstanceId
	self.eggId = eggId
	self.hatchAtUnixMs = hatchAtUnixMs
	self.model:SetAttribute("IncubatingEggId", eggInstanceId)
	self.model:SetAttribute("IncubatingHatchAtUnixMs", hatchAtUnixMs)
	self.prompt.Enabled = false
	local data = Data[self.owner]
	local item = if data then (data.inventory() :: { [string]: SavedItem })[eggInstanceId] else nil
	self:showEgg(eggId, item ~= nil and item.isGiganticEgg == true)
	local function finish()
		if self.destroyed or self.eggInstanceId ~= eggInstanceId or self.hatchAtUnixMs ~= hatchAtUnixMs then
			return
		end
		local remaining = (hatchAtUnixMs - DateTime.now().UnixTimestampMillis) / 1000
		if remaining > 0 then
			task.delay(remaining, finish)
			return
		end
		if self.hatchPrompt then
			self.hatchPrompt.Enabled = not self.hatchNowPending
		end
	end
	task.delay(math.max(0, (hatchAtUnixMs - DateTime.now().UnixTimestampMillis) / 1000), finish)
end

function PlacedIncubatorServer.restore(self: PlacedIncubatorServer)
	if self.destroyed or self.owner.Parent ~= Players then
		return
	end
	local inventory = Data[self.owner].inventory() :: { [string]: SavedItem }
	local instanceIds = {}
	for instanceId, item in inventory do
		if typeof(item) == "table" and item.incubatorInstanceId == self.instanceId then
			table.insert(instanceIds, instanceId)
		end
	end
	table.sort(instanceIds)
	for _, eggInstanceId in instanceIds do
		local item = inventory[eggInstanceId]
		local eggId = string.match(item.itemId, "^Egg%.([%w_]+)$")
		if eggId and typeof(item.hatchAtUnixMs) == "number" then
			self:occupy(eggInstanceId, eggId, item.hatchAtUnixMs :: number)
			break
		end
	end
end

function PlacedIncubatorServer.destroy(self: PlacedIncubatorServer)
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.prompt:Destroy()
	if self.visual then
		self.visual:Destroy()
		self.visual = nil
	end
end

return PlacedIncubatorServer
