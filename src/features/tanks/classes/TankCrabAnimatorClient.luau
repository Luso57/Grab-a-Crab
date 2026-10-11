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
	offset: Vector2,
	fromOffset: Vector2,
	targetOffset: Vector2,
	maxOffset: Vector2,
	boxSize: Vector3,
	boundsCorners: { Vector3 },
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

local function seedFromId(instanceId: string): number
	local seed = 17
	for index = 1, #instanceId do
		seed = (seed * 33 + string.byte(instanceId, index)) % 2147483647
	end
	return seed
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
	local random = Random.new(seedFromId(instanceId))
	local walkDuration = random:NextNumber(Config.walkDurationMin, Config.walkDurationMax)
	local self = setmetatable({
		marker = marker,
		floor = floor,
		tankModel = tankModel,
		visual = visual,
		joints = getJoints(visual),
		random = random,
		state = "Walk",
		elapsed = random:NextNumber(0, walkDuration * 0.85),
		duration = walkDuration,
		cycle = 0,
		offset = Vector2.zero,
		fromOffset = Vector2.zero,
		targetOffset = Vector2.zero,
		maxOffset = Vector2.zero,
		boxSize = boxSize,
		boundsCorners = boundsCorners,
		roofHeight = roofHeight,
		farElapsed = 0,
		destroyed = false,
	}, TankCrabAnimatorClient) :: TankCrabAnimatorClient
	self:updateBounds()
	self:chooseWalkTarget()
	return self
end

function TankCrabAnimatorClient.updateBounds(self: TankCrabAnimatorClient)
	local localHome = self.floor.CFrame:PointToObjectSpace(self.marker.Position)
	local floorHalfX = self.floor.Size.X / 2
	local floorHalfZ = self.floor.Size.Z / 2
	local x = math.max(0, floorHalfX - math.abs(localHome.X) - self.boxSize.X / 2 - Config.edgePadding)
	local z = math.max(0, floorHalfZ - math.abs(localHome.Z) - self.boxSize.Z / 2 - Config.edgePadding)
	local capacity = self.tankModel:GetAttribute("TankCapacity")
	if capacity == 2 then
		x = math.min(x, 0.09)
		z = math.min(z, 0.18)
	elseif capacity == 3 then
		x = math.min(x, 0.15)
		z = math.min(z, 0.14)
	else
		x = math.min(x, 0.25)
		z = math.min(z, 0.25)
	end
	self.maxOffset = Vector2.new(x, z)
end

function TankCrabAnimatorClient.chooseWalkTarget(self: TankCrabAnimatorClient)
	self.fromOffset = self.offset
	self.targetOffset = Vector2.new(
		self.random:NextNumber(-self.maxOffset.X, self.maxOffset.X),
		self.random:NextNumber(-self.maxOffset.Y, self.maxOffset.Y)
	)
end

