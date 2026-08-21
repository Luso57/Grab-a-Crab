local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotLevelConfig = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelConfig)
local Config = require(ReplicatedStorage.Source.Features.Slimeevent.SlimeEventConfig)
local EventBillboard = require(ReplicatedStorage.Source.Features.Slimeevent.Modules.EventBillboard)
local EventSlimeSpawner = require(ReplicatedStorage.Source.Features.Slimeevent.Modules.EventSlimeSpawner)
local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
local RagdollServer = require(ServerScriptService.Features.Slimeevent.Modules.RagdollServer)

local SlimeEventServiceServer = {}

local function findBat(container: Instance?): Tool?
	if not container then return nil end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(Config.ToolAttribute) == true then return child end
	end
	return nil
end

local function destroyBats(container: Instance?)
	if not container then return end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(Config.ToolAttribute) == true then child:Destroy() end
	end
end

local function getSpawnSurface(): BasePart?
	local hexagon = workspace:FindFirstChild("Hexagon")
	local board = hexagon and hexagon:FindFirstChild("SpawnBoard")
	local surface = board and board:FindFirstChild("SpawnSlime")
	return if surface and surface:IsA("BasePart") then surface else nil
end

function SlimeEventServiceServer.init(self: SlimeEventServiceServer)
	self.networker = Networker.server.new(Config.NetworkTag, self, { self.requestSwing, self.requestEventState })
	self.lastSwingAt = {}
	self.combatEnabled = false
	self.random = Random.new()
	self.carrier = nil
	self.eventState = "countdown"
	self.eventStartsAt = 0
	self.eventEndsAt = 0
	self.billboard = nil
	self.timerUpdateElapsed = 0
	self.deliveryCheckElapsed = 0
	self.deliveryAttempting = false
	self.plotFullNotified = false
	self:beginCountdown()
	RunService.Heartbeat:Connect(function(deltaTime)
		if self.eventState == "countdown" then
			self.timerUpdateElapsed += deltaTime
			local remaining = self.eventStartsAt - os.clock()
			if remaining <= 0 then
				self:startEvent()
			elseif self.timerUpdateElapsed >= 1 then
				self.timerUpdateElapsed = 0
				if self.billboard then self.billboard:setCountdown(remaining) end
			end
			return
		end

		self.timerUpdateElapsed += deltaTime
		local remaining = self.eventEndsAt - os.clock()
		if remaining <= 0 then
			self:beginCountdown()
			return
		elseif self.timerUpdateElapsed >= 1 then
			self.timerUpdateElapsed = 0
			if self.billboard then self.billboard:setInProgress(remaining) end
		end

		if not self.carrier then self.deliveryCheckElapsed = 0 return end
		self.deliveryCheckElapsed += deltaTime
		if self.deliveryCheckElapsed >= Config.DeliveryCheckInterval then
			self.deliveryCheckElapsed = 0
			self:tryDeliverEventSlime()
		end
	end)

	local function playerAdded(player: Player)
		player:SetAttribute(Config.CarryingAttribute, false)
		player.CharacterAdded:Connect(function()
			if self.carrier == player then
				self:releaseEventSlime(player, false)
			else
				player:SetAttribute(Config.CarryingAttribute, false)
			end
			if self.combatEnabled then
				task.defer(function() self:grantBat(player) end)
			else
				self:removeBat(player)
			end
		end)
		if self.combatEnabled then
			task.defer(function() self:grantBat(player) end)
		else
			self:removeBat(player)
		end
	end
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(function(player)
		self.lastSwingAt[player] = nil
		if self.carrier == player then self:releaseEventSlime(player, false) end
	end)
	for _, player in Players:GetPlayers() do playerAdded(player) end
end

function SlimeEventServiceServer.ensureBillboard(self: SlimeEventServiceServer): boolean
	local surface = getSpawnSurface()
	if not surface then
		warn("[SlimeEvent] Workspace.Hexagon.SpawnBoard.SpawnSlime is missing")
		return false
	end
	if not self.billboard or not self.billboard.gui.Parent then self.billboard = EventBillboard.new(surface) end
	return true
end

function SlimeEventServiceServer.beginCountdown(self: SlimeEventServiceServer)
	local wasInProgress = self.eventState == "inProgress"
	if self.carrier then
		self.carrier:SetAttribute(Config.CarryingAttribute, false)
	end
	if self.eventSlime then
		self.eventSlime:destroy()
		self.eventSlime = nil
	end
	self.carrier = nil
	self.deliveryAttempting = false
	self.plotFullNotified = false
	self.eventState = "countdown"
	self.eventStartsAt = os.clock() + Config.EventIntervalSeconds
	self.eventEndsAt = 0
	self.timerUpdateElapsed = 0
	self:setCombatEnabled(false)
	if self:ensureBillboard() and self.billboard then
		self.billboard:setCountdown(Config.EventIntervalSeconds)
	end
	if wasInProgress then self.networker:fireAll("eventEnded") end
end

function SlimeEventServiceServer.rollEventMutation(self: SlimeEventServiceServer): string
	local roll = self.random:NextNumber()
	if roll < Config.EventMutationNormalChance then return "normal" end
	if roll < Config.EventMutationNormalChance + Config.EventMutationFireChance then return "fire" end
	return "blackMatter"
