--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server

type SavedItem = {
	itemId: string,
	incubatorInstanceId: string?,
	hatchAtUnixMs: number?,
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
	hatchAtUnixMs: number?,
	visual: Model?,
	destroyed: boolean,
}, PlacedIncubatorServer))

local function inventoryService()
	return require(ServerScriptService.Features.Inventory.InventoryServiceServer)
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
		hatchAtUnixMs = nil :: number?,
		visual = nil :: Model?,
		destroyed = false,
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
	end)
	return self
end

function PlacedIncubatorServer.showEgg(self: PlacedIncubatorServer, eggId: string)
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
	visual:ScaleTo(visual:GetScale() * 2 / height)
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
		hatchPrompt.ObjectText = "Egg"
		hatchPrompt.KeyboardKeyCode = Enum.KeyCode.E
		hatchPrompt.HoldDuration = 0
		hatchPrompt.MaxActivationDistance = 10
		hatchPrompt.RequiresLineOfSight = false
		hatchPrompt.Enabled = false
		hatchPrompt.Parent = eggPart
		hatchPrompt.Triggered:Connect(function(player)
			local eggInstanceId = self.eggInstanceId
			local hatchAtUnixMs = self.hatchAtUnixMs
			if not eggInstanceId or not hatchAtUnixMs or not hatchPrompt.Enabled
				or not isOwnerInRange(self, player)
				or DateTime.now().UnixTimestampMillis < hatchAtUnixMs then
				return
			end
			if inventoryService():completeIncubation(player, eggInstanceId, self.instanceId, hatchAtUnixMs) then
				self:clear()
			end
		end)
		self.hatchPrompt = hatchPrompt
	end
end

function PlacedIncubatorServer.clear(self: PlacedIncubatorServer)
	if self.visual then
		self.visual:Destroy()
		self.visual = nil
	end
	self.hatchPrompt = nil
	self.eggInstanceId = nil
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
	self.hatchAtUnixMs = hatchAtUnixMs
	self.model:SetAttribute("IncubatingEggId", eggInstanceId)
	self.model:SetAttribute("IncubatingHatchAtUnixMs", hatchAtUnixMs)
	self.prompt.Enabled = false
	self:showEgg(eggId)
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
			self.hatchPrompt.Enabled = true
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
