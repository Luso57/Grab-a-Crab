--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MAX_ARROW_COUNT = 24
local ARROW_SPACING_STUDS = 5.5
local ARROW_LENGTH = 3.8
local ARROW_WIDTH = 2.8
local BAR_WIDTH = 0.62
local BAR_HEIGHT = 0.1
local ARROW_FLOW_SPEED = 5.5
local BODY_START_DOWN_OFFSET = 0.55
local BODY_START_FORWARD_OFFSET = 0.9

type ArrowEntry = {
	upperBar: Part,
	lowerBar: Part,
}

local TutorialArrowPath = {}

local function makeBar(parent: Folder, name: string): Part
	local bar = Instance.new("Part")
	bar.Name = name
	bar.Size = Vector3.new(1, BAR_HEIGHT, BAR_WIDTH)
	bar.Anchored = true
	bar.CanCollide = false
	bar.CanTouch = false
	bar.CanQuery = false
	bar.CastShadow = false
	bar.Material = Enum.Material.Neon
	bar.Color = Color3.fromRGB(255, 247, 218)
	bar.Transparency = 1
	bar.Parent = parent
	return bar
end

local function setArm(part: Part, from: Vector3, to: Vector3, planeNormal: Vector3)
	local arm = to - from
	if arm.Magnitude < 0.001 then
		return
	end
	local direction = arm.Unit
	local depth = direction:Cross(planeNormal).Unit
	part.Size = Vector3.new(arm.Magnitude, BAR_HEIGHT, BAR_WIDTH)
	part.CFrame = CFrame.fromMatrix((from + to) * 0.5, direction, planeNormal, depth)
end

local function setChevron(arrow: ArrowEntry, center: Vector3, forward: Vector3, length: number, width: number)
	local side = forward:Cross(Vector3.yAxis)
	if side.Magnitude < 0.001 then
		side = forward:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local planeNormal = side:Cross(forward).Unit
	local tip = center + forward * (length * 0.5)
	local back = center - forward * (length * 0.5)
	setArm(arrow.upperBar, back + side * (width * 0.5), tip, planeNormal)
	setArm(arrow.lowerBar, back - side * (width * 0.5), tip, planeNormal)
end

function TutorialArrowPath.mount(_playerGui: PlayerGui): (BasePart?, BasePart?) -> ()
	local folder = Instance.new("Folder")
	folder.Name = "TutorialArrowPathParts"
	folder.Parent = Workspace

	local arrows: { ArrowEntry } = table.create(MAX_ARROW_COUNT)
	for index = 1, MAX_ARROW_COUNT do
		arrows[index] = {
			upperBar = makeBar(folder, `TutorialArrow{index}Upper`),
			lowerBar = makeBar(folder, `TutorialArrow{index}Lower`),
		}
	end

	local origin: BasePart? = nil
	local destination: BasePart? = nil
	local phaseStuds = 0
	local activeArrowCount = 0

	local function hidePath()
		for index = 1, activeArrowCount do
			local arrow = arrows[index]
			arrow.upperBar.Transparency = 1
			arrow.lowerBar.Transparency = 1
		end
		activeArrowCount = 0
	end

	RunService.RenderStepped:Connect(function(dt)
		local from = origin
		local to = destination
		local camera = Workspace.CurrentCamera
		if not camera or not from or not to or not from.Parent or not to.Parent then
			hidePath()
			return
		end

		local endPosition: Vector3
		if to.Name == "InsideFloor" then
			endPosition = to.Position + Vector3.new(0, to.Size.Y * 0.5 + 0.06, 0)
		else
			endPosition = to.Position
		end
		local bodyPosition = from.Position - Vector3.new(0, BODY_START_DOWN_OFFSET, 0)
		local initialDelta = endPosition - bodyPosition
		if initialDelta.Magnitude < 0.1 then
			hidePath()
			return
		end
		local forward = initialDelta.Unit
		local startOffset = math.min(BODY_START_FORWARD_OFFSET, initialDelta.Magnitude * 0.3)
		local startPosition = bodyPosition + forward * startOffset
		local delta = endPosition - startPosition
		local pathLength = delta.Magnitude
		if pathLength < 0.1 then
			hidePath()
			return
		end

		phaseStuds += dt * ARROW_FLOW_SPEED
		local arrowLength = math.min(ARROW_LENGTH, pathLength)
		local centerTravelLength = math.max(pathLength - arrowLength, 0)
		local hasMovingPath = centerTravelLength > ARROW_SPACING_STUDS
		local movingCycleLength = if hasMovingPath then centerTravelLength + ARROW_SPACING_STUDS else 0
		local movingArrowCount = if hasMovingPath then math.clamp(
			math.ceil(movingCycleLength / ARROW_SPACING_STUDS),
			1,
			MAX_ARROW_COUNT - 1
		) else 0
		local movingStep = if movingArrowCount > 0 then movingCycleLength / movingArrowCount else 0
		local count = movingArrowCount + 1
		for index = count + 1, activeArrowCount do
			local arrow = arrows[index]
			arrow.upperBar.Transparency = 1
			arrow.lowerBar.Transparency = 1
		end
		activeArrowCount = count
		for index = 1, count do
			local arrow = arrows[index]
			if index > movingArrowCount then
				local distance = pathLength - arrowLength * 0.5
				setChevron(arrow, startPosition + forward * distance, forward, arrowLength, ARROW_WIDTH)
				arrow.upperBar.Transparency = 0.2
				arrow.lowerBar.Transparency = 0.2
			else
				local cycleDistance = ((index - 1) * movingStep + phaseStuds) % movingCycleLength
				if cycleDistance > centerTravelLength then
					arrow.upperBar.Transparency = 1
					arrow.lowerBar.Transparency = 1
				else
					local distance = arrowLength * 0.5 + cycleDistance
					setChevron(arrow, startPosition + forward * distance, forward, arrowLength, ARROW_WIDTH)

					-- Fade each chevron at the ends of its run so its return to the
					-- player's side stays invisible and the flow remains forward-only.
					local fadeLength = math.min(1, centerTravelLength * 0.25)
					local fadeIn = math.clamp(cycleDistance / fadeLength, 0, 1)
					local fadeOut = math.clamp((centerTravelLength - cycleDistance) / fadeLength, 0, 1)
					local visibility = math.min(fadeIn, fadeOut)
					local transparency = 1 - visibility * 0.8
					arrow.upperBar.Transparency = transparency
					arrow.lowerBar.Transparency = transparency
				end
			end
		end
	end)

	return function(from: BasePart?, to: BasePart?)
		origin = from
		destination = to
	end
end

return TutorialArrowPath
