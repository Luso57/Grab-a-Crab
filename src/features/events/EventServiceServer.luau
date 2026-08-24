local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Config = require(ReplicatedStorage.Source.Features.Events.EventConfig)
local EventBillboard = require(ReplicatedStorage.Source.Features.Events.Modules.EventBillboard)
local EventRegistry = require(ServerScriptService.Features.Events.Registry.EventRegistryServer)

local EventServiceServer = {
	initialized = false,
}

local function getSpawnSurface(): BasePart?
	local hexagon = Workspace:FindFirstChild("Hexagon")
	local board = hexagon and hexagon:FindFirstChild("SpawnBoard")
	local surface = board and board:FindFirstChild("SpawnSlime")
	return if surface and surface:IsA("BasePart") then surface else nil
end

function EventServiceServer.init(self)
	if self.initialized then return end
	self.initialized = true
	self.networker = Networker.server.new(Config.NetworkTag, self, { self.requestEventState })
	self.random = Random.new()
	self.phase = "countdown"
	self.currentDefinition = nil
	self.currentSession = nil
	self.generation = 0
	self.startsAt = 0
	self.endsAt = 0
	self.timerElapsed = 0
	self.billboard = nil
	self:beginCountdown(Config.CountdownSeconds)

	RunService.Heartbeat:Connect(function(deltaTime)
		self.timerElapsed += deltaTime
		local now = Workspace:GetServerTimeNow()
		if self.phase == "countdown" then
			local remaining = self.startsAt - now
			if remaining <= 0 then
				self:startNextEvent()
			elseif self.timerElapsed >= 1 then
				self.timerElapsed = 0
				if self.billboard then self.billboard:setCountdown(remaining) end
			end
		elseif self.phase == "running" then
			local remaining = self.endsAt - now
			if remaining <= 0 then
				self:finishEvent("expired")
			elseif self.timerElapsed >= 1 then
				self.timerElapsed = 0
				if self.billboard then self.billboard:setInProgress(remaining) end
			end
		end
	end)
end

function EventServiceServer.ensureBillboard(self): boolean
	local surface = getSpawnSurface()
	if not surface then
		warn("[Events] Workspace.Hexagon.SpawnBoard.SpawnSlime is missing")
		return false
	end
	if not self.billboard or not self.billboard.gui.Parent then
		self.billboard = EventBillboard.new(surface)
	end
	return true
end

function EventServiceServer.getState(self)
	local definition = self.currentDefinition
	return {
		phase = self.phase,
		eventId = if definition then definition.id else nil,
		displayName = if definition then definition.displayName else nil,
		startsAt = if self.phase == "countdown" then self.startsAt else nil,
		endsAt = if self.phase == "running" then self.endsAt else nil,
		notificationText = if definition then definition.notificationText else nil,
		soundId = if definition then definition.soundId else nil,
		soundVolume = if definition then definition.soundVolume else nil,
	}
end

function EventServiceServer.publishState(self)
	self.networker:fireAll("eventStateChanged", self:getState())
end

function EventServiceServer.beginCountdown(self, duration: number?)
	self.generation += 1
	self.phase = "countdown"
	self.currentDefinition = nil
	self.currentSession = nil
	self.startsAt = Workspace:GetServerTimeNow() + (duration or Config.CountdownSeconds)
	self.endsAt = 0
	self.timerElapsed = 0
	if self:ensureBillboard() and self.billboard then
		self.billboard:setCountdown(duration or Config.CountdownSeconds)
	end
	self:publishState()
end

function EventServiceServer.chooseDefinition(self)
	local totalWeight = 0
	for _, definition in EventRegistry do
		if definition.weight > 0 then totalWeight += definition.weight end
	end
	if totalWeight <= 0 then return nil end

	local roll = self.random:NextNumber(0, totalWeight)
	local cumulative = 0
	for _, definition in EventRegistry do
		if definition.weight <= 0 then continue end
		cumulative += definition.weight
		if roll <= cumulative then return definition end
	end
	return EventRegistry[#EventRegistry]
end

function EventServiceServer.startNextEvent(self)
	if self.phase ~= "countdown" then return end
	local definition = self:chooseDefinition()
	if not definition then
		warn("[Events] No enabled event definitions")
		self:beginCountdown(Config.StartRetrySeconds)
		return
	end

	self.generation += 1
	local generation = self.generation
	local success, sessionOrError = xpcall(function()
		return definition.server:start({
			random = self.random,
			complete = function()
				if self.phase == "running" and self.generation == generation then
					self:finishEvent("completed")
				end
			end,
		})
	end, debug.traceback)

	if not success or not sessionOrError then
		warn(("[Events] Failed to start %s: %s"):format(definition.id, tostring(sessionOrError)))
		self:beginCountdown(Config.StartRetrySeconds)
		return
	end

	self.phase = "running"
	self.currentDefinition = definition
	self.currentSession = sessionOrError
	self.startsAt = 0
	self.endsAt = Workspace:GetServerTimeNow() + definition.duration
	self.timerElapsed = 0
	if self:ensureBillboard() and self.billboard then
		self.billboard:setInProgress(definition.duration)
	end
	self:publishState()
end

function EventServiceServer.finishEvent(self, reason)
	if self.phase ~= "running" then return end
	self.generation += 1
	local session = self.currentSession
	self.currentSession = nil
	if session then
		local success, stopError = xpcall(function()
			session:stop(reason)
		end, debug.traceback)
		if not success then warn(("[Events] Event cleanup failed: %s"):format(tostring(stopError))) end
	end
	self:beginCountdown(Config.CountdownSeconds)
end

function EventServiceServer.requestEventState(self, player: Player)
	self.networker:fire(player, "eventStateChanged", self:getState())
end

return EventServiceServer
