--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabRigBuilder = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabRigBuilder)
local Config = require(script.Parent.Parent.Modules.TankAnimationConfig)

local TankCrabAnimatorClient = {}
TankCrabAnimatorClient.__index = TankCrabAnimatorClient

export type TankCrabAnimatorClient = typeof(setmetatable({} :: {
	marker: BasePart,
	floor: BasePart,
	tankModel: Model,
	visual: Model,
	joints: { [string]: Motor6D },
	random: Random,
	state: string,
	elapsed: number,
	duration: number,
	cycle: number,
	motionTime: number,
	handstandCooldown: number,
	bottomCooldown: number,
	bottomMovesRemaining: number,
	offset: Vector3,
	fromOffset: Vector3,
	targetOffset: Vector3,
	controlOffset: Vector3,
	trickOrigin: Vector3,
	orientation: CFrame,
	fromOrientation: CFrame,
	targetOrientation: CFrame,
	trickOrientation: CFrame,
	minOffset: Vector3,
	maxOffset: Vector3,
	boxSize: Vector3,
	boundsCorners: { Vector3 },
	footCorners: { Vector3 },
	feet: { BasePart },
	floatMinOffsetY: number,
	bottomFloorOffsetY: number,
	roofHeight: number,
	farElapsed: number,
	destroyed: boolean,
}, TankCrabAnimatorClient))

local function getJoints(visual: Model): { [string]: Motor6D }
	local joints: { [string]: Motor6D } = {}
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local role = descendant.Name:match("^CrabRig_(.+)$")
			if role then
				joints[role] = descendant
			end
		end
	end
	return joints
end

local function appendPartCorners(corners: { Vector3 }, part: BasePart, origin: CFrame)
	local half = part.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local worldCorner = part.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
				table.insert(corners, origin:PointToObjectSpace(worldCorner))
			end
		end
	end
end

local function lowestPartY(part: BasePart, floor: BasePart): number
	local half = part.Size / 2
	local lowest = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
				lowest = math.min(lowest, floor.CFrame:PointToObjectSpace(corner).Y)
			end
		end
	end
	return lowest
end

local function seedFromId(instanceId: string): number
	local seed = 17
	for index = 1, #instanceId do
		seed = (seed * 33 + string.byte(instanceId, index)) % 2147483647
	end
	return seed
end

local function randomOrientation(random: Random): CFrame
	return CFrame.Angles(
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi)
	)
end

