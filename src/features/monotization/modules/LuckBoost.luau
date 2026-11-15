--!strict

local Workspace = game:GetService("Workspace")

local ServerLuck = {
	DURATION_SECONDS = 15 * 60,
	MULTIPLIER_ATTRIBUTE = "ServerGrowthLuckMultiplier",
	EXPIRES_AT_ATTRIBUTE = "ServerGrowthLuckExpiresAt",
}

function ServerLuck.getMultiplier(now: number?): number
	local expiresAt = Workspace:GetAttribute(ServerLuck.EXPIRES_AT_ATTRIBUTE)
	if typeof(expiresAt) ~= "number" or expiresAt <= (now or Workspace:GetServerTimeNow()) then
		return 1
	end
	local multiplier = Workspace:GetAttribute(ServerLuck.MULTIPLIER_ATTRIBUTE)
	return if multiplier == 2 or multiplier == 4 then multiplier else 1
end

function ServerLuck.getRemaining(now: number?): number
	local expiresAt = Workspace:GetAttribute(ServerLuck.EXPIRES_AT_ATTRIBUTE)
	if typeof(expiresAt) ~= "number" then
		return 0
	end
	return math.max(0, math.ceil(expiresAt - (now or Workspace:GetServerTimeNow())))
end

return ServerLuck
