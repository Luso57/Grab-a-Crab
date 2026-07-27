local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local SlimeSlice = require(ReplicatedStorage.Source.Features.Slimes.SlimeSlice)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

type SlimeData = DataTemplate.SlimeData

local SlimeClient = {}
SlimeClient.__index = SlimeClient

export type SlimeClient = typeof(setmetatable(
	{} :: {
		slimeData: SlimeData,
		model: Model,
		isLocalPlayer: boolean,
		sliceEntryId: string,
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

function SlimeClient.new(slimeData: SlimeData, spawner: BasePart, isLocalPlayer: boolean): SlimeClient
	local model = Slimes.getSlimeModel(slimeData.slimeId)
	local rootPart = model:FindFirstChildWhichIsA("BasePart", true)
	assert(rootPart, `Slime model has no BaseParts: {slimeData.slimeId}`)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	model:PivotTo(getSpawnPivot(spawner, model))
	model.Parent = spawner.Parent

	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position + boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2)

	local statsAttachment = Instance.new("Attachment")
	statsAttachment.Name = "StatsAttachment"
	statsAttachment.Position = rootPart.CFrame:PointToObjectSpace(topPosition)
	statsAttachment.Parent = rootPart

	local self = setmetatable({
		slimeData = slimeData,
		model = model,
		isLocalPlayer = isLocalPlayer,
		sliceEntryId = SlimeSlice.actions.addSlime(statsAttachment, slimeData.slimeId),
	}, SlimeClient)

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
	end

	return self
end

function SlimeClient.destroy(self: SlimeClient)
	SlimeSlice.actions.removeSlime(self.sliceEntryId)
	self.model:Destroy()
end

return SlimeClient