function TankCrabAnimatorClient.new(marker: BasePart, floor: BasePart, tankModel: Model): TankCrabAnimatorClient?
	local crabId = marker:GetAttribute("CrabId")
	local instanceId = marker:GetAttribute("ItemInstanceId")
	local displayScale = marker:GetAttribute("DisplayScale")
	if typeof(crabId) ~= "string" or typeof(instanceId) ~= "string" or typeof(displayScale) ~= "number" then
		return nil
	end
	local definition = Crabs.get(crabId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crabs = if assets then assets:FindFirstChild("Crabs") else nil
	local template = if definition and crabs then crabs:FindFirstChild(definition.modelName) else nil
	if not template or not template:IsA("Model") then
		warn("Missing animated crab model:", crabId)
		return nil
	end

	local visual = template:Clone()
	local body = CrabRigBuilder.rig(visual)
	if not body then
		visual:Destroy()
		return nil
	end
	visual:ScaleTo(displayScale)
	visual.Name = "AnimatedCrab"
	visual:SetAttribute("ItemInstanceId", instanceId)
	visual:SetAttribute("CrabId", crabId)
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == body
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
	visual:PivotTo(marker.CFrame)
	visual.Parent = marker.Parent

	local boxCFrame, boxSize = visual:GetBoundingBox()
	local joints = getJoints(visual)
	local feet: { BasePart } = {}
	local footCorners: { Vector3 } = {}
	for _, side in { "L", "R" } do
		for index = 1, 4 do
			local joint = joints[string.format("Leg_%s_%02d", side, index)]
			if joint and joint.Part1 then
				local foot = joint.Part1
				table.insert(feet, foot)
				appendPartCorners(footCorners, foot, marker.CFrame)
			end
		end
	end
	local half = boxSize / 2
	local boundsCorners: { Vector3 } = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local worldCorner = boxCFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
				table.insert(boundsCorners, marker.CFrame:PointToObjectSpace(worldCorner))
			end
		end
	end
	local roofHeight = math.huge
	for _, descendant in tankModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name:match("^RoofSlat") then
			local roofLocal = floor.CFrame:PointToObjectSpace(descendant.Position)
			roofHeight = math.min(roofHeight, roofLocal.Y - descendant.Size.Y / 2)
		end
	end
	if roofHeight == math.huge then
		roofHeight = floor.Size.Y / 2 + math.max(2.5, boxSize.Y + 0.6)
	end
	local random = Random.new(seedFromId(instanceId))
	local initialOrientation = randomOrientation(random)
	visual:PivotTo(marker.CFrame * initialOrientation)
	local driftDuration = random:NextNumber(Config.driftDurationMin, Config.driftDurationMax)
	local self = setmetatable({
		marker = marker,
		floor = floor,
		tankModel = tankModel,
		visual = visual,
		joints = joints,
		random = random,
		state = "Drift",
		elapsed = 0,
		duration = driftDuration,
		cycle = 0,
		motionTime = 0,
		handstandCooldown = random:NextNumber(Config.handstandCooldownMin, Config.handstandCooldownMax),
		bottomCooldown = random:NextNumber(Config.bottomCooldownMin, Config.bottomCooldownMax),
		bottomMovesRemaining = 0,
		offset = Vector3.zero,
		fromOffset = Vector3.zero,
		targetOffset = Vector3.zero,
		controlOffset = Vector3.zero,
		trickOrigin = Vector3.zero,
		orientation = initialOrientation,
		fromOrientation = initialOrientation,
		targetOrientation = initialOrientation,
		trickOrientation = initialOrientation,
		minOffset = Vector3.zero,
		maxOffset = Vector3.zero,
		boxSize = boxSize,
		boundsCorners = boundsCorners,
		footCorners = footCorners,
		feet = feet,
		floatMinOffsetY = 0,
		bottomFloorOffsetY = 0,
		roofHeight = roofHeight,
		farElapsed = 0,
		destroyed = false,
	}, TankCrabAnimatorClient) :: TankCrabAnimatorClient
	self:updateBounds()
	self:chooseDriftTarget()
	return self
end

local function clampOffset(self: TankCrabAnimatorClient, value: Vector3): Vector3
	return Vector3.new(
		math.clamp(value.X, self.minOffset.X, self.maxOffset.X),
		math.clamp(value.Y, self.minOffset.Y, self.maxOffset.Y),
		math.clamp(value.Z, self.minOffset.Z, self.maxOffset.Z)
	)
end

function TankCrabAnimatorClient.updateBounds(self: TankCrabAnimatorClient)
	local home = self.floor.CFrame:PointToObjectSpace(self.marker.Position)
	local minCorner = Vector3.new(math.huge, math.huge, math.huge)
	local maxCorner = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, corner in self.boundsCorners do
		local localCorner = self.floor.CFrame:VectorToObjectSpace(self.marker.CFrame:VectorToWorldSpace(corner))
		minCorner = Vector3.new(
			math.min(minCorner.X, localCorner.X),
			math.min(minCorner.Y, localCorner.Y),
			math.min(minCorner.Z, localCorner.Z)
		)
		maxCorner = Vector3.new(
			math.max(maxCorner.X, localCorner.X),
			math.max(maxCorner.Y, localCorner.Y),
			math.max(maxCorner.Z, localCorner.Z)
		)
	end
	local halfX = self.floor.Size.X / 2 - Config.edgePadding
	local halfZ = self.floor.Size.Z / 2 - Config.edgePadding
	local minX = -halfX - home.X - minCorner.X
	local maxX = halfX - home.X - maxCorner.X
	local minZ = -halfZ - home.Z - minCorner.Z
	local maxZ = halfZ - home.Z - maxCorner.Z
	local minY = self.floor.Size.Y / 2 + 0.03 - home.Y - minCorner.Y
	local maxY = self.roofHeight - Config.verticalPadding - home.Y - maxCorner.Y
	local bottomY = minY
	if #self.footCorners > 0 then
		local lowestFoot = math.huge
		local walkingRotation = CFrame.Angles(math.pi / 2, 0, 0)
		for _, corner in self.footCorners do
			local worldVector = self.marker.CFrame:VectorToWorldSpace(walkingRotation:VectorToWorldSpace(corner))
			local floorVector = self.floor.CFrame:VectorToObjectSpace(worldVector)
			lowestFoot = math.min(lowestFoot, floorVector.Y)
		end
		bottomY = self.floor.Size.Y / 2 + 0.02 - home.Y - lowestFoot
	end
	self.floatMinOffsetY = minY
	self.bottomFloorOffsetY = bottomY
	local lowestOffsetY = math.min(minY, bottomY)
	self.minOffset = Vector3.new(
		if minX <= maxX then minX else 0,
		if lowestOffsetY <= maxY then lowestOffsetY else 0,
		if minZ <= maxZ then minZ else 0
	)
	self.maxOffset = Vector3.new(
		if minX <= maxX then maxX else 0,
		if minY <= maxY then maxY else 0,
		if minZ <= maxZ then maxZ else 0
	)
end

function TankCrabAnimatorClient.chooseDriftTarget(self: TankCrabAnimatorClient)
	self.fromOffset = clampOffset(self, self.offset)
	self.fromOrientation = self.orientation
	self.targetOrientation = randomOrientation(self.random)
	local floatingMinY = math.min(self.maxOffset.Y, self.floatMinOffsetY + Config.verticalPadding)
	self.targetOffset = Vector3.new(
		self.random:NextNumber(self.minOffset.X, self.maxOffset.X),
		self.random:NextNumber(floatingMinY, self.maxOffset.Y),
		self.random:NextNumber(self.minOffset.Z, self.maxOffset.Z)
	)
	local delta = self.targetOffset - self.fromOffset
	local sideways = Vector3.new(-delta.Z, 0, delta.X)
	local bend = if sideways.Magnitude > 0.01
		then sideways.Unit * self.random:NextNumber(-0.22, 0.22) else Vector3.zero
	self.controlOffset = clampOffset(self, (self.fromOffset + self.targetOffset) / 2 + bend)
end

function TankCrabAnimatorClient.chooseBottomTarget(self: TankCrabAnimatorClient)
	self.fromOffset = clampOffset(self, self.offset)
	self.fromOrientation = self.orientation
	self.targetOffset = Vector3.new(
		self.random:NextNumber(self.minOffset.X, self.maxOffset.X),
		self.bottomFloorOffsetY,
		self.random:NextNumber(self.minOffset.Z, self.maxOffset.Z)
	)
	self.targetOrientation = CFrame.Angles(0, self.random:NextNumber(-math.pi, math.pi), 0)
		* CFrame.Angles(math.pi / 2, 0, 0)
	local delta = self.targetOffset - self.fromOffset
	local sideways = Vector3.new(-delta.Z, 0, delta.X)
	local bend = if sideways.Magnitude > 0.01
		then sideways.Unit * self.random:NextNumber(-0.16, 0.16) else Vector3.zero
	self.controlOffset = clampOffset(self, (self.fromOffset + self.targetOffset) / 2 + bend)
end

function TankCrabAnimatorClient.advanceState(self: TankCrabAnimatorClient)
	self.elapsed = 0
	if self.state == "Drift" and self.handstandCooldown <= 0 then
		self.state = "Handstand"
		self.duration = Config.handstandDuration
		self.trickOrigin = self.offset
		self.trickOrientation = self.orientation
		self.handstandCooldown = self.random:NextNumber(Config.handstandCooldownMin, Config.handstandCooldownMax)
	elseif self.state == "Drift" and self.bottomCooldown <= 0 then
		self.state = "Bottom"
		self.duration = self.random:NextNumber(Config.bottomMoveDurationMin, Config.bottomMoveDurationMax)
		self.bottomMovesRemaining = self.random:NextInteger(3, 4)
		self.bottomCooldown = self.random:NextNumber(Config.bottomCooldownMin, Config.bottomCooldownMax)
		self:chooseBottomTarget()
	elseif self.state == "Bottom" and self.bottomMovesRemaining > 1 then
		self.bottomMovesRemaining -= 1
		self.duration = self.random:NextNumber(Config.bottomMoveDurationMin, Config.bottomMoveDurationMax)
		self:chooseBottomTarget()
	else
		self.state = "Drift"
		self.duration = self.random:NextNumber(Config.driftDurationMin, Config.driftDurationMax)
		self.cycle += 1
		self:chooseDriftTarget()
	end
end

local function smoothstep(value: number): number
	return value * value * (3 - 2 * value)
end

function TankCrabAnimatorClient.step(self: TankCrabAnimatorClient, dt: number, cameraPosition: Vector3)
	if self.destroyed or not self.marker.Parent or not self.visual.Parent then
		return
	end
	local distance = (cameraPosition - self.marker.Position).Magnitude
	if distance > Config.farDistance then
		return
	end
	if distance > Config.nearDistance then
		self.farElapsed += dt
		if self.farElapsed < Config.farUpdateInterval then
			return
		end
		dt = self.farElapsed
		self.farElapsed = 0
	else
		self.farElapsed = 0
	end

	local animationDt = math.min(dt, 0.15)
	self.elapsed += animationDt
	self.motionTime += animationDt
	if self.state == "Drift" then
		self.handstandCooldown -= animationDt
		self.bottomCooldown -= animationDt
	end
	self:updateBounds()
	if self.elapsed >= self.duration then
		self:advanceState()
	end

	local progress = math.clamp(self.elapsed / self.duration, 0, 1)
	local bodyBob = 0
	if self.state == "Drift" then
		local blend = smoothstep(progress)
		local first = self.fromOffset:Lerp(self.controlOffset, blend)
		local second = self.controlOffset:Lerp(self.targetOffset, blend)
		self.offset = clampOffset(self, first:Lerp(second, blend))
		self.orientation = self.fromOrientation:Lerp(self.targetOrientation, blend)
		bodyBob = math.sin(self.motionTime * 2.6 + self.cycle) * 0.055
	elseif self.state == "Bottom" then
		local blend = smoothstep(math.clamp(progress / 0.82, 0, 1))
		local first = self.fromOffset:Lerp(self.controlOffset, blend)
		local second = self.controlOffset:Lerp(self.targetOffset, blend)
		self.offset = clampOffset(self, first:Lerp(second, blend))
		self.orientation = self.fromOrientation:Lerp(self.targetOrientation, blend)
		bodyBob = math.sin(self.motionTime * 4) * 0.012
	else
		local capacity = self.tankModel:GetAttribute("TankCapacity")
		local yaw = if capacity == 2 then math.sin(progress * 2 * math.pi) * 0.35
			else 2 * math.pi * smoothstep(progress)
		local enter = smoothstep(math.clamp(progress / 0.2, 0, 1))
		local leave = smoothstep(math.clamp((1 - progress) / 0.2, 0, 1))
		self.orientation = self.trickOrientation:Lerp(CFrame.Angles(0, yaw, 0), math.min(enter, leave))
		local orbit = math.min(
			(self.maxOffset.X - self.minOffset.X) / 2,
			(self.maxOffset.Z - self.minOffset.Z) / 2,
			0.08
		)
		self.offset = clampOffset(self, self.trickOrigin + Vector3.new(
			math.sin(progress * 4 * math.pi) * orbit,
			math.sin(math.pi * progress) * 0.18,
			(math.cos(progress * 4 * math.pi) - 1) * orbit
		))
		bodyBob = math.sin(progress * 8 * math.pi) * 0.025
	end

	local home = self.marker.CFrame
	local rotation = self.orientation
	local base = home * CFrame.new(self.offset.X, self.offset.Y + bodyBob, self.offset.Z) * rotation
	local lowest = math.huge
	local highest = -math.huge
	for _, corner in if self.state == "Bottom" and #self.footCorners > 0 then self.footCorners else self.boundsCorners do
		local floorY = self.floor.CFrame:PointToObjectSpace(base:PointToWorldSpace(corner)).Y
		lowest = math.min(lowest, floorY)
	end
	for _, corner in self.boundsCorners do
		local floorY = self.floor.CFrame:PointToObjectSpace(base:PointToWorldSpace(corner)).Y
		highest = math.max(highest, floorY)
	end
	local floorTop = self.floor.Size.Y / 2
	local padding = if self.state == "Handstand" then 0.16
		elseif self.state == "Bottom" then 0.02 else 0.03
	local lift = if self.state == "Bottom" then floorTop + padding - lowest
		else math.max(0, floorTop + padding - lowest)
	lift -= math.max(0, highest + lift - (self.roofHeight - 0.12))
	self.visual:PivotTo(home * CFrame.new(self.offset.X, self.offset.Y + bodyBob + lift, self.offset.Z) * rotation)

	for _, side in { "L", "R" } do
		local sign = if side == "L" then 1 else -1
		local arm = self.joints["Arm_" .. side]
		local claw = self.joints["Claw_" .. side]
		local armSway = if self.state == "Drift" then math.sin(self.motionTime * 3 + sign) * 0.08
			elseif self.state == "Bottom" then math.sin(self.motionTime * 5 + sign) * 0.07
			else math.sin(self.elapsed * 9 + sign) * 0.16
		if arm then
			arm.Transform = CFrame.Angles(0, sign * armSway, 0)
		end
		if claw then
			claw.Transform = CFrame.Angles(0, sign * math.sin(self.motionTime * 4 + sign) * 0.06, 0)
		end
		for index = 1, 4 do
			local leg = self.joints[string.format("Leg_%s_%02d", side, index)]
			if leg then
				local swing = if self.state == "Drift"
					then math.sin(self.motionTime * 3.5 + index + sign) * 0.07
					elseif self.state == "Bottom"
					then math.sin(self.motionTime * 6 + index + sign) * 0.11
					else math.sin(self.elapsed * 8 + index + sign) * 0.1
				leg.Transform = CFrame.Angles(swing, 0, swing * 0.35)
			end
		end
	end
end

function TankCrabAnimatorClient.correctContainment(self: TankCrabAnimatorClient, cameraPosition: Vector3)
	if self.destroyed or not self.visual.Parent
		or (cameraPosition - self.marker.Position).Magnitude > Config.farDistance then
		return
	end
	local boxCFrame, boxSize = self.visual:GetBoundingBox()
	local half = boxSize / 2
	local lowest = math.huge
	local highest = -math.huge
	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = boxCFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
				local floorY = self.floor.CFrame:PointToObjectSpace(corner).Y
				lowest = math.min(lowest, floorY)
				highest = math.max(highest, floorY)
				local localCorner = self.floor.CFrame:PointToObjectSpace(corner)
				minX = math.min(minX, localCorner.X)
				maxX = math.max(maxX, localCorner.X)
				minZ = math.min(minZ, localCorner.Z)
				maxZ = math.max(maxZ, localCorner.Z)
			end
		end
	end
	if self.state == "Bottom" and #self.feet > 0 then
		lowest = math.huge
		for _, foot in self.feet do
			lowest = math.min(lowest, lowestPartY(foot, self.floor))
		end
	end
	local correctionY = if self.state == "Bottom" then self.floor.Size.Y / 2 + 0.02 - lowest
		else math.max(0, self.floor.Size.Y / 2 + 0.02 - lowest)
	correctionY -= math.max(0, highest + correctionY - (self.roofHeight - 0.02))
	local halfX = self.floor.Size.X / 2 - 0.02
	local halfZ = self.floor.Size.Z / 2 - 0.02
	local fitsX = maxX - minX <= halfX * 2
	local fitsZ = maxZ - minZ <= halfZ * 2
	local correctionX = if not fitsX then 0 elseif minX < -halfX then -halfX - minX
		elseif maxX > halfX then halfX - maxX else 0
	local correctionZ = if not fitsZ then 0 elseif minZ < -halfZ then -halfZ - minZ
		elseif maxZ > halfZ then halfZ - maxZ else 0
	if correctionX ~= 0 or correctionY ~= 0 or correctionZ ~= 0 then
		local delta = self.floor.CFrame:VectorToWorldSpace(Vector3.new(correctionX, correctionY, correctionZ))
		self.visual:PivotTo(CFrame.new(delta) * self.visual:GetPivot())
	end
end

function TankCrabAnimatorClient.destroy(self: TankCrabAnimatorClient)
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.visual:Destroy()
	table.clear(self.joints)
end

return TankCrabAnimatorClient
