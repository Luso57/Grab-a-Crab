local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local TutorialConfig = require(ReplicatedStorage.Source.Features.Tutorial.TutorialConfig)

type ActionId = TutorialConfig.ActionId

local TutorialServiceServer = {
	initialized = false,
	completionTokens = {} :: { [Player]: number },
}

local function setTutorial(playerData, step: string, completed: boolean, targetSlimeInstanceId: string?)
	playerData.tutorial({
		version = TutorialConfig.Version,
		step = step,
		completed = completed,
		targetSlimeInstanceId = targetSlimeInstanceId or "",
	})
end

function TutorialServiceServer.scheduleCompletion(self, player: Player)
	local token = (self.completionTokens[player] or 0) + 1
	self.completionTokens[player] = token
	task.delay(TutorialConfig.DoneDuration, function()
		if self.completionTokens[player] ~= token then return end
		local playerData = Data[player]
		if not playerData then return end
		local tutorial = playerData.tutorial()
		if tutorial.version == TutorialConfig.Version and tutorial.step == "done" and not tutorial.completed then
			setTutorial(playerData, "", true, tutorial.targetSlimeInstanceId)
		end
	end)
end

function TutorialServiceServer.init(self)
	if self.initialized then return end
	self.initialized = true

	local function playerAdded(player: Player)
		Data.Service:waitForData(player)
		local playerData = Data[player]
		if not playerData or player.Parent ~= Players then return end

		local tutorial = playerData.tutorial()
		if tutorial.version < TutorialConfig.Version then
			local profile = Data.Service:getProfile(player)
			local isFirstSession = profile and profile.SessionLoadCount <= 1
			if isFirstSession then
				setTutorial(playerData, "roll", false, "")
			else
				setTutorial(playerData, "", true, "")
			end
		elseif not tutorial.completed and tutorial.step == "done" then
			self:scheduleCompletion(player)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(playerAdded, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.completionTokens[player] = nil
	end)
	for _, player in Players:GetPlayers() do task.spawn(playerAdded, player) end
end

function TutorialServiceServer.recordAction(
	self,
	player: Player,
	action: ActionId,
	targetSlimeInstanceId: string?
): boolean
	local playerData = Data[player]
	if not playerData then return false end
	local tutorial = playerData.tutorial()
	if tutorial.completed or tutorial.version ~= TutorialConfig.Version then return false end

	local definition = TutorialConfig.Steps[tutorial.step]
	if not definition or definition.action ~= action or not definition.nextStep then return false end
	if (action == "collectedSlime" or action == "upgradedSlime")
		and tutorial.targetSlimeInstanceId ~= ""
		and tutorial.targetSlimeInstanceId ~= targetSlimeInstanceId
	then
		return false
	end

	local nextTarget = tutorial.targetSlimeInstanceId
	if action == "boughtSlime" and type(targetSlimeInstanceId) == "string" and targetSlimeInstanceId ~= "" then
		nextTarget = targetSlimeInstanceId
	end
	setTutorial(playerData, definition.nextStep, false, nextTarget)

	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, definition.number, tutorial.step)
	end)
	if definition.nextStep == "done" then
		self:scheduleCompletion(player)
	end
	return true
end

function TutorialServiceServer.isProtectedSlime(_self, player: Player, instanceId: string): boolean
	local playerData = Data[player]
	if not playerData then return false end
	local tutorial = playerData.tutorial()
	return not tutorial.completed
		and tutorial.version == TutorialConfig.Version
		and tutorial.targetSlimeInstanceId ~= ""
		and tutorial.targetSlimeInstanceId == instanceId
end

function TutorialServiceServer.isOnStep(_self, player: Player, step: string): boolean
	local playerData = Data[player]
	if not playerData then return false end
	local tutorial = playerData.tutorial()
	return not tutorial.completed
		and tutorial.version == TutorialConfig.Version
		and tutorial.step == step
end

return TutorialServiceServer
