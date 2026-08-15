local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlimeMovement = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMovement)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)
local Config = require(ReplicatedStorage.Source.Features.Slimeevent.SlimeEventConfig)

local EVENT_SLIME_NAME = "EventSlime"
local MOVEMENT_AREA_NAME = "EventSlimeMovementArea"
local MOVEMENT_AREA_HEIGHT = 0.05
local INSCRIBED_RECTANGLE_SCALE = 1 / math.sqrt(2)

local EventSlimeHandle = {}
EventSlimeHandle.__index = EventSlimeHandle

export type EventSlimeHandle = typeof(setmetatable(
	{} :: {
		model: Model,
		movementArea: BasePart,
		movement: SlimeMovement.MovementHandle?,
		movementAttachment: Attachment,
		prompt: ProximityPrompt,
		highlight: Highlight,
		carryRoot: BasePart?,
		carryWeld: WeldConstraint?,
		originalMassless: { [BasePart]: boolean },
	},
	EventSlimeHandle
))

local EventSlimeSpawner = {}

local RARITY_RANK: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Exotic = 6,
	Secret = 7,
}

local function getEventSlimeId(random: Random): string
	local minimumRank = RARITY_RANK[Config.EventMinimumRarity]
	assert(minimumRank, `Invalid event minimum rarity: {Config.EventMinimumRarity}`)

	local eligibleIds = {}
	local totalWeight = 0
	for _, slimeId in Slimes.slimeIds do
		local info = Slimes.getSlimeInfo(slimeId)
		if (RARITY_RANK[info.rarity] or 0) >= minimumRank then
			local weight = 1 / info.chance
			totalWeight += weight
			table.insert(eligibleIds, { id = slimeId, weight = weight })
		end
	end
	assert(#eligibleIds > 0 and totalWeight > 0, "Event slime pool has no eligible slimes")

	local roll = random:NextNumber() * totalWeight
	local cumulativeWeight = 0
	for _, entry in eligibleIds do
		cumulativeWeight += entry.weight
		if roll <= cumulativeWeight then return entry.id end
	end
	return eligibleIds[#eligibleIds].id
end

local function createMovementArea(surface: BasePart): BasePart
	local existing = surface.Parent:FindFirstChild(MOVEMENT_AREA_NAME)
	if existing then existing:Destroy() end

	local surfaceNormal = surface.CFrame.RightVector
	local movementArea = Instance.new("Part")
	movementArea.Name = MOVEMENT_AREA_NAME
	movementArea.Anchored = true
	movementArea.CanCollide = false
	movementArea.CanQuery = false
	movementArea.CanTouch = false
	movementArea.CastShadow = false
	movementArea.Transparency = 1
	movementArea.Size = Vector3.new(
		surface.Size.Y * INSCRIBED_RECTANGLE_SCALE,
		MOVEMENT_AREA_HEIGHT,
		surface.Size.Z * INSCRIBED_RECTANGLE_SCALE
	)
	movementArea.CFrame = CFrame.fromMatrix(
		surface.Position + surfaceNormal * (surface.Size.X / 2 + MOVEMENT_AREA_HEIGHT / 2),
		surface.CFrame.UpVector,
		surfaceNormal,
		surface.CFrame.LookVector
	)
	movementArea.Parent = surface.Parent

	return movementArea
end

local function prepareSlimeModel(
	slimeId: string,
	mutationId: string
): (Model, BasePart, Attachment, ProximityPrompt, Highlight)
	local model = Slimes.getSlimeModel(slimeId)
	model.Name = EVENT_SLIME_NAME
	model:SetAttribute("SlimeId", slimeId)
	model:SetAttribute("MutationId", mutationId)

	local rootPart: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not rootPart or descendant.Size.X * descendant.Size.Y * descendant.Size.Z > rootPart.Size.X * rootPart.Size.Y * rootPart.Size.Z then
				rootPart = descendant
			end
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	assert(rootPart, `Event slime model has no BaseParts: {slimeId}`)

	local movementAttachment = Instance.new("Attachment")
	movementAttachment.Name = "MovementAttachment"
	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position + boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2)
	movementAttachment.Position = rootPart.CFrame:PointToObjectSpace(topPosition)
	movementAttachment.Parent = rootPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CarryPrompt"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = "Slime"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.PickupHoldDuration
	prompt.MaxActivationDistance = Config.PickupDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = rootPart

	local highlight = Instance.new("Highlight")
	highlight.Name = "CarryHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.Enabled = false
	highlight.Parent = model

	model:SetAttribute(Config.CarrierAttribute, 0)
	return model, rootPart, movementAttachment, prompt, highlight
end

function EventSlimeHandle.stopMovement(self: EventSlimeHandle)
	if self.movement then
		self.movement:cancel()
		self.movement = nil
	end
end

function EventSlimeHandle.clearCarryAttachment(self: EventSlimeHandle)
	if self.carryWeld then
		self.carryWeld:Destroy()
		self.carryWeld = nil
	end

	for part, wasMassless in self.originalMassless do
		if part.Parent then
			part.Anchored = true
			part.Massless = wasMassless
		end
	end
	table.clear(self.originalMassless)

	if self.carryRoot then
		self.carryRoot:Destroy()
		self.carryRoot = nil
	end
end

function EventSlimeHandle.startMovement(self: EventSlimeHandle)
	self:clearCarryAttachment()
	self.model:SetAttribute(Config.CarrierAttribute, 0)
	self.prompt.ActionText = "Pick Up"
	self.prompt.Enabled = true
	self:stopMovement()
	self.movement = SlimeMovement.play(self.model, self.movementArea, self.movementAttachment)
end

function EventSlimeHandle.carry(self: EventSlimeHandle, player: Player, character: Model)
	self:stopMovement()
	self:clearCarryAttachment()

	local head = character:FindFirstChild("Head")
	local upperTorso = character:FindFirstChild("UpperTorso")
	assert(head and head:IsA("BasePart"), "Carrier character has no Head")
	assert(upperTorso and upperTorso:IsA("BasePart"), "Carrier character has no UpperTorso")
	local boundingBox, boundingSize = self.model:GetBoundingBox()
	local boundingBoxToPivot = boundingBox:ToObjectSpace(self.model:GetPivot())
	local targetBox = CFrame.new(head.Position)
		* upperTorso.CFrame.Rotation
		* CFrame.new(0, head.Size.Y / 2 + boundingSize.Y / 2 + Config.CarryHeadClearance, 0)
	self.model:PivotTo(targetBox * boundingBoxToPivot)

	local carryRoot = Instance.new("Part")
	carryRoot.Name = "CarryRoot"
	carryRoot.Size = Vector3.new(0.2, 0.2, 0.2)
	carryRoot.Transparency = 1
	carryRoot.Anchored = true
	carryRoot.CanCollide = false
	carryRoot.CanQuery = false
	carryRoot.CanTouch = false
	carryRoot.CastShadow = false
	carryRoot.Massless = true
	carryRoot.CFrame = self.model:GetPivot()
	carryRoot.Parent = self.model
	self.carryRoot = carryRoot

	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= carryRoot then
			self.originalMassless[descendant] = descendant.Massless
			local weld = Instance.new("WeldConstraint")
			weld.Name = "SlimeCarryPartWeld"
			weld.Part0 = carryRoot
			weld.Part1 = descendant
			weld.Parent = carryRoot
			descendant.Anchored = false
			descendant.Massless = true
		end
	end

	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Name = "SlimeCarryCharacterWeld"
	carryWeld.Part0 = upperTorso
	carryWeld.Part1 = carryRoot
	carryWeld.Parent = carryRoot
	self.carryWeld = carryWeld
	carryRoot.Anchored = false
	pcall(function() carryRoot:SetNetworkOwner(player) end)

	self.model:SetAttribute(Config.CarrierAttribute, player.UserId)
	self.prompt.Enabled = false
end

function EventSlimeHandle.returnToBoard(self: EventSlimeHandle)
	self:startMovement()
end

function EventSlimeHandle.destroy(self: EventSlimeHandle)
	self:stopMovement()
	self:clearCarryAttachment()
	self.model:Destroy()
	self.movementArea:Destroy()
end

function EventSlimeSpawner.spawn(surface: BasePart, random: Random?, mutationId: string?): EventSlimeHandle
	local parent = surface.Parent
	local existingSlime = parent:FindFirstChild(EVENT_SLIME_NAME)
	if existingSlime then existingSlime:Destroy() end

	local movementArea = createMovementArea(surface)
	local slimeId = getEventSlimeId(random or Random.new())
	local model, _, movementAttachment, prompt, highlight = prepareSlimeModel(slimeId, mutationId or "normal")
	local movement = SlimeMovement.play(model, movementArea, movementAttachment)

	return setmetatable({
		model = model,
		movementArea = movementArea,
		movement = movement,
		movementAttachment = movementAttachment,
		prompt = prompt,
		highlight = highlight,
		carryRoot = nil,
		carryWeld = nil,
		originalMassless = {},
	}, EventSlimeHandle)
end

return EventSlimeSpawner
