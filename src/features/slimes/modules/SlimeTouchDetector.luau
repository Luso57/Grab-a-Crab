local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer
local HORIZONTAL_PADDING = 1
local VERTICAL_PADDING = 2
local EXIT_HYSTERESIS = 0.35

type DetectorEntry = {
	centerOffset: Vector3,
	horizontalRadius: number,
	verticalRange: number,
	inside: boolean,
	onEntered: () -> (),
	anchorPart: BasePart,
}

local TouchHandle = {}
TouchHandle.__index = TouchHandle

export type TouchHandle = typeof(setmetatable(
	{} :: {
		entryId: number,
		cancelled: boolean,
	},
	TouchHandle
))

local entries: { [number]: DetectorEntry } = {}
local nextEntryId = 0
local heartbeatConnection: RBXScriptConnection? = nil

local function getCharacterRoot(): BasePart?
	local character = LOCAL_PLAYER.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	return if rootPart and rootPart:IsA("BasePart") then rootPart else nil
end

local function stopHeartbeatIfUnused()
	if next(entries) == nil and heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function step()
	local characterRoot = getCharacterRoot()

	for _, entry in entries do
		if not characterRoot then
			entry.inside = false
			continue
		end

		local slimeCenter = entry.anchorPart.CFrame:PointToWorldSpace(entry.centerOffset)

		local offset = characterRoot.Position - slimeCenter
		local horizontalDistance = Vector2.new(offset.X, offset.Z).Magnitude
		local activeRadius = entry.horizontalRadius + (if entry.inside then EXIT_HYSTERESIS else 0)
		local isInside = horizontalDistance <= activeRadius
			and math.abs(offset.Y) <= entry.verticalRange

		if isInside and not entry.inside then
			task.spawn(entry.onEntered)
		end

		entry.inside = isInside
	end
end

local function startHeartbeat()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(step)
end

function TouchHandle.cancel(self: TouchHandle)
	if self.cancelled then
		return
	end

	self.cancelled = true
	entries[self.entryId] = nil
	stopHeartbeatIfUnused()
end

local SlimeTouchDetector = {}

function SlimeTouchDetector.watch(model: Model, onEntered: () -> ()): TouchHandle
	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	local anchorPart = model:FindFirstChildWhichIsA("BasePart", true)
	assert(anchorPart, "Collectible slime model must contain a BasePart")
	local horizontalRadius = math.max(boundingBoxSize.X, boundingBoxSize.Z) / 2 + HORIZONTAL_PADDING
	nextEntryId += 1

	entries[nextEntryId] = {
		centerOffset = anchorPart.CFrame:PointToObjectSpace(boundingBoxCFrame.Position),
		horizontalRadius = horizontalRadius,
		verticalRange = boundingBoxSize.Y / 2 + VERTICAL_PADDING,
		inside = false,
		onEntered = onEntered,
		anchorPart = anchorPart,
	}

	local handle = setmetatable({
		entryId = nextEntryId,
		cancelled = false,
	}, TouchHandle)

	startHeartbeat()
	return handle
end

return SlimeTouchDetector
