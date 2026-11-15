--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MAX_ARROW_COUNT = 24
local ARROW_SPACING_STUDS = 5.5
local ARROW_LENGTH = 3.1
local ARROW_WIDTH = 2.45
local BAR_WIDTH = 0.42
local BAR_HEIGHT = 0.055
local ARROW_FLOW_SPEED = 5.5
local GROUND_OFFSET = 0.06

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
	bar.Transparency = 0.2
	bar.Parent = parent
	return bar
end

local function setArm(part: Part, from: Vector3, to: Vector3)
	local arm = to - from
	if arm.Magnitude < 0.001 then
		return
	end
	local direction = arm.Unit
	part.Size = Vector3.new(arm.Magnitude, BAR_HEIGHT, BAR_WIDTH)
	part.CFrame = CFrame.fromMatrix((from + to) * 0.5, direction, Vector3.yAxis, direction:Cross(Vector3.yAxis))
end

local function setChevron(arrow: ArrowEntry, center: Vector3, forward: Vector3)
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local tip = center + forward * (ARROW_LENGTH * 0.5)
	local back = center - forward * (ARROW_LENGTH * 0.5)
	setArm(arrow.upperBar, back + side * (ARROW_WIDTH * 0.5), tip)
	setArm(arrow.lowerBar, back - side * (ARROW_WIDTH * 0.5), tip)
end

local function surfacePosition(position: Vector3, fallback: Vector3, params: RaycastParams, excluded: { Instance }): Vector3
	local castExclusions = table.clone(excluded)
	for _ = 1, 8 do
		params.FilterDescendantsInstances = castExclusions
		local result = Workspace:Raycast(position + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
		if not result then
			break
		end
		if result.Normal.Y > 0.65 then
			return result.Position + Vector3.new(0, GROUND_OFFSET, 0)
		end
		table.insert(castExclusions, result.Instance)
	end
	return fallback
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
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local function hidePath()
		for _, arrow in arrows do
			arrow.upperBar.Transparency = 1
			arrow.lowerBar.Transparency = 1
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		local from = origin
		local to = destination
		local camera = Workspace.CurrentCamera
		if not camera or not from or not to or not from.Parent or not to.Parent then
			hidePath()
			return
		end

		local character = from:FindFirstAncestorOfClass("Model")
		local targetModel = to:FindFirstAncestorOfClass("Model")
		local excluded: { Instance } = {}
		if character then table.insert(excluded, character) end
		if targetModel and targetModel ~= character then table.insert(excluded, targetModel) end
		raycastParams.FilterDescendantsInstances = excluded

		local startPosition = surfacePosition(from.Position, from.Position - Vector3.new(0, 2.5, 0), raycastParams, excluded)
		local endPosition
		if to.Name == "InsideFloor" then
			endPosition = to.Position + Vector3.new(0, to.Size.Y * 0.5 + GROUND_OFFSET, 0)
		else
			endPosition = surfacePosition(to.Position, to.Position - Vector3.new(0, 2.5, 0), raycastParams, excluded)
		end
		local delta = endPosition - startPosition
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		local pathLength = horizontal.Magnitude
		if pathLength < 0.1 then
			hidePath()
			return
		end

		phaseStuds = (phaseStuds + dt * ARROW_FLOW_SPEED) % ARROW_SPACING_STUDS
		local forward = horizontal.Unit
		local count = math.clamp(math.ceil(math.max(pathLength - ARROW_LENGTH, 0) / ARROW_SPACING_STUDS) + 1, 1, MAX_ARROW_COUNT)
		local movingPathLength = math.max(pathLength - ARROW_LENGTH, 0)
		for index, arrow in arrows do
			if index > count then
				arrow.upperBar.Transparency = 1
				arrow.lowerBar.Transparency = 1
				continue
			end

			local distance
			if index == count then
				-- Keep the final chevron aimed exactly at the target instead of letting
				-- the conveyor animation wrap it past the incubator.
				distance = pathLength - ARROW_LENGTH * 0.5
			else
				distance = ((index - 0.5) * ARROW_SPACING_STUDS + phaseStuds) % movingPathLength
			end
			local flatCenter = startPosition + forward * distance
			local center
			if index == count then
				center = endPosition - forward * (ARROW_LENGTH * 0.5)
			else
				center = surfacePosition(flatCenter, flatCenter, raycastParams, excluded)
			end
			setChevron(arrow, center, forward)
			arrow.upperBar.Transparency = 0.2
			arrow.lowerBar.Transparency = 0.2
		end
	end)

	return function(from: BasePart?, to: BasePart?)
		origin = from
		destination = to
	end
end

return TutorialArrowPath
