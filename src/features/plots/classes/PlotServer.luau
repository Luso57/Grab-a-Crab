local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local PlotLevelConfig = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelConfig)
local ProductEntitlements = require(ReplicatedStorage.Source.Features.Monetization.Modules.ProductEntitlements)
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)
local SlimeDiscovery = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeDiscovery)
local SlimeEconomy = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeEconomy)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)
local UpgradeConfig = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeConfig)
local UpgradeTypes = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeTypes)
local SellingServiceServer = require(ServerScriptService.Features.Selling.SellingServiceServer)
local UpgradeServiceServer = require(ServerScriptService.Features.Upgrades.UpgradeServiceServer)

local PlotModel = ReplicatedStorage.Assets.Misc.Plot

local PlotServer = {}

PlotServer.__index = PlotServer

type PlotSpawn = PlotTypes.PlotSpawn

local CHAR_SPAWN_OFFSET = CFrame.new(0, 10, 0) * CFrame.Angles(0, math.pi, 0)
local ROLL_LOCK_DURATION = 6.25
local PRODUCTION_INTERVAL = 1
local COLLECTION_REQUEST_COOLDOWN = 0.25
local HOME_TELEPORT_COOLDOWN = 1
local COLLECTION_HORIZONTAL_MARGIN = 6
local COLLECTION_VERTICAL_MARGIN = 10
local SLIMES_PER_PLAYPEN = 7

