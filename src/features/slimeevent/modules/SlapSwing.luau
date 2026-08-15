local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.SlimeEventConfig)

local SlapSwing = {}
local activeSwings: { [Model]: number } = {}

local function ease(value: number): number
	return value * value * (3 - 2 * value)
end

local function blend(from: CFrame, to: CFrame, alpha: number): CFrame
	return from:Lerp(to, ease(math.clamp(alpha, 0, 1)))
end

local function getOffsets(elapsed: number): (CFrame, CFrame, CFrame)
	local windupEnd = Config.SwingStrikeStart
	local strikeEnd = Config.HitDelay
	local followThroughEnd = Config.SwingFollowThroughEnd
	local shoulderWindup = CFrame.Angles(math.rad(20), math.rad(35), math.rad(60))
	local shoulderStrike = CFrame.Angles(math.rad(-20), math.rad(35), 0)
	local shoulderFollowThrough = CFrame.Angles(math.rad(-45), math.rad(20), math.rad(-45))
	local elbowWindup = CFrame.Angles(0, 0, math.rad(-10))
	local elbowStrike = CFrame.Angles(0, 0, math.rad(-10))
	local elbowFollowThrough = CFrame.Angles(0, 0, math.rad(-10))
	local waistWindup = CFrame.Angles(0, math.rad(-25), 0)
	local waistStrike = CFrame.Angles(0, math.rad(-35), 0)
	local waistFollowThrough = CFrame.Angles(0, math.rad(-50), 0)

	if elapsed <= windupEnd then
		local alpha = elapsed / windupEnd
		return blend(CFrame.identity, shoulderWindup, alpha), blend(CFrame.identity, elbowWindup, alpha), blend(CFrame.identity, waistWindup, alpha)
	elseif elapsed <= strikeEnd then
		local alpha = (elapsed - windupEnd) / (strikeEnd - windupEnd)
		return blend(shoulderWindup, shoulderStrike, alpha), blend(elbowWindup, elbowStrike, alpha), blend(waistWindup, waistStrike, alpha)
	elseif elapsed <= followThroughEnd then
		local alpha = (elapsed - strikeEnd) / (followThroughEnd - strikeEnd)
		return blend(shoulderStrike, shoulderFollowThrough, alpha), blend(elbowStrike, elbowFollowThrough, alpha), blend(waistStrike, waistFollowThrough, alpha)
	end
	local alpha = (elapsed - followThroughEnd) / (Config.SwingDuration - followThroughEnd)
	return blend(shoulderFollowThrough, CFrame.identity, alpha), blend(elbowFollowThrough, CFrame.identity, alpha), blend(waistFollowThrough, CFrame.identity, alpha)
end

function SlapSwing.play(character: Model)
	activeSwings[character] = os.clock()
end

RunService.PreSimulation:Connect(function()
	local now = os.clock()
	for character, startedAt in activeSwings do
		if not character.Parent or now - startedAt >= Config.SwingDuration then
			activeSwings[character] = nil
			continue
		end
		local shoulderOffset, elbowOffset, waistOffset = getOffsets(now - startedAt)
		local shoulder = character:FindFirstChild("RightShoulder", true)
		local elbow = character:FindFirstChild("RightElbow", true)
		local waist = character:FindFirstChild("Waist", true)
		if shoulder and shoulder:IsA("AnimationConstraint") then shoulder.Transform *= shoulderOffset end
		if elbow and elbow:IsA("AnimationConstraint") then elbow.Transform *= elbowOffset end
		if waist and waist:IsA("AnimationConstraint") then waist.Transform *= waistOffset end
	end
end)

return SlapSwing