end

function SlimeEventServiceServer.spawnEventSlime(
	self: SlimeEventServiceServer,
	mutationId: string,
	spawnRules: Config.EventSpawnRules
): boolean
	local surface = getSpawnSurface()
	if not surface then
		warn("[SlimeEvent] Workspace.Hexagon.SpawnBoard.SpawnSlime is missing")
		return false
	end

	if self.eventSlime then self.eventSlime:destroy() end
	local success, result = pcall(
		EventSlimeSpawner.spawn,
		surface,
		spawnRules.minimumRarity,
		spawnRules.maximumRarity,
		self.random,
		mutationId
	)
	if success then
		self.eventSlime = result
		result.prompt.Triggered:Connect(function(player) self:toggleEventSlime(player) end)
		return true
	else
		warn(`[SlimeEvent] Failed to spawn event slime: {result}`)
		self.eventSlime = nil
		return false
	end
end

function SlimeEventServiceServer.startEvent(self: SlimeEventServiceServer)
	if self.eventState ~= "countdown" then return end
	local spawnRules = Config.getEventSpawnRules(#Players:GetPlayers())
	local mutationId = if spawnRules.allowMutations then self:rollEventMutation() else "normal"
	if not self:spawnEventSlime(mutationId, spawnRules) then
		self.eventStartsAt = os.clock() + Config.EventSpawnRetrySeconds
		if self.billboard then self.billboard:setCountdown(Config.EventSpawnRetrySeconds) end
		return
	end
	self.eventState = "inProgress"
	self.eventEndsAt = os.clock() + Config.EventDurationSeconds
	self.timerUpdateElapsed = 0
	if self:ensureBillboard() and self.billboard then self.billboard:setInProgress(Config.EventDurationSeconds) end
	self:setCombatEnabled(true)
	self.networker:fireAll("eventStarted")
end

function SlimeEventServiceServer.removeBat(_self: SlimeEventServiceServer, player: Player)
	destroyBats(player:FindFirstChildOfClass("Backpack"))
	destroyBats(player.Character)
	destroyBats(player:FindFirstChild("StarterGear"))
end

function SlimeEventServiceServer.releaseEventSlime(self: SlimeEventServiceServer, player: Player, restoreBat: boolean?)
	if self.carrier ~= player then return end
	self.carrier = nil
	self.deliveryAttempting = false
	self.plotFullNotified = false
	player:SetAttribute(Config.CarryingAttribute, false)
	if self.eventSlime and self.eventSlime.model.Parent then self.eventSlime:returnToBoard() end
	if restoreBat ~= false and self.combatEnabled then task.defer(function() self:grantBat(player) end) end
end

function SlimeEventServiceServer.toggleEventSlime(self: SlimeEventServiceServer, player: Player)
	local eventSlime = self.eventSlime
	if not eventSlime or not eventSlime.model.Parent then return end
	if self.carrier then return end
	local plot = PlotServiceServer:getPlayerPlot(player)
	if not plot then return end
	if plot:getAvailablePlaypenLevel() == nil then
		plot.networker:fire(player, "plotFull")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return end
	if RagdollServer.isActive(character) then return end
	local slimePosition = eventSlime.model:GetBoundingBox().Position
	if (root.Position - slimePosition).Magnitude > Config.PickupDistance + 2 then return end

	self.carrier = player
	self.plotFullNotified = false
	player:SetAttribute(Config.CarryingAttribute, true)
	self:removeBat(player)
	local carrySuccess, carryError = pcall(function() eventSlime:carry(player, character) end)
	if not carrySuccess then
		self.carrier = nil
		player:SetAttribute(Config.CarryingAttribute, false)
		if self.combatEnabled then task.defer(function() self:grantBat(player) end) end
		warn(`[SlimeEvent] Failed to carry event slime: {carryError}`)
		return
	end
	local characterAtPickup = character
	humanoid.Died:Once(function()
		if self.carrier == player and player.Character == characterAtPickup then self:releaseEventSlime(player, false) end
	end)
	player.CharacterRemoving:Once(function(removingCharacter)
		if removingCharacter == characterAtPickup and self.carrier == player then self:releaseEventSlime(player, false) end
	end)
end

function SlimeEventServiceServer.tryDeliverEventSlime(self: SlimeEventServiceServer)
	if self.deliveryAttempting then return end
	local player = self.carrier
	local eventSlime = self.eventSlime
	if not player or not eventSlime or not eventSlime.model.Parent then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return end

	local plot = PlotServiceServer:getPlayerPlot(player)
	if not plot then return end
	local playpenLevel = plot:getAvailablePlaypenLevel()
	if playpenLevel == nil then
		if not self.plotFullNotified then
			self.plotFullNotified = true
			plot.networker:fire(player, "plotFull")
		end
		return
	end
	self.plotFullNotified = false

	if not plot:isPlayerNearPlaypen(player, PlotLevelConfig.StartingLevel) then return end

	self.deliveryAttempting = true
	local slimeId = eventSlime.model:GetAttribute("SlimeId")
	local mutationId = eventSlime.model:GetAttribute("MutationId")
	local granted = type(slimeId) == "string"
		and plot:grantSlime(slimeId, if type(mutationId) == "string" then mutationId else "normal")
	if not granted then
		self.deliveryAttempting = false
		if plot:getAvailablePlaypenLevel() == nil and not self.plotFullNotified then
			self.plotFullNotified = true
			plot.networker:fire(player, "plotFull")
		end
		return
	end

	self.carrier = nil
	self.plotFullNotified = false
	player:SetAttribute(Config.CarryingAttribute, false)
	eventSlime:destroy()
	self.eventSlime = nil
	self.deliveryAttempting = false
	self:beginCountdown()
end

function SlimeEventServiceServer.grantBat(self: SlimeEventServiceServer, player: Player)
	if not self.combatEnabled or player:GetAttribute(Config.CarryingAttribute) == true then return end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return end
	local bat = findBat(character) or findBat(backpack)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local misc = assets and assets:FindFirstChild("Misc")
	local template = misc and misc:FindFirstChild(Config.ToolName)
	if not bat and template and template:IsA("Tool") then
		bat = template:Clone()
		bat.Parent = backpack
	elseif not bat then
		warn("[SlimeEvent] ReplicatedStorage.Assets.Misc.Bat is missing")
		return
	end
	if bat.Parent ~= character then humanoid:EquipTool(bat) end
end

function SlimeEventServiceServer.setCombatEnabled(self: SlimeEventServiceServer, enabled: boolean)
	self.combatEnabled = enabled
	for _, player in Players:GetPlayers() do
		if enabled then
			self:grantBat(player)
		else
			self:removeBat(player)
		end
	end
end

function SlimeEventServiceServer.requestSwing(self: SlimeEventServiceServer, player: Player)
	if not self.combatEnabled then return end
	local now = os.clock()
	if now - (self.lastSwingAt[player] or -math.huge) < Config.SwingCooldown then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local bat = findBat(character)
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") or not bat then return end

	self.lastSwingAt[player] = now
	self.networker:fireAllExcept(player, "swingReplicated", player.UserId)
	task.delay(Config.HitDelay, function()
		if player.Character ~= character or humanoid.Health <= 0 or bat.Parent ~= character then return end
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { character }
		local hitbox = root.CFrame * CFrame.new(0, 0, -Config.HitboxForwardOffset)
		local closestCharacter, closestDistance = nil, math.huge
		for _, part in workspace:GetPartBoundsInBox(hitbox, Config.HitboxSize, overlap) do
			local candidate = part:FindFirstAncestorOfClass("Model")
			local targetPlayer = candidate and Players:GetPlayerFromCharacter(candidate)
			local targetHumanoid = candidate and candidate:FindFirstChildOfClass("Humanoid")
			local targetRoot = candidate and candidate:FindFirstChild("HumanoidRootPart")
			if targetPlayer and targetPlayer ~= player and targetHumanoid and targetHumanoid.Health > 0 and targetRoot and targetRoot:IsA("BasePart") and not RagdollServer.isActive(candidate) then
				local distance = (targetRoot.Position - root.Position).Magnitude
				if distance < closestDistance then
					closestDistance, closestCharacter = distance, candidate
				end
			end
		end

		if closestCharacter then
			local targetRoot = closestCharacter:FindFirstChild("HumanoidRootPart") :: BasePart
			local targetPlayer = Players:GetPlayerFromCharacter(closestCharacter)
			if targetPlayer and self.carrier == targetPlayer then self:releaseEventSlime(targetPlayer, true) end
			if RagdollServer.apply(closestCharacter, targetRoot.Position - root.Position) then
				local handle = bat:FindFirstChild("Handle")
				local hitSound = handle and handle:FindFirstChild("Hit")
				if hitSound and hitSound:IsA("Sound") then hitSound:Play() end
				local ouchTemplate = handle and handle:FindFirstChild("Ouch")
				if ouchTemplate and ouchTemplate:IsA("Sound") then
					local ouch = ouchTemplate:Clone()
					ouch.Parent = targetRoot
					ouch:Play()
					Debris:AddItem(ouch, 3)
				end
			end
		end
	end)
end

function SlimeEventServiceServer.requestEventState(self: SlimeEventServiceServer, player: Player)
	self.networker:fire(player, "eventStateChanged", self.eventState == "inProgress")
end

type SlimeEventServiceServer = typeof(SlimeEventServiceServer) & {
	networker: Networker.Server,
	combatEnabled: boolean,
	eventSlime: EventSlimeSpawner.EventSlimeHandle?,
	billboard: EventBillboard.Handle?,
	carrier: Player?,
	deliveryAttempting: boolean,
	deliveryCheckElapsed: number,
	eventStartsAt: number,
	eventEndsAt: number,
	eventState: "countdown" | "inProgress",
	plotFullNotified: boolean,
	timerUpdateElapsed: number,
	lastSwingAt: { [Player]: number },
	random: Random,
}

return SlimeEventServiceServer :: SlimeEventServiceServer