local function getSafeCurrency(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(math.max(0, value))
end

local function stagePlotLevels(plotModel: Model, player: Player, plotIndex: number): Folder
	local levels = plotModel:FindFirstChild("Levels")
	assert(levels and levels:IsA("Folder"), "Plot must contain a Levels folder")
	levels.Name = `PlotLevels_{player.UserId}_{plotIndex}`
	levels.Parent = ServerStorage
	return levels
end

export type Plot = typeof(setmetatable(
	{} :: {
		cf: CFrame,
		index: number,
		player: Player,
		plotModel: Model,
		playpenBase: BasePart,
		levelTemplates: Folder,
		plotLevel: number,
		plotLevelPurchaseLocked: boolean,
		currentSlimeId: string?,
		currentMutationId: string?,

		secondarySlimeId: string?,
		secondaryMutationId: string?,
		networker: Networker.Server,
		activeRollSeed: number?,
		random: Random,
		destroyed: boolean,
		lastCollectionAt: { [string]: number },
		lastHomeTeleportAt: number,
		slimeManagementLocked: boolean,
		sellingHandle: SellingServiceServer.SellingHandle?,
		upgradeHandle: UpgradeServiceServer.UpgradeHandle?,
	},
	PlotServer
))

function PlotServer.new(player: Player, plotSpawn: PlotSpawn): Plot
	local self = setmetatable({
		player = player,
		cf = plotSpawn.part.CFrame,
		index = plotSpawn.index,
		currentSlimeId = nil,
		currentMutationId = nil,
		secondarySlimeId = nil,
		secondaryMutationId = nil,
		networker = nil :: any,
		activeRollSeed = nil,
		random = Random.new(),
		destroyed = false,
		lastCollectionAt = {},
		lastHomeTeleportAt = 0,
		slimeManagementLocked = false,
		plotLevel = PlotLevelConfig.StartingLevel,
		plotLevelPurchaseLocked = false,
		sellingHandle = nil,
		upgradeHandle = nil,
	}, PlotServer)

	local plotModel = PlotModel:Clone()
	plotModel:PivotTo(plotSpawn.part.CFrame)
	self.levelTemplates = stagePlotLevels(plotModel, player, plotSpawn.index)
	plotModel.Parent = workspace
	self.plotModel = plotModel
	self.playpenBase = self:getPlaypenBase()
	self.networker = Networker.server.new(`Plot{self.index}`, self, {
		self.rollSlime,
		self.buySlime,
		self.collectSlime,
		self.upgradeSlime,
		self.sellSlime,
		self.rebirth,
		self.purchaseSlimeLuck,
		self.purchaseCashMultiplier,
		self.purchasePlotLevel,
		self.teleportHome,
	})

	Data.Service:waitForData(player)
	local playerData = Data[player]
	if playerData then
		self.plotLevel = PlotLevelConfig.getLevel(playerData.plotLevel())
		playerData.plotLevel(self.plotLevel)
		self:migrateSlimeData()
		local pending = playerData.pendingBuySlime()
		if pending.active and Slimes.isValidSlimeId(pending.slimeId) then
			if pending.offerIndex == 2 then
				self.secondarySlimeId = pending.slimeId
				self.secondaryMutationId = SlimeMutations.getId(pending.mutationId)
			else
				self.currentSlimeId = pending.slimeId
				self.currentMutationId = SlimeMutations.getId(pending.mutationId)
			end
		end
		for level = PlotLevelConfig.StartingLevel + 1, self.plotLevel do
			self:spawnPlotLevel(level)
		end
	end
	self.upgradeHandle = UpgradeServiceServer.attachPlot(player, self.plotModel)
	self.sellingHandle = SellingServiceServer.attachPlot(player, self.plotModel, function(amount)
		self.networker:fire(player, "slimeDeposited", amount)
	end, function(amount)
		self.networker:fire(player, "cashCollected", amount)
	end, function()
		self.networker:fire(player, "upgradePerSecondStepped")
	end, function()
		self.networker:fire(player, "insufficientMoney")
	end)
	self:startProduction()

	self.charInit(self)
	if playerData and math.max(0, math.floor(playerData.pending99xLuckSpins())) > 0 then
		task.defer(function()
			self:tryStartPending99xLuckSpin()
		end)
	end

	return self
end

function PlotServer.spawnPlotLevel(self: Plot, level: number): boolean
	local levelName = `PlayPenBaseLvl{level}`
	if self.plotModel:FindFirstChild(levelName) then
		return true
	end

	local levelModel = self.levelTemplates:FindFirstChild(levelName)
	if not levelModel or not levelModel:IsA("Model") then
		warn(`Missing authored plot level model {levelName}`)
		return false
	end

	levelModel.Parent = self.plotModel
	return true
end

function PlotServer.getPlaypenBase(self: Plot, level: number?): BasePart
	local safeLevel = math.max(1, math.floor(level or 1))
	if safeLevel > 1 then
		local levelModel = self.plotModel:FindFirstChild(`PlayPenBaseLvl{safeLevel}`)
		local playpenArea = if levelModel then levelModel:FindFirstChild("PlayPenArea", true) else nil
		if playpenArea and playpenArea:IsA("BasePart") then
			return playpenArea
		end
		error(`Plot is missing the PlayPenArea for level {safeLevel}`)
	end

	for _, descendant in self.plotModel:GetDescendants() do
		if descendant:IsA("BasePart") and string.lower(descendant.Name) == "playpenbase" then
			return descendant
		end
	end

	error("Plot is missing its PlaypenBase BasePart")
end

function PlotServer.isPlayerNearPlaypen(self: Plot, player: Player, level: number): boolean
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local playpenBase = self:getPlaypenBase(level)
	local localPosition = playpenBase.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = playpenBase.Size / 2

	return math.abs(localPosition.X) <= halfSize.X + COLLECTION_HORIZONTAL_MARGIN
		and math.abs(localPosition.Z) <= halfSize.Z + COLLECTION_HORIZONTAL_MARGIN
		and math.abs(localPosition.Y) <= halfSize.Y + COLLECTION_VERTICAL_MARGIN
end

function PlotServer.migrateSlimeData(self: Plot)
	local playerData = Data[self.player]
	if not playerData then
		return
	end

	local savedSlimes = playerData.slimes()
	local neededLevel = PlotLevelConfig.getLevel(math.ceil(#savedSlimes / SLIMES_PER_PLAYPEN))
	if neededLevel > self.plotLevel then
		self.plotLevel = neededLevel
		playerData.plotLevel(self.plotLevel)
	end

	local floorCounts = {}
	local needsAssignment = {}
	local discoveredSlimes = table.clone(playerData.discoveredSlimes() or {})
	local discoveriesChanged = false

	for index, slimeData in savedSlimes do
		local slimeValue = playerData.slimes[index]

		if not slimeData.instanceId then
			slimeValue.instanceId(HttpService:GenerateGUID(false))
		end

		local safeMutationId = SlimeMutations.getId(slimeData.mutationId)
		if slimeData.mutationId ~= safeMutationId then
			slimeValue.mutationId(safeMutationId)
		end
		if Slimes.isValidSlimeId(slimeData.slimeId) then
			local discoveryKey = SlimeDiscovery.getKey(slimeData.slimeId, safeMutationId)
			if discoveredSlimes[discoveryKey] ~= true then
				discoveredSlimes[discoveryKey] = true
				discoveriesChanged = true
			end
		end

		if slimeData.storedSlime == nil then
			slimeValue.storedSlime(0)
		end

		if slimeData.level == nil then
			slimeValue.level(1)
		end

		if slimeData.upgradeInvestment == nil then
			slimeValue.upgradeInvestment(0)
		end

		local assignedLevel = slimeData.playpenLevel
		local isValidAssignment = type(assignedLevel) == "number"
			and assignedLevel == assignedLevel
			and assignedLevel % 1 == 0
			and assignedLevel >= PlotLevelConfig.StartingLevel
			and assignedLevel <= self.plotLevel
			and (floorCounts[assignedLevel] or 0) < SLIMES_PER_PLAYPEN

		if isValidAssignment then
			floorCounts[assignedLevel] = (floorCounts[assignedLevel] or 0) + 1
		else
			table.insert(needsAssignment, index)
		end
	end

	for _, index in needsAssignment do
		local assignedLevel = PlotLevelConfig.MaxLevel
		for level = PlotLevelConfig.StartingLevel, self.plotLevel do
			if (floorCounts[level] or 0) < SLIMES_PER_PLAYPEN then
				assignedLevel = level
				break
			end
		end

		floorCounts[assignedLevel] = (floorCounts[assignedLevel] or 0) + 1
		playerData.slimes[index].playpenLevel(assignedLevel)
	end

	if discoveriesChanged then
		playerData.discoveredSlimes(discoveredSlimes)
	end
end

function PlotServer.getAvailablePlaypenLevel(self: Plot): number?
	local playerData = Data[self.player]
	if not playerData then
		return nil
	end

	local savedSlimes = playerData.slimes()
	local pending = playerData.pendingBuySlime()
	local hasReservation = pending.active
		and type(pending.playpenLevel) == "number"
		and pending.playpenLevel >= PlotLevelConfig.StartingLevel
		and pending.playpenLevel <= self.plotLevel
	if #savedSlimes + (if hasReservation then 1 else 0) >= self.plotLevel * SLIMES_PER_PLAYPEN then
		return nil
	end

	local floorCounts = {}
	for _, slimeData in savedSlimes do
		local level = slimeData.playpenLevel
		if type(level) == "number" and level % 1 == 0 and level >= 1 and level <= self.plotLevel then
			floorCounts[level] = (floorCounts[level] or 0) + 1
		end
	end
	if hasReservation then
		floorCounts[pending.playpenLevel] = (floorCounts[pending.playpenLevel] or 0) + 1
	end

	for level = PlotLevelConfig.StartingLevel, self.plotLevel do
		if (floorCounts[level] or 0) < SLIMES_PER_PLAYPEN then
			return level
		end
	end

	return nil
end

function PlotServer.startProduction(self: Plot)
	task.spawn(function()
		while not self.destroyed do
			task.wait(PRODUCTION_INTERVAL)

			if self.destroyed then
				break
			end

			local playerData = Data[self.player]
			if not playerData then
				continue
			end

			local productionUpdates = {}
			local hasAutoCollectSlime = ProductEntitlements.owns(playerData, "autoCollectSlime")
			local autoCollectedAmount = 0

			for index, slimeData in playerData.slimes() do
				if not Slimes.isValidSlimeId(slimeData.slimeId) then
					continue
				end

				local slimeInfo = Slimes.getSlimeInfo(slimeData.slimeId)
				local income = SlimeEconomy.getProduction(slimeInfo.income, slimeData.level)
					* SlimeMutations.getIncomeMultiplier(slimeData.mutationId)
				local storedSlime: number

				if hasAutoCollectSlime then
					local totalStored = math.max(0, slimeData.storedSlime) + income
					local wholeSlime = math.floor(totalStored)
					storedSlime = totalStored - wholeSlime
					playerData.slimes[index].storedSlime(storedSlime)
					autoCollectedAmount += wholeSlime
				else
					storedSlime = playerData.slimes[index].storedSlime(function(previous)
						return previous + income
					end)
				end

				productionUpdates[slimeData.instanceId] = storedSlime
			end

			if hasAutoCollectSlime and autoCollectedAmount > 0 then
				playerData.slimeCurrency(function(previous)
					return math.max(0, previous) + autoCollectedAmount
				end)
			end

			if next(productionUpdates) then
				self.networker:fireAll("slimeProductionUpdated", productionUpdates)
			end
		end
	end)
end

function PlotServer.get(self: Plot): PlotTypes.PlotData
	local playerData = Data[self.player]
	local savedSlimes = if playerData then playerData.slimes() else {}

	return {
		player = self.player,
		index = self.index,
		plotModel = self.plotModel,
		cf = self.cf,
		currentSlimeId = self.currentSlimeId,
		currentMutationId = self.currentMutationId,
		secondarySlimeId = self.secondarySlimeId,
		secondaryMutationId = self.secondaryMutationId,
		plotLevel = self.plotLevel,
		slimes = savedSlimes,
	}
end

function PlotServer.purchasePlotLevel(self: Plot, player: Player): boolean
	if not self:isOwner(player) or self.plotLevelPurchaseLocked then
		return false
	end

	local nextLevel = self.plotLevel + 1
	local cost = PlotLevelConfig.getCost(nextLevel)
	if nextLevel > PlotLevelConfig.MaxLevel or cost == nil then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end

	local currency = getSafeCurrency(playerData.currency())
	if currency < cost then
		self.networker:fire(player, "insufficientMoney")
		return false
	end

	local levelModel = self.levelTemplates:FindFirstChild(`PlayPenBaseLvl{nextLevel}`)
	if not levelModel or not levelModel:IsA("Model") then
		warn(`Cannot purchase missing plot level {nextLevel} for {player.Name}`)
		return false
	end

	self.plotLevelPurchaseLocked = true
	playerData.currency(currency - cost)
	playerData.plotLevel(nextLevel)
	self.plotLevel = nextLevel
	levelModel.Parent = self.plotModel
	self.plotLevelPurchaseLocked = false

	self.networker:fireAll("plotLevelPurchased", nextLevel)
	return true
end

function PlotServer.charInit(self: Plot)
	local character = self.player.Character or self.player.CharacterAdded:Wait()

	character:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	self.player.CharacterAdded:Connect(function(newCharacter)
		newCharacter:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	end)
end

local function clearPendingBuySlime(playerData)
	playerData.pendingBuySlime({
		active = false,
		slimeId = "",
		mutationId = "normal",
		offerIndex = 1,
		playpenLevel = 1,
	})
end

function PlotServer.teleportHome(self: Plot, player: Player): boolean
	if not self:isOwner(player) or self.destroyed then
		return false
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local now = os.clock()
	if now - self.lastHomeTeleportAt < HOME_TELEPORT_COOLDOWN then
		return false
	end
	self.lastHomeTeleportAt = now

	character:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	return true
end

function PlotServer.isOwner(self: Plot, player: Player): boolean
	return self.player == player
end

function PlotServer.performRoll(self: Plot, player: Player, is99xLuckSpin: boolean): boolean
	if not self:isOwner(player) or self.activeRollSeed or self.destroyed then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end
	if not is99xLuckSpin and math.max(0, math.floor(playerData.pending99xLuckSpins())) > 0 then
		task.defer(function()
			self:tryStartPending99xLuckSpin()
		end)
		return false
	end

	local currency = getSafeCurrency(playerData.currency())
	local ownedSlimes = playerData.slimes()
	local needsFreeStarter = not is99xLuckSpin and currency == 0 and #ownedSlimes == 0
	local luckMultiplier = UpgradeConfig.getLuckMultiplier(playerData.slimeLuckLevel())
		* RebirthConfig.getRewardMultiplier(playerData.rebirths())
		* ProductEntitlements.getLuckMultiplier(playerData)
	if is99xLuckSpin then
		luckMultiplier *= 99
	end

	local function rollOffer(): (string, string, number)
		local slimeId = if needsFreeStarter
			then Slimes.getRandomFreeSlimeId(self.random)
			else Slimes.getLuckyRandomSlimeId(luckMultiplier, self.random)
		local mutationId = SlimeMutations.roll(self.random)
		local animationSeed = self.random:NextInteger(1, 2_147_483_647)
		return slimeId, mutationId, animationSeed
	end

	local slimeId, mutationId, animationSeed = rollOffer()
	local hasDoubleRolls = ProductEntitlements.owns(playerData, "doubleRolls")
	local secondarySlimeId: string? = nil
	local secondaryMutationId: string? = nil
	local secondaryAnimationSeed: number? = nil
	if hasDoubleRolls then
		secondarySlimeId, secondaryMutationId, secondaryAnimationSeed = rollOffer()
	end

	local durationScale = if ProductEntitlements.owns(playerData, "doubleRollSpeed") then 0.5 else 1
	self.currentSlimeId = slimeId
	self.currentMutationId = mutationId
	self.secondarySlimeId = secondarySlimeId
	self.secondaryMutationId = secondaryMutationId
	self.activeRollSeed = animationSeed

	self.networker:fireAll(
		"playSlimeRoll",
		slimeId,
		mutationId,
		animationSeed,
		secondarySlimeId,
		secondaryMutationId,
		secondaryAnimationSeed,
		durationScale
	)

	task.delay(ROLL_LOCK_DURATION * durationScale, function()
		if self.activeRollSeed == animationSeed then
			self.activeRollSeed = nil
			self:tryStartPending99xLuckSpin()
		end
	end)

	return true
end

function PlotServer.tryStartPending99xLuckSpin(self: Plot): boolean
	if self.destroyed or self.activeRollSeed then
		return false
	end

	local playerData = Data[self.player]
	if not playerData then
		return false
	end
	local pending = math.max(0, math.floor(playerData.pending99xLuckSpins()))
	if pending <= 0 then
		return false
	end

	if not self:performRoll(self.player, true) then
		return false
	end
	playerData.pending99xLuckSpins(pending - 1)
	return true
end

function PlotServer.complete99xLuckSpinReceipt(self: Plot): boolean
	local playerData = Data[self.player]
	if not playerData or self.destroyed then
		return false
	end

	playerData.pending99xLuckSpins(function(previous)
		return math.max(0, math.floor(previous)) + 1
	end)
	task.defer(function()
		self:tryStartPending99xLuckSpin()
	end)
	return true
end

function PlotServer.completeFinishNowReceipt(self: Plot): boolean
	if self.destroyed then
		return false
	end

	return SellingServiceServer.finishQueue(self.player, self.plotModel)
end

function PlotServer.rollSlime(self: Plot, player: Player): boolean
	return self:performRoll(player, false)
end
function PlotServer.buySlime(self: Plot, player: Player, offerIndex: number?): boolean
	if not self:isOwner(player) then
		return false
	end

	local normalizedOfferIndex = if offerIndex == 2 then 2 else 1
	local slimeId = if normalizedOfferIndex == 2 then self.secondarySlimeId else self.currentSlimeId
	local mutationId = SlimeMutations.getId(
		if normalizedOfferIndex == 2 then self.secondaryMutationId else self.currentMutationId
	)
	if not slimeId or not Slimes.isValidSlimeId(slimeId) then
		return false
	end

	local slimeInfo = Slimes.getSlimeInfo(slimeId)
	local cost = slimeInfo.cost
	local playerData = Data[player]
	if not playerData then
		return false
	end
	local existingPending = playerData.pendingBuySlime()
	if existingPending.active then
		self.networker:fire(player, "promptBuySlimePurchase")
		return false
	end
	local playpenLevel = self:getAvailablePlaypenLevel()
	if playpenLevel == nil then
		self.networker:fire(player, "plotFull")
		return false
	end

	local currency = getSafeCurrency(playerData.currency())
	if currency < cost then
		self.networker:fire(player, "insufficientMoney")
		playerData.pendingBuySlime({
			active = true,
			slimeId = slimeId,
			mutationId = mutationId,
			offerIndex = normalizedOfferIndex,
			playpenLevel = playpenLevel,
		})
		self.networker:fire(player, "promptBuySlimePurchase")
		return false
	end

	local slimeData: DataTemplate.SlimeData = {
		instanceId = HttpService:GenerateGUID(false),
		slimeId = slimeId,
		mutationId = mutationId,
		storedSlime = 0,
		level = 1,
		upgradeInvestment = 0,
		playpenLevel = playpenLevel,
	}

	playerData.currency(currency - cost)
	playerData.slimes.Insert(slimeData)
	local discoveryKey = SlimeDiscovery.getKey(slimeId, mutationId)
	local discoveredSlimes = playerData.discoveredSlimes()
	if discoveredSlimes[discoveryKey] ~= true then
		local nextDiscoveredSlimes = table.clone(discoveredSlimes)
		nextDiscoveredSlimes[discoveryKey] = true
		playerData.discoveredSlimes(nextDiscoveredSlimes)
	end

	if normalizedOfferIndex == 2 then
		self.secondarySlimeId = nil
		self.secondaryMutationId = nil
	else
		self.currentSlimeId = nil
		self.currentMutationId = nil
	end
	self.networker:fireAll("slimeBought", slimeData, normalizedOfferIndex)

	return true
end

function PlotServer.completeBuySlimeReceipt(self: Plot, purchaseId: string): boolean
	if self.destroyed or purchaseId == "" then
		return false
	end

	local playerData = Data[self.player]
	if not playerData then
		return false
	end

	local instanceId = `robux-buy-slime:{purchaseId}`
	for _, slimeData in playerData.slimes() do
		if slimeData.instanceId == instanceId then
			local pending = playerData.pendingBuySlime()
			if pending.active
				and pending.slimeId == slimeData.slimeId
				and SlimeMutations.getId(pending.mutationId) == slimeData.mutationId
			then
				clearPendingBuySlime(playerData)
			end
			self.networker:fireAll("slimeGranted", slimeData)
			return true
		end
	end

	local pending = playerData.pendingBuySlime()
	if not pending.active or not Slimes.isValidSlimeId(pending.slimeId) then
		return false
	end
	local playpenLevel = math.floor(pending.playpenLevel)
	if playpenLevel < PlotLevelConfig.StartingLevel or playpenLevel > self.plotLevel then
		return false
	end

	local mutationId = SlimeMutations.getId(pending.mutationId)
	local slimeData: DataTemplate.SlimeData = {
		instanceId = instanceId,
		slimeId = pending.slimeId,
		mutationId = mutationId,
		storedSlime = 0,
		level = 1,
		upgradeInvestment = 0,
		playpenLevel = playpenLevel,
	}
	playerData.slimes.Insert(slimeData)

	local discoveryKey = SlimeDiscovery.getKey(pending.slimeId, mutationId)
	local discoveredSlimes = playerData.discoveredSlimes()
	if discoveredSlimes[discoveryKey] ~= true then
		local nextDiscoveredSlimes = table.clone(discoveredSlimes)
		nextDiscoveredSlimes[discoveryKey] = true
		playerData.discoveredSlimes(nextDiscoveredSlimes)
	end

	local offerIndex = if pending.offerIndex == 2 then 2 else 1
	local offerStillMatches = if offerIndex == 2
		then self.secondarySlimeId == pending.slimeId
		else self.currentSlimeId == pending.slimeId
	if offerStillMatches then
		if offerIndex == 2 then
			self.secondarySlimeId = nil
			self.secondaryMutationId = nil
		else
			self.currentSlimeId = nil
			self.currentMutationId = nil
		end
	end

	clearPendingBuySlime(playerData)
	if offerStillMatches then
		self.networker:fireAll("slimeBought", slimeData, offerIndex)
	else
		self.networker:fireAll("slimeGranted", slimeData)
	end
	return true
end

function PlotServer.grantSlime(self: Plot, slimeId: string, mutationId: string): boolean
	if self.destroyed or not Slimes.isValidSlimeId(slimeId) then return false end
	local playerData = Data[self.player]
	if not playerData then return false end
	local playpenLevel = self:getAvailablePlaypenLevel()
	if playpenLevel == nil then return false end

	local safeMutationId = SlimeMutations.getId(mutationId)
	local slimeData: DataTemplate.SlimeData = {
		instanceId = HttpService:GenerateGUID(false),
		slimeId = slimeId,
		mutationId = safeMutationId,
		storedSlime = 0,
		level = 1,
		upgradeInvestment = 0,
		playpenLevel = playpenLevel,
	}
	playerData.slimes.Insert(slimeData)

	local discoveryKey = SlimeDiscovery.getKey(slimeId, safeMutationId)
	local discoveredSlimes = playerData.discoveredSlimes()
	if discoveredSlimes[discoveryKey] ~= true then
		local nextDiscoveredSlimes = table.clone(discoveredSlimes)
		nextDiscoveredSlimes[discoveryKey] = true
		playerData.discoveredSlimes(nextDiscoveredSlimes)
	end

	self.networker:fireAll("slimeGranted", slimeData)
	return true
end

local function promptUpgradePurchase(self: Plot, playerData, upgradeType: string, mode: UpgradeTypes.PurchaseMode)
	local quantity = if mode == "single" then 1 else 10
	local pending = playerData.pendingUpgradePurchase()
	if pending.active then
		self.networker:fire(self.player, "promptUpgradePurchase", pending.quantity)
		return
	end

	playerData.pendingUpgradePurchase({
		active = true,
		upgradeType = upgradeType,
		quantity = quantity,
	})
	self.networker:fire(self.player, "promptUpgradePurchase", quantity)
end

function PlotServer.purchaseSlimeLuck(self: Plot, player: Player, mode: UpgradeTypes.PurchaseMode): boolean
	if not self:isOwner(player) or (mode ~= "single" and mode ~= "ten") or not self.upgradeHandle then
		return false
	end

	local result = UpgradeServiceServer.purchase(player, self.plotModel, mode)
	if result == "insufficientMoney" then
		local playerData = Data[player]
		if playerData then
			promptUpgradePurchase(self, playerData, "luck", mode)
		end
	end
	return result == "success"
end

function PlotServer.purchaseCashMultiplier(self: Plot, player: Player, mode: UpgradeTypes.PurchaseMode): boolean
	if not self:isOwner(player) or (mode ~= "single" and mode ~= "ten") or not self.upgradeHandle then
		return false
	end

	local result = UpgradeServiceServer.purchaseCashMultiplier(player, self.plotModel, mode)
	if result == "insufficientMoney" then
		local playerData = Data[player]
		if playerData then
			promptUpgradePurchase(self, playerData, "cash", mode)
		end
	end
	return result == "success"
end

function PlotServer.completeUpgradeReceipt(self: Plot, quantity: number): boolean
	local playerData = Data[self.player]
	if not playerData then
		return false
	end

	local pending = playerData.pendingUpgradePurchase()
	if not pending.active or pending.quantity ~= quantity then
		return false
	end
	if pending.upgradeType ~= "luck" and pending.upgradeType ~= "cash" then
		return false
	end

	local granted = UpgradeServiceServer.grantDeveloperProduct(
		self.player,
		self.plotModel,
		pending.upgradeType,
		quantity
	)
	if not granted then
		return false
	end

	playerData.pendingUpgradePurchase({
		active = false,
		upgradeType = "",
		quantity = 0,
	})
	return true
end
function PlotServer.upgradeSlime(self: Plot, player: Player, instanceId: string): boolean
	if not self:isOwner(player)
		or self.slimeManagementLocked
		or type(instanceId) ~= "string"
		or #instanceId > 64
	then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end

	for index, slimeData in playerData.slimes() do
		if slimeData.instanceId ~= instanceId or not Slimes.isValidSlimeId(slimeData.slimeId) then
			continue
		end

		local slimeInfo = Slimes.getSlimeInfo(slimeData.slimeId)
		local level = SlimeEconomy.getLevel(slimeData.level)
		local upgradeCost = SlimeEconomy.getUpgradeCost(slimeInfo.cost, level)
		local currency = math.floor(math.max(0, playerData.currency()))
		if upgradeCost == math.huge or currency < upgradeCost then
			if upgradeCost ~= math.huge then
				self.networker:fire(player, "insufficientMoney")
			end
			return false
		end

		self.slimeManagementLocked = true
		playerData.currency(currency - upgradeCost)
		playerData.slimes[index].level(level + 1)
		playerData.slimes[index].upgradeInvestment(function(previous)
			return math.max(0, previous or 0) + upgradeCost
		end)
		self.slimeManagementLocked = false
		self.networker:fireAll("slimeUpgraded", instanceId, level + 1)
		return true
	end

	return false
end

function PlotServer.sellSlime(self: Plot, player: Player, instanceId: string): boolean
	if not self:isOwner(player)
		or self.slimeManagementLocked
		or type(instanceId) ~= "string"
		or #instanceId > 64
	then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end

	for index, slimeData in playerData.slimes() do
		if slimeData.instanceId ~= instanceId or not Slimes.isValidSlimeId(slimeData.slimeId) then
			continue
		end

		local slimeInfo = Slimes.getSlimeInfo(slimeData.slimeId)
		local sellValue = SlimeEconomy.getSellValue(slimeInfo.cost, slimeData.upgradeInvestment)
		local storedSlime = math.floor(math.max(0, slimeData.storedSlime))

		self.slimeManagementLocked = true
		playerData.currency(function(previous)
			return math.max(0, previous) + sellValue
		end)
		if storedSlime > 0 then
			playerData.slimeCurrency(function(previous)
				return math.max(0, previous) + storedSlime
			end)
		end
		playerData.slimes.Remove(index)
		self.lastCollectionAt[instanceId] = nil
		self.slimeManagementLocked = false
		self.networker:fireAll("slimeSold", instanceId)
		return true
	end

	return false
end

function PlotServer.rebirth(self: Plot, player: Player): boolean
	if not self:isOwner(player) or self.slimeManagementLocked then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end

	local rebirthCount = RebirthConfig.getCount(playerData.rebirths())
	local rebirthCost = RebirthConfig.getCost(rebirthCount)
	local currency = math.floor(math.max(0, playerData.currency()))
	if rebirthCost == math.huge or currency < rebirthCost then
		if rebirthCost ~= math.huge then
			self.networker:fire(player, "insufficientMoney")
		end
		return false
	end

	self.slimeManagementLocked = true
	playerData.currency(0)
	playerData.slimeCurrency(0)
	playerData.slimeQueue(0)
	playerData.uncollectedCash(0)
	playerData.slimesPerSecond(5)
	playerData.sellUpgradeLevel(0)
	playerData.slimeLuckLevel(0)
	playerData.cashMultiplierLevel(0)
	playerData.slimes({})
	playerData.rebirths(rebirthCount + 1)
	table.clear(self.lastCollectionAt)
	self.slimeManagementLocked = false

	SellingServiceServer.refresh(player, self.plotModel)
	self.networker:fireAll("rebirthed", rebirthCount + 1)
	return true
end

function PlotServer.collectSlime(self: Plot, player: Player, instanceId: string): boolean
	if type(instanceId) ~= "string" or #instanceId > 64 then
		return false
	end

	if not self:isOwner(player) then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end

	for index, slimeData in playerData.slimes() do
		if slimeData.instanceId ~= instanceId then
			continue
		end
		if not self:isPlayerNearPlaypen(player, slimeData.playpenLevel) then
			return false
		end

		local now = os.clock()
		local lastCollectedAt = self.lastCollectionAt[instanceId]
		if lastCollectedAt and now - lastCollectedAt < COLLECTION_REQUEST_COOLDOWN then
			return false
		end
		self.lastCollectionAt[instanceId] = now

		local amount = math.floor(math.max(0, slimeData.storedSlime))
		if amount <= 0 then
			return false
		end

		playerData.slimes[index].storedSlime(0)
		playerData.slimeCurrency(function(previous)
			return previous + amount
		end)
		self.networker:fireAll("slimeProductionUpdated", {
			[instanceId] = 0,
		})
		self.networker:fire(player, "slimeCollected", instanceId, amount)

		return true
	end

	return false
end

function PlotServer.destroy(self: Plot)
	self.destroyed = true
	self.activeRollSeed = nil
	self.currentMutationId = nil
	self.currentSlimeId = nil
	self.secondarySlimeId = nil
	self.secondaryMutationId = nil
	self.plotLevelPurchaseLocked = false
	if self.sellingHandle then
		self.sellingHandle:destroy()
		self.sellingHandle = nil
	end
	if self.upgradeHandle then
		self.upgradeHandle:destroy()
		self.upgradeHandle = nil
	end
	self.networker:destroy()
	self.plotModel:Destroy()
	self.levelTemplates:Destroy()
end

return PlotServer
