local RunService = game:GetService("RunService")

local PLAYPEN_MIN_PAUSE = 0.5
local PLAYPEN_MAX_PAUSE = 2
local PLAYPEN_TURN_DURATION = 0.25
local PLAYPEN_FACING_OFFSET = 0
local PLAYPEN_HOP_DISTANCE = 3
local PLAYPEN_HOP_SPEED = 5
local PLAYPEN_ANTICIPATION_DURATION = 0.12
local PLAYPEN_LANDING_DURATION = 0.16
local PLAYPEN_ANTICIPATION_VERTICAL_SCALE = 0.88
local PLAYPEN_ANTICIPATION_HORIZONTAL_SCALE = 1.06
local PLAYPEN_AIR_VERTICAL_SCALE = 1.08
local PLAYPEN_AIR_HORIZONTAL_SCALE = 0.96
local PLAYPEN_LANDING_VERTICAL_SCALE = 0.86
local PLAYPEN_LANDING_HORIZONTAL_SCALE = 1.07
local JUMP_SOUND_ID = "rbxassetid://109872799119131"
local JUMP_SOUND_MAX_DISTANCE = 35

type DeformPart = {
	part: BasePart,
	size: Vector3,
	relativeCFrame: CFrame,
}

type PlaypenPlacement = {
	boundingBoxSize: Vector3,
	boundingBoxToPivot: CFrame,
}

local MovementHandle = {}
MovementHandle.__index = MovementHandle

export type MovementHandle = typeof(setmetatable(
	{} :: {
		connection: RBXScriptConnection?,
		jumpSound: Sound,
		cancelled: boolean,
	},
	MovementHandle
))

local SlimeMovement = {}

local function getDeformParts(model: Model, pivot: CFrame): { DeformPart }
	local deformParts = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(deformParts, {
				part = descendant,
				size = descendant.Size,
				relativeCFrame = pivot:ToObjectSpace(descendant.CFrame),
			})
		end
	end

	return deformParts
end

local function applyDeformation(
	deformParts: { DeformPart },
	displayedPivot: CFrame,
	horizontalScale: number,
	verticalScale: number
)
	for _, entry in deformParts do
		local originalPosition = entry.relativeCFrame.Position
		local scaledPosition = Vector3.new(
			originalPosition.X * horizontalScale,
			originalPosition.Y * verticalScale,
			originalPosition.Z * horizontalScale
		)

		entry.part.Size = Vector3.new(
			math.max(0.05, entry.size.X * horizontalScale),
			math.max(0.05, entry.size.Y * verticalScale),
			math.max(0.05, entry.size.Z * horizontalScale)
		)
		entry.part.CFrame = displayedPivot * CFrame.new(scaledPosition) * entry.relativeCFrame.Rotation
	end
end

local function getPlaypenPlacement(slimeModel: Model): PlaypenPlacement
	local modelPivot = slimeModel:GetPivot()
	local boundingBoxCFrame, boundingBoxSize = slimeModel:GetBoundingBox()

	return {
		boundingBoxSize = boundingBoxSize,
		boundingBoxToPivot = boundingBoxCFrame:ToObjectSpace(modelPivot),
	}
end

local function getRandomPlaypenPivot(playpenBase: BasePart, placement: PlaypenPlacement, random: Random): CFrame
	local boundingBoxSize = placement.boundingBoxSize
	local horizontalRadius = math.max(boundingBoxSize.X, boundingBoxSize.Z) / 2
	local maxX = math.max(0, playpenBase.Size.X / 2 - horizontalRadius)
	local maxZ = math.max(0, playpenBase.Size.Z / 2 - horizontalRadius)
	local x = if maxX > 0 then random:NextNumber(-maxX, maxX) else 0
	local z = if maxZ > 0 then random:NextNumber(-maxZ, maxZ) else 0
	local y = playpenBase.Size.Y / 2 + boundingBoxSize.Y / 2
	local targetBoundingBox = playpenBase.CFrame * CFrame.new(x, y, z)

	return targetBoundingBox * placement.boundingBoxToPivot
