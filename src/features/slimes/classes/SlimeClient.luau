local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local SlimeSlice = require(ReplicatedStorage.Source.Features.Slimes.SlimeSlice)
local SlimeMovement = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMovement)
local SlimeTouchDetector = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeTouchDetector)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

type SlimeData = DataTemplate.SlimeData

local SlimeClient = {}
SlimeClient.__index = SlimeClient

local ROTATION_SPEED = math.rad(25)
local COLLECTION_SOUND_ID = "rbxassetid://128847265647261"
local COLLECTION_SOUND_LIFETIME = 10

export type SlimeClient = typeof(setmetatable(
	{} :: {
		slimeData: SlimeData,
		model: Model,
		rootPart: BasePart,
		isLocalPlayer: boolean,
		sliceEntryId: string,
		rotationConnection: RBXScriptConnection?,
		activeMovement: SlimeMovement.MovementHandle?,
		touchHandle: SlimeTouchDetector.TouchHandle?,
		onBought: () -> (),
	},
	SlimeClient
))

local function getSpawnPivot(spawner: BasePart, slimeModel: Model): CFrame
	local modelPivot = slimeModel:GetPivot()
	local boundingBoxCFrame, boundingBoxSize = slimeModel:GetBoundingBox()
	local boundingBoxToPivot = boundingBoxCFrame:ToObjectSpace(modelPivot)

	local surfaceOffset = spawner.Size.X / 2 + boundingBoxSize.Y / 2
	local position = spawner.Position + spawner.CFrame.RightVector * surfaceOffset
	local targetBoundingBox = CFrame.new(position) * boundingBoxCFrame.Rotation

	return targetBoundingBox * boundingBoxToPivot
end

local function prepareModel(slimeData: SlimeData): (Model, BasePart)
	local model = Slimes.getSlimeModel(slimeData.slimeId)
	local rootPart = model:FindFirstChildWhichIsA("BasePart", true)
	assert(rootPart, `Slime model has no BaseParts: {slimeData.slimeId}`)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	return model, rootPart
end

local function addStatsAttachment(
	rootPart: BasePart,
	model: Model,
	slimeData: SlimeData,
	billboardType: "purchase" | "playpen"
): (string, Attachment)
	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position + boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2)

	local statsAttachment = Instance.new("Attachment")
	statsAttachment.Name = "StatsAttachment"
	statsAttachment.Position = rootPart.CFrame:PointToObjectSpace(topPosition)
	statsAttachment.Parent = rootPart

	return SlimeSlice.actions.addSlime(
		statsAttachment,
		slimeData.slimeId,
		billboardType,
		slimeData.instanceId,
		slimeData.storedSlime
	), statsAttachment
end

function SlimeClient.new(
	slimeData: SlimeData,
	spawner: BasePart,
	isLocalPlayer: boolean,
	startingRotation: number?
): SlimeClient
	local model, rootPart = prepareModel(slimeData)

	model:PivotTo(getSpawnPivot(spawner, model))
	model.Parent = spawner.Parent
	local sliceEntryId = addStatsAttachment(rootPart, model, slimeData, "purchase")

	local self = setmetatable({
		slimeData = slimeData,
		model = model,
		rootPart = rootPart,
		isLocalPlayer = isLocalPlayer,
		sliceEntryId = sliceEntryId,
		rotationConnection = nil,
		activeMovement = nil,
		touchHandle = nil,
		onBought = function() end,
	}, SlimeClient)

	local basePivot = model:GetPivot()
	local rotation = startingRotation or 0
	model:PivotTo(basePivot * CFrame.Angles(0, rotation, 0))

	self.rotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		rotation = (rotation + ROTATION_SPEED * deltaTime) % (2 * math.pi)
		model:PivotTo(basePivot * CFrame.Angles(0, rotation, 0))
	end)

	if self.isLocalPlayer then
		local highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.Enabled = false
		highlight.Parent = self.model

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 14
		prompt.HoldDuration = 0.4
		prompt.Parent = rootPart

		prompt.PromptShown:Connect(function()
			highlight.Enabled = true
		end)

		prompt.PromptHidden:Connect(function()
			highlight.Enabled = false
		end)

		prompt.Triggered:Connect(function()
			self.onBought()
		end)
	end

	return self
end

function SlimeClient.newPlaypenSlime(
	slimeData: SlimeData,
	playpenBase: BasePart,
	onTouched: (() -> ())?
): SlimeClient
	local model, rootPart = prepareModel(slimeData)
	local sliceEntryId, statsAttachment = addStatsAttachment(rootPart, model, slimeData, "playpen")

	local self = setmetatable({
		slimeData = slimeData,
		model = model,
		rootPart = rootPart,
		isLocalPlayer = false,
		sliceEntryId = sliceEntryId,
		rotationConnection = nil,
		activeMovement = nil,
		touchHandle = nil,
		onBought = function() end,
	}, SlimeClient)

	self.activeMovement = SlimeMovement.play(model, playpenBase, statsAttachment)
	if onTouched then
		self.touchHandle = SlimeTouchDetector.watch(model, onTouched)
	end

	return self
end

function SlimeClient.setStoredSlime(self: SlimeClient, amount: number)
	self.slimeData.storedSlime = amount
	SlimeSlice.actions.setStoredSlime(self.sliceEntryId, amount)
end

function SlimeClient.playCollectionSound(self: SlimeClient)
	local sound = Instance.new("Sound")
	sound.Name = "SlimeCollected"
	sound.SoundId = COLLECTION_SOUND_ID
	sound.Volume = 0.7
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 5
	sound.RollOffMaxDistance = 35
	sound.Parent = self.rootPart

	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, COLLECTION_SOUND_LIFETIME)
	sound:Play()
end

function SlimeClient.destroy(self: SlimeClient)
	if self.rotationConnection then
		self.rotationConnection:Disconnect()
		self.rotationConnection = nil
	end

	if self.activeMovement then
		self.activeMovement:cancel()
		self.activeMovement = nil
	end

	if self.touchHandle then
		self.touchHandle:cancel()
		self.touchHandle = nil
	end

	SlimeSlice.actions.removeSlime(self.sliceEntryId)
	self.model:Destroy()
end

return SlimeClient
