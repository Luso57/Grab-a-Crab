local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Source.Features.Slimeevent.SlimeEventConfig)

local RagdollServer = {}
local active: { [Model]: boolean } = {}

local function getCharacterAssemblies(character: Model): { BasePart }
	local assemblies = {}
	local seen: { [BasePart]: boolean } = {}

	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		local assemblyRoot = descendant.AssemblyRootPart or descendant
		if seen[assemblyRoot] then continue end
		seen[assemblyRoot] = true
		table.insert(assemblies, assemblyRoot)
	end

	return assemblies
end

local function setServerOwnership(assemblies: { BasePart })
	for _, assemblyRoot in assemblies do
		if assemblyRoot:CanSetNetworkOwnership() then
			assemblyRoot:SetNetworkOwner(nil)
		end
	end
end

local function stopAssemblies(assemblies: { BasePart })
	for _, assemblyRoot in assemblies do
		if not assemblyRoot.Parent then continue end
		assemblyRoot.AssemblyLinearVelocity = Vector3.zero
		assemblyRoot.AssemblyAngularVelocity = Vector3.zero
	end
end

local function restoreAutomaticOwnership(character: Model)
	for _, assemblyRoot in getCharacterAssemblies(character) do
		if assemblyRoot:CanSetNetworkOwnership() then
			assemblyRoot:SetNetworkOwnershipAuto()
		end
	end
end

function RagdollServer.isActive(character: Model): boolean
	return active[character] == true
end

function RagdollServer.apply(character: Model, direction: Vector3): boolean
	if active[character] then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return false end

	active[character] = true
	local autoRotate = humanoid.AutoRotate
	local platformStand = humanoid.PlatformStand
	local joints = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("AnimationConstraint") then
			table.insert(joints, { joint = descendant, isKinematic = descendant.IsKinematic })
			descendant.IsKinematic = false
		end
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	local assemblies = getCharacterAssemblies(character)
	setServerOwnership(assemblies)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	flatDirection = if flatDirection.Magnitude < 0.01 then root.CFrame.LookVector else flatDirection.Unit
	local tumbleAxis = Vector3.yAxis:Cross(flatDirection)
	local launchVelocity = flatDirection * Config.KnockbackHorizontal
		+ Vector3.yAxis * Config.KnockbackVertical
	local tumbleVelocity = tumbleAxis * Config.KnockbackAngularSpeed
	for _, assemblyRoot in assemblies do
		assemblyRoot.AssemblyLinearVelocity += launchVelocity
		assemblyRoot.AssemblyAngularVelocity += tumbleVelocity
	end

	task.delay(Config.RagdollDuration, function()
		if not character.Parent then
			active[character] = nil
			return
		end

		stopAssemblies(getCharacterAssemblies(character))
		for _, state in joints do
			if state.joint.Parent then state.joint.IsKinematic = state.isKinematic end
		end

		RunService.Heartbeat:Wait()
		if not character.Parent then
			active[character] = nil
			return
		end
		stopAssemblies(getCharacterAssemblies(character))

		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.PlatformStand = platformStand
			humanoid.AutoRotate = autoRotate
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if character.Parent then
			restoreAutomaticOwnership(character)
		end
		active[character] = nil
	end)
	return true
end

return RagdollServer