end

local function getFacingPivot(currentPivot: CFrame, targetPosition: Vector3, upVector: Vector3): CFrame
	local direction = targetPosition - currentPivot.Position
	local flatDirection = direction - upVector * direction:Dot(upVector)

	if flatDirection.Magnitude < 0.001 then
		return currentPivot
	end

	return CFrame.lookAt(currentPivot.Position, currentPivot.Position + flatDirection, upVector)
		* CFrame.Angles(0, PLAYPEN_FACING_OFFSET, 0)
end

local function easeInOut(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

function MovementHandle.cancel(self: MovementHandle)
	if self.cancelled then
		return
	end

	self.cancelled = true
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	self.jumpSound:Destroy()
end

function SlimeMovement.play(model: Model, playpenBase: BasePart, statsAttachment: Attachment): MovementHandle
	local random = Random.new()
	local placement = getPlaypenPlacement(model)
	local spawnPivot = getRandomPlaypenPivot(playpenBase, placement, random)
	model:PivotTo(spawnPivot)
	model.Parent = playpenBase.Parent

	local deformParts = getDeformParts(model, spawnPivot)
	local statsAttachmentPosition = statsAttachment.Position
	local jumpSound = Instance.new("Sound")
	jumpSound.Name = "SlimeJump"
	jumpSound.SoundId = JUMP_SOUND_ID
	jumpSound.Volume = 0.5
	jumpSound.RollOffMode = Enum.RollOffMode.InverseTapered
	jumpSound.RollOffMinDistance = 5
	jumpSound.RollOffMaxDistance = JUMP_SOUND_MAX_DISTANCE
	jumpSound.Parent = statsAttachment
	local hopHeight = math.clamp(placement.boundingBoxSize.Y * 0.18, 0.3, 0.75)
	local handle = setmetatable({
		connection = nil,
		jumpSound = jumpSound,
		cancelled = false,
	}, MovementHandle)

	local state = "paused"
	local logicalPivot = spawnPivot
	local phaseStartPivot = spawnPivot
	local phaseTargetPivot = spawnPivot
	local destinationPosition = spawnPivot.Position
	local currentHopHeight = hopHeight
	local elapsed = 0
	local duration = PLAYPEN_TURN_DURATION
	local pauseRemaining = random:NextNumber(PLAYPEN_MIN_PAUSE, PLAYPEN_MAX_PAUSE)

	local function startHop()
		local remaining = destinationPosition - logicalPivot.Position
		if remaining.Magnitude <= 0.05 then
			pauseRemaining = random:NextNumber(PLAYPEN_MIN_PAUSE, PLAYPEN_MAX_PAUSE)
			state = "paused"
			return
		end

		local hopDistance = math.min(PLAYPEN_HOP_DISTANCE, remaining.Magnitude)
		local hopPosition = logicalPivot.Position + remaining.Unit * hopDistance
		phaseStartPivot = logicalPivot
		phaseTargetPivot = CFrame.new(hopPosition) * logicalPivot.Rotation
		currentHopHeight = hopHeight * math.clamp(hopDistance / PLAYPEN_HOP_DISTANCE, 0.45, 1)
		elapsed = 0
		duration = PLAYPEN_ANTICIPATION_DURATION
		state = "anticipating"
	end

	local function startTurning()
		destinationPosition = getRandomPlaypenPivot(playpenBase, placement, random).Position
		phaseStartPivot = logicalPivot
		phaseTargetPivot = getFacingPivot(logicalPivot, destinationPosition, playpenBase.CFrame.UpVector)
		elapsed = 0
		duration = PLAYPEN_TURN_DURATION
		state = "turning"
	end

	handle.connection = RunService.RenderStepped:Connect(function(deltaTime)
		local displayedPivot = logicalPivot
		local horizontalScale = 1
		local verticalScale = 1

		if state == "paused" then
			pauseRemaining -= deltaTime
			if pauseRemaining <= 0 then
				startTurning()
			end
		elseif state == "turning" then
			elapsed += deltaTime
			local alpha = math.min(1, elapsed / duration)
			logicalPivot = phaseStartPivot:Lerp(phaseTargetPivot, easeInOut(alpha))
			displayedPivot = logicalPivot

			if alpha >= 1 then
				logicalPivot = phaseTargetPivot
				startHop()
			end
		elseif state == "anticipating" then
			elapsed += deltaTime
			local alpha = easeInOut(math.min(1, elapsed / duration))
			verticalScale = 1 + (PLAYPEN_ANTICIPATION_VERTICAL_SCALE - 1) * alpha
			horizontalScale = 1 + (PLAYPEN_ANTICIPATION_HORIZONTAL_SCALE - 1) * alpha

			if elapsed >= duration then
				elapsed = 0
				duration = math.max(
					0.32,
					(phaseTargetPivot.Position - phaseStartPivot.Position).Magnitude / PLAYPEN_HOP_SPEED
				)
				state = "airborne"
				jumpSound.TimePosition = 0
				jumpSound:Play()
			end
		elseif state == "airborne" then
			elapsed += deltaTime
			local alpha = math.min(1, elapsed / duration)
			logicalPivot = phaseStartPivot:Lerp(phaseTargetPivot, alpha)
			local arcHeight = math.sin(math.pi * alpha) * currentHopHeight
			displayedPivot = logicalPivot * CFrame.new(0, arcHeight, 0)

			if alpha <= 0.5 then
				local stretchAlpha = easeInOut(alpha * 2)
				verticalScale = PLAYPEN_ANTICIPATION_VERTICAL_SCALE
					+ (PLAYPEN_AIR_VERTICAL_SCALE - PLAYPEN_ANTICIPATION_VERTICAL_SCALE) * stretchAlpha
				horizontalScale = PLAYPEN_ANTICIPATION_HORIZONTAL_SCALE
					+ (PLAYPEN_AIR_HORIZONTAL_SCALE - PLAYPEN_ANTICIPATION_HORIZONTAL_SCALE) * stretchAlpha
			else
				local landingAlpha = easeInOut((alpha - 0.5) * 2)
				verticalScale = PLAYPEN_AIR_VERTICAL_SCALE
					+ (PLAYPEN_LANDING_VERTICAL_SCALE - PLAYPEN_AIR_VERTICAL_SCALE) * landingAlpha
				horizontalScale = PLAYPEN_AIR_HORIZONTAL_SCALE
					+ (PLAYPEN_LANDING_HORIZONTAL_SCALE - PLAYPEN_AIR_HORIZONTAL_SCALE) * landingAlpha
			end

			if alpha >= 1 then
				logicalPivot = phaseTargetPivot
				displayedPivot = logicalPivot
				elapsed = 0
				duration = PLAYPEN_LANDING_DURATION
				state = "landing"
			end
		elseif state == "landing" then
			elapsed += deltaTime
			local alpha = easeInOut(math.min(1, elapsed / duration))
			verticalScale = PLAYPEN_LANDING_VERTICAL_SCALE + (1 - PLAYPEN_LANDING_VERTICAL_SCALE) * alpha
			horizontalScale = PLAYPEN_LANDING_HORIZONTAL_SCALE
				+ (1 - PLAYPEN_LANDING_HORIZONTAL_SCALE) * alpha

			if elapsed >= duration then
				startHop()
			end
		end

		applyDeformation(deformParts, displayedPivot, horizontalScale, verticalScale)
		statsAttachment.Position = Vector3.new(
			statsAttachmentPosition.X * horizontalScale,
			statsAttachmentPosition.Y * verticalScale,
			statsAttachmentPosition.Z * horizontalScale
		)
	end)

	return handle
end

return SlimeMovement
