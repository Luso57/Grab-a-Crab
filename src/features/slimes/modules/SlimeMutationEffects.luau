local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)

local UPDATE_INTERVAL = 0.5
local MAX_EFFECT_DISTANCE = 140

type EffectHandleInternal = {
	model: Model,
	instances: { Instance },
	emitters: { ParticleEmitter },
	destroyed: boolean,
}

local activeHandles: { [EffectHandleInternal]: boolean } = {}
local updateElapsed = 0

local EffectHandle = {}
EffectHandle.__index = EffectHandle

export type EffectHandle = typeof(setmetatable({} :: EffectHandleInternal, EffectHandle))

local function scaleNumberSequence(sequence: NumberSequence, factor: number): NumberSequence
	local keypoints = {}
	for _, keypoint in sequence.Keypoints do
		table.insert(
			keypoints,
			NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * factor, keypoint.Envelope * factor)
		)
	end
	return NumberSequence.new(keypoints)
end

local function scaleEmitter(emitter: ParticleEmitter, factor: number)
	emitter.Size = scaleNumberSequence(emitter.Size, factor)
	emitter.Speed = NumberRange.new(emitter.Speed.Min * factor, emitter.Speed.Max * factor)
	emitter.Acceleration *= factor
end

local function getReferenceSize(template: Model): Vector3
	return Vector3.new(
		template:GetAttribute("ReferenceSizeX") or 3.5,
		template:GetAttribute("ReferenceSizeY") or 4.24,
		template:GetAttribute("ReferenceSizeZ") or 3.7
	)
end

local function copyVisuals(source: Instance, target: Attachment, sizeScale: number, emitters: { ParticleEmitter })
	for _, child in source:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local clone = child:Clone()
			scaleEmitter(clone, sizeScale)
			clone.Parent = target
			table.insert(emitters, clone)
		elseif child:IsA("PointLight") then
			local clone = child:Clone()
			clone.Range *= sizeScale
			clone.Parent = target
		end
	end
end

local function createRuntimeAttachment(
	rootPart: BasePart,
	targetFrame: CFrame,
	name: string,
	instances: { Instance }
): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = `MutationEffect_{name}`
	attachment.CFrame = rootPart.CFrame:ToObjectSpace(targetFrame)
	attachment.Parent = rootPart
	table.insert(instances, attachment)
	return attachment
end

local function setEnabled(handle: EffectHandleInternal, enabled: boolean)
	for _, emitter in handle.emitters do
		if emitter.Parent then
			emitter.Enabled = enabled
		end
	end
end

function EffectHandle.destroy(self: EffectHandle)
	if self.destroyed then
		return
	end
	self.destroyed = true
	activeHandles[self] = nil
	for _, instance in self.instances do
		instance:Destroy()
	end
	table.clear(self.instances)
	table.clear(self.emitters)
end

local SlimeMutationEffects = {}

function SlimeMutationEffects.apply(model: Model, rootPart: BasePart, mutationId: string?): EffectHandle?
	local mutation = SlimeMutations.get(mutationId)
	if not mutation.effectTemplate then
		return nil
	end

	local effectsFolder = ReplicatedStorage.Assets:WaitForChild("SlimeEffects")
	local template = effectsFolder:WaitForChild(mutation.effectTemplate)
	assert(template:IsA("Model"), `Invalid mutation effect template: {mutation.effectTemplate}`)

	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	local referenceSize = getReferenceSize(template)
	local axisScale = Vector3.new(
		boundingBoxSize.X / math.max(0.01, referenceSize.X),
		boundingBoxSize.Y / math.max(0.01, referenceSize.Y),
		boundingBoxSize.Z / math.max(0.01, referenceSize.Z)
	)
	local sizeScale = math.clamp((axisScale.X + axisScale.Y + axisScale.Z) / 3, 0.45, 2.5)
	local instances = {}
	local emitters = {}

	for _, sourcePart in template:GetChildren() do
		if not sourcePart:IsA("BasePart") then
			continue
		end

		local sourcePosition = sourcePart.CFrame.Position
		local scaledPosition = Vector3.new(
			sourcePosition.X * axisScale.X,
			sourcePosition.Y * axisScale.Y,
			sourcePosition.Z * axisScale.Z
		)
		local partFrame = boundingBoxCFrame * CFrame.new(scaledPosition) * sourcePart.CFrame.Rotation
		local centerAttachment = createRuntimeAttachment(rootPart, partFrame, sourcePart.Name, instances)
		copyVisuals(sourcePart, centerAttachment, sizeScale, emitters)

		for _, sourceAttachment in sourcePart:GetChildren() do
			if sourceAttachment:IsA("Attachment") then
				local localPosition = sourceAttachment.CFrame.Position
				local scaledLocalPosition = Vector3.new(
					localPosition.X * axisScale.X,
					localPosition.Y * axisScale.Y,
					localPosition.Z * axisScale.Z
				)
				local attachmentFrame = partFrame
					* CFrame.new(scaledLocalPosition)
					* sourceAttachment.CFrame.Rotation
				local attachment = createRuntimeAttachment(rootPart, attachmentFrame, sourceAttachment.Name, instances)
				copyVisuals(sourceAttachment, attachment, sizeScale, emitters)
			end
		end
	end

	local handle = setmetatable({
		model = model,
		instances = instances,
		emitters = emitters,
		destroyed = false,
	}, EffectHandle)
	activeHandles[handle] = true
	return handle
end

if RunService:IsClient() then
	RunService.RenderStepped:Connect(function(deltaTime)
		updateElapsed += deltaTime
		if updateElapsed < UPDATE_INTERVAL then
			return
		end
		updateElapsed = 0

		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		for handle in activeHandles do
			if handle.destroyed or not handle.model.Parent then
				handle:destroy()
			else
				local distance = (camera.CFrame.Position - handle.model:GetPivot().Position).Magnitude
				setEnabled(handle, distance <= MAX_EFFECT_DISTANCE)
			end
		end
	end)
end

return SlimeMutationEffects
