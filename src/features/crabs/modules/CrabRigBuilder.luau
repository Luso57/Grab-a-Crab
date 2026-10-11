--!strict

-- Rig the existing separate MeshParts without changing their resting positions.
local CrabRigBuilder = {}

local RIG_VERSION = 1

local function findBody(model: Model): BasePart?
	if model.Name == "SkeletonCrab" then
		local cage = model:FindFirstChild("SK_BoneCage", true)
		return if cage and cage:IsA("BasePart") then cage else nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart")
			and (descendant.Name == "Body" or descendant.Name:match("^[^_]+_Body$")) then
			return descendant
		end
	end
	return nil
end

local function getPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part else nil
end

local function addMotor(part0: BasePart, part1: BasePart, role: string, towardChild: number)
	local pivot = CFrame.new(part0.Position:Lerp(part1.Position, towardChild))
	local motor = Instance.new("Motor6D")
	motor.Name = "CrabRig_" .. role
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(pivot)
	motor.C1 = part1.CFrame:ToObjectSpace(pivot)
	motor.Parent = part0
end

function CrabRigBuilder.rig(model: Model): BasePart?
	local body = findBody(model)
	if not body then
		warn("Crab rig has no body:", model.Name)
		return nil
	end
	if model:GetAttribute("CrabRigVersion") == RIG_VERSION then
		return body
	end

	local prefix = if model.Name == "SkeletonCrab" then "SK_" else body.Name:gsub("Body$", "")
	local core: { [BasePart]: boolean } = { [body] = true }
	local parts: { [string]: BasePart } = {}
	for _, role in { "Arm_L", "Arm_R", "Claw_L", "Claw_R",
		"Leg_L_01", "Leg_L_02", "Leg_L_03", "Leg_L_04",
		"Leg_R_01", "Leg_R_02", "Leg_R_03", "Leg_R_04" } do
		local part = getPart(model, prefix .. role)
		if not part then
			warn("Crab rig missing " .. role .. ":", model.Name)
			return nil
		end
		parts[role] = part
		core[part] = true
	end

	for _, descendant in model:GetDescendants() do
		if (descendant:IsA("Motor6D") or descendant:IsA("WeldConstraint")) and descendant.Name:match("^CrabRig_") then
			descendant:Destroy()
		end
	end

	model.PrimaryPart = body
	for _, side in { "L", "R" } do
		local arm = parts["Arm_" .. side]
		addMotor(body, arm, "Arm_" .. side, 0.45)
		addMotor(arm, parts["Claw_" .. side], "Claw_" .. side, 0.5)
		for index = 1, 4 do
			local role = string.format("Leg_%s_%02d", side, index)
			addMotor(body, parts[role], role, 0.35)
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not core[descendant] then
			local target = body
			if descendant.Name:match("Claw_R$") then
				target = parts.Claw_R
			elseif descendant.Name:match("Claw_L$")
				or descendant.Name:find("Palette", 1, true)
				or descendant.Name:find("Paint_", 1, true)
				or descendant.Name:find("Shovel", 1, true) then
				target = parts.Claw_L
			end
			local weld = Instance.new("WeldConstraint")
			weld.Name = "CrabRig_Detail"
			weld.Part0 = target
			weld.Part1 = descendant
			weld.Parent = target
		end
	end

	model:SetAttribute("CrabRigVersion", RIG_VERSION)
	return body
end

return CrabRigBuilder