function TankCrabAnimatorClient.advanceState(self: TankCrabAnimatorClient)
	self.elapsed = 0
	if self.state == "Walk" then
		self.cycle += 1
		if self.cycle % 3 == 0 then
			self.state = "Float"
			self.duration = Config.floatDuration
		else
			self.state = "Clap"
			self.duration = Config.clapDuration
		end
	elseif self.state == "Float" or self.state == "Clap" then
		self.state = "Walk"
		self.duration = self.random:NextNumber(Config.walkDurationMin, Config.walkDurationMax)
		self:chooseWalkTarget()
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

	self.elapsed += math.min(dt, 0.15)
	if self.elapsed >= self.duration then
		self:advanceState()
	end
	self:updateBounds()

	local progress = math.clamp(self.elapsed / self.duration, 0, 1)
	local bodyBob = 0
	local lift = 0
	local yaw = 0
	local gait = 0
	local clap = 0
	if self.state == "Walk" then
		local blend = smoothstep(progress)
		self.offset = self.fromOffset:Lerp(self.targetOffset, blend)
		gait = math.sin(self.elapsed * 2 * math.pi * Config.walkSpeed * 2)
		bodyBob = math.abs(gait) * 0.035
		yaw = math.sin(self.elapsed * 2) * 0.08
	elseif self.state == "Clap" then
		clap = math.sin(math.pi * progress) ^ 2
		bodyBob = clap * 0.04
	else
		local capacity = self.tankModel:GetAttribute("TankCapacity")
		yaw = if capacity == 2 then math.sin(progress * 2 * math.pi) * 0.35
			else 2 * math.pi * smoothstep(progress)
		local orbit = math.min(self.maxOffset.X, self.maxOffset.Y, 0.08)
		self.offset = Vector2.new(
			math.sin(progress * 4 * math.pi) * orbit,
			math.cos(progress * 4 * math.pi) * orbit
		)
		bodyBob = math.sin(progress * 8 * math.pi) * 0.025
	end

	local home = self.marker.CFrame
	local rotation = CFrame.Angles(0, yaw, 0)
	local base = home * CFrame.new(self.offset.X, bodyBob, self.offset.Y) * rotation
	local lowest = math.huge
	local highest = -math.huge
	for _, corner in self.boundsCorners do
		local floorY = self.floor.CFrame:PointToObjectSpace(base:PointToWorldSpace(corner)).Y
		lowest = math.min(lowest, floorY)
		highest = math.max(highest, floorY)
	end
	local floorTop = self.floor.Size.Y / 2
	local padding = if self.state == "Float" then 0.16 else 0.03
	lift = math.max(0, floorTop + padding - lowest)
	if self.state == "Float" then
		lift += math.sin(math.pi * progress) * 0.18
	end
	lift = math.min(lift, math.max(0, self.roofHeight - highest - 0.12))
	self.visual:PivotTo(home * CFrame.new(self.offset.X, bodyBob + lift, self.offset.Y) * rotation)

	for _, side in { "L", "R" } do
		local sign = if side == "L" then 1 else -1
		local arm = self.joints["Arm_" .. side]
		local claw = self.joints["Claw_" .. side]
		local armSway = if self.state == "Walk" then gait * 0.12
			elseif self.state == "Float" then math.sin(self.elapsed * 9 + sign) * 0.16 else 0
		if arm then
			arm.Transform = CFrame.Angles(0, sign * (clap * 0.42 + armSway), sign * clap * 0.12)
		end
		if claw then
			claw.Transform = CFrame.Angles(0, sign * (clap * 0.24 + math.sin(self.elapsed * 5 + sign) * 0.05), 0)
		end
		for index = 1, 4 do
			local leg = self.joints[string.format("Leg_%s_%02d", side, index)]
			if leg then
				local alternating = if (index % 2 == 0) then -1 else 1
				local swing = if self.state == "Walk" then gait * alternating * sign * 0.15
					elseif self.state == "Float" then math.sin(self.elapsed * 8 + index + sign) * 0.1 else 0
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
				local localCorner = self.floor.CFrame:PointToObjectSpace(corner)
				minX = math.min(minX, localCorner.X)
				maxX = math.max(maxX, localCorner.X)
				minZ = math.min(minZ, localCorner.Z)
				maxZ = math.max(maxZ, localCorner.Z)
			end
		end
	end
	local correctionY = math.max(0, self.floor.Size.Y / 2 + 0.02 - lowest)
	local halfX = self.floor.Size.X / 2 - 0.02
	local halfZ = self.floor.Size.Z / 2 - 0.02
	local correctionX = if minX < -halfX then -halfX - minX
		elseif maxX > halfX then halfX - maxX else 0
	local correctionZ = if minZ < -halfZ then -halfZ - minZ
		elseif maxZ > halfZ then halfZ - maxZ else 0
	if correctionX ~= 0 or correctionY > 0 or correctionZ ~= 0 then
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
