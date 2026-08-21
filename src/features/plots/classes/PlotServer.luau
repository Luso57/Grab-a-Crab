local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local PlotLevelConfig = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelConfig)
local ProductEntitlements = require(ReplicatedStorage.Source.Features.Monetization.Modules.ProductEntitlements)
local SlimePurchaseProducts =
	require(ReplicatedStorage.Source.Features.Monetization.Modules.SlimePurchaseProducts)
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)
local SlimeDiscovery = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeDiscovery)
local SlimeEconomy = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeEconomy)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)
local SlimeUpgradeTypes = require(ReplicatedStorage.Source.Features.Slimes.SlimeUpgradeTypes)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)
local UpgradeConfig = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeConfig)
local UpgradeTypes = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeTypes)
local SellingConfig = require(ReplicatedStorage.Source.Features.Selling.SellingConfig)
local SellingServiceServer = require(ServerScriptService.Features.Selling.SellingServiceServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)
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
local PAID_LUCK_SPIN_MULTIPLIER = 5
local ROBUX_SLIME_INSTANCE_PREFIX = "robux-buy-slime:"

local function getSafeCurrency(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(math.max(0, value))
end

local function getSavedOffer(offer: DataTemplate.RolledSlimeOffer?): (string?, string?)
	if type(offer) ~= "table" or not Slimes.isValidSlimeId(offer.slimeId) then return nil, nil end
	return offer.slimeId, SlimeMutations.getId(offer.mutationId)
end

local function saveRolledOffers(
	playerData,
	primaryId: string?,
	primaryMutationId: string?,
	secondaryId: string?,
	secondaryMutationId: string?
)
	playerData.rolledSlimeOffers({
		primary = {
			slimeId = primaryId or "",
			mutationId = if primaryId then SlimeMutations.getId(primaryMutationId) else "normal",
		},
		secondary = {
			slimeId = secondaryId or "",
			mutationId = if secondaryId then SlimeMutations.getId(secondaryMutationId) else "normal",
		},
	})
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
		paidRandomItemsRestricted: boolean,
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
	characterConnection: RBXScriptConnection?,
		sellingHandle: SellingServiceServer.SellingHandle?,
		upgradeHandle: UpgradeServiceServer.UpgradeHandle?,
	},
	PlotServer
))

function PlotServer.new(player: Player, plotSpawn: PlotSpawn): Plot
	local self: any = setmetatable({
		player = player,
		cf = plotSpawn.part.CFrame,
		index = plotSpawn.index,
		currentSlimeId = nil,
		currentMutationId = nil,
		secondarySlimeId = nil,
		secondaryMutationId = nil,
		networker = nil,
		activeRollSeed = nil,
		random = Random.new(),
		destroyed = false,
		lastCollectionAt = {},
		lastHomeTeleportAt = 0,
		slimeManagementLocked = false,
		characterConnection = nil,
		plotModel = nil,
		playpenBase = nil,
		levelTemplates = nil,
		plotLevel = PlotLevelConfig.StartingLevel,
		plotLevelPurchaseLocked = false,
		paidRandomItemsRestricted = true,
		sellingHandle = nil,
		upgradeHandle = nil,
	}, PlotServer)

	local success, result = xpcall(function()
		local playerData = Data[player]
		assert(playerData, `Cannot create plot before data loads for {player.Name}`)

		local plotModel = PlotModel:Clone()
		self.plotModel = plotModel
		plotModel:PivotTo(plotSpawn.part.CFrame)
		self.levelTemplates = stagePlotLevels(plotModel, player, plotSpawn.index)
		plotModel.Parent = workspace
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

		self.plotLevel = PlotLevelConfig.getLevel(playerData.plotLevel())
		playerData.plotLevel(self.plotLevel)
		self:migrateSlimeData()
		local savedOffers = playerData.rolledSlimeOffers()
		self.currentSlimeId, self.currentMutationId = getSavedOffer(savedOffers.primary)
		self.secondarySlimeId, self.secondaryMutationId = getSavedOffer(savedOffers.secondary)
		saveRolledOffers(
			playerData,
			self.currentSlimeId,
			self.currentMutationId,
			self.secondarySlimeId,
			self.secondaryMutationId
		)
		for level = PlotLevelConfig.StartingLevel + 1, self.plotLevel do
			self:spawnPlotLevel(level)
		end

		self.upgradeHandle = UpgradeServiceServer.attachPlot(player, self.plotModel)
		self.sellingHandle = SellingServiceServer.attachPlot(player, self.plotModel, function(amount)
			self.networker:fire(player, "slimeDeposited", amount)
			TutorialServiceServer:recordAction(player, "depositedSlime")
		end, function(amount, isAutomatic)
			if not isAutomatic then self.networker:fire(player, "cashCollected", amount) end
			TutorialServiceServer:recordAction(player, "collectedMoney")
		end, function()
			self.networker:fire(player, "upgradePerSecondStepped")
		end, function()
			self.networker:fire(player, "insufficientMoney")
		end)

		self:startProduction()
		self:charInit()

		local legacyPendingSpins = math.max(0, math.floor(playerData.pending99xLuckSpins()))
		if legacyPendingSpins > 0 then
			playerData.pending5xLuckSpins(function(previous)
				return math.max(0, math.floor(previous)) + legacyPendingSpins
			end)
			playerData.pending99xLuckSpins(0)
		end
		if math.max(0, math.floor(playerData.pending5xLuckSpins())) > 0 then
			task.defer(function()
				if not self.destroyed then self:tryStartPending5xLuckSpin() end
			end)
		end
		return self
	end, debug.traceback)

	if not success then
		self:destroy()
		error(result, 0)
	end
	return result :: Plot
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

		if slimeData.purchasedWithRobux == nil then
			local legacyRobuxPurchase = type(slimeData.instanceId) == "string"
				and string.sub(slimeData.instanceId, 1, #ROBUX_SLIME_INSTANCE_PREFIX)
					== ROBUX_SLIME_INSTANCE_PREFIX
			slimeValue.purchasedWithRobux(legacyRobuxPurchase)
		elseif type(slimeData.purchasedWithRobux) ~= "boolean" then
			slimeValue.purchasedWithRobux(false)
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
					if wholeSlime > 0 then
						TutorialServiceServer:recordAction(self.player, "collectedSlime", slimeData.instanceId)
					end
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
	local function placeCharacter(character: Model)
		if self.destroyed or not character.Parent then
			return
		end
		character:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	end

	local character = self.player.Character
	if character then
		placeCharacter(character)
	end

	self.characterConnection = self.player.CharacterAdded:Connect(placeCharacter)
end

local function clearPendingBuySlime(playerData)
	playerData.pendingBuySlime({
		active = false,
		slimeId = "",
		mutationId = "normal",
		offerIndex = 1,
		playpenLevel = 1,
		productKey = "",
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

function PlotServer.loadPaidRandomItemsPolicy(self: Plot)
	local success, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(self.player)
	end)
	if self.destroyed or self.player.Parent ~= Players or not self.plotModel then
		return
	end
	self.paidRandomItemsRestricted = not success or policy.ArePaidRandomItemsRestricted == true
	local luckSpinButton = self.plotModel:FindFirstChild('99Button', true)
	if luckSpinButton then
		local prompt = luckSpinButton:FindFirstChild('ProximityPrompt', true)
		if prompt and prompt:IsA('ProximityPrompt') then
			prompt.Enabled = not self.paidRandomItemsRestricted
		end
	end
end

function PlotServer.performRoll(self: Plot, player: Player, isPaidLuckSpin: boolean): boolean
	if isPaidLuckSpin and self.paidRandomItemsRestricted then
		return false
	end
	if not self:isOwner(player) or self.activeRollSeed or self.destroyed then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end
	if not isPaidLuckSpin and math.max(0, math.floor(playerData.pending5xLuckSpins())) > 0 then
		task.defer(function()
			self:tryStartPending5xLuckSpin()
		end)
		return false
	end

	local currency = getSafeCurrency(playerData.currency())
	local ownedSlimes = playerData.slimes()
	local needsFreeStarter = not isPaidLuckSpin
		and #ownedSlimes == 0
		and (currency == 0 or TutorialServiceServer:isOnStep(player, "roll"))
	local luckMultiplier = UpgradeConfig.getLuckMultiplier(playerData.slimeLuckLevel())
		* RebirthConfig.getRewardMultiplier(playerData.rebirths())
		* ProductEntitlements.getLuckMultiplier(playerData)
	if isPaidLuckSpin then
		luckMultiplier *= PAID_LUCK_SPIN_MULTIPLIER
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
	saveRolledOffers(playerData, slimeId, mutationId, secondarySlimeId, secondaryMutationId)
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
			self:tryStartPending5xLuckSpin()
		end
	end)

	return true
end

function PlotServer.tryStartPending5xLuckSpin(self: Plot): boolean
	if self.destroyed or self.activeRollSeed then
		return false
	end

	local playerData = Data[self.player]
	if not playerData then
		return false
	end
	local pending = math.max(0, math.floor(playerData.pending5xLuckSpins()))
	if pending <= 0 then
		return false
	end

	if not self:performRoll(self.player, true) then
		return false
	end
	playerData.pending5xLuckSpins(pending - 1)
	return true
end

function PlotServer.complete5xLuckSpinReceipt(self: Plot): boolean
	if self.paidRandomItemsRestricted then
		return true
	end
	local playerData = Data[self.player]
	if not playerData or self.destroyed then
		return false
	end

	playerData.pending5xLuckSpins(function(previous)
		return math.max(0, math.floor(previous)) + 1
	end)
	task.defer(function()
		self:tryStartPending5xLuckSpin()
	end)
	return true
end

function PlotServer.completeFinishNowReceipt(self: Plot): boolean
	if self.destroyed then
		return false
	end

	local playerData = Data[self.player]
	if not playerData then return false end
	local currencyBefore = getSafeCurrency(playerData.currency())
	local completed = SellingServiceServer.finishQueue(self.player, self.plotModel)
	if completed and getSafeCurrency(playerData.currency()) > currencyBefore then
		TutorialServiceServer:recordAction(self.player, "collectedMoney")
	end
	return completed
end

function PlotServer.rollSlime(self: Plot, player: Player): boolean
	local rolled = self:performRoll(player, false)
	if rolled then
		TutorialServiceServer:recordAction(player, "rolled")
	end
	return rolled
end
function PlotServer.buySlime(self: Plot, player: Player, offerIndex: number?): boolean
	if self.paidRandomItemsRestricted then
		return false
	end
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
		if Slimes.isValidSlimeId(existingPending.slimeId) then
			local pendingRarity = Slimes.getSlimeInfo(existingPending.slimeId).rarity
			local pendingProductKey = SlimePurchaseProducts.getProductKey(pendingRarity)
			if pendingProductKey then
				self.networker:fire(player, "promptBuySlimePurchase", pendingProductKey)
			end
		else
			clearPendingBuySlime(playerData)
		end
		return false
	end
	local playpenLevel = self:getAvailablePlaypenLevel()
	if playpenLevel == nil then
		self.networker:fire(player, "plotFull")
		return false
	end

	local currency = getSafeCurrency(playerData.currency())
	if currency < cost then
		local productKey = SlimePurchaseProducts.getProductKey(slimeInfo.rarity)
		if not productKey then
			warn(string.format("Missing developer product for slime rarity: %s", slimeInfo.rarity))
			return false
		end
		self.networker:fire(player, "insufficientMoney")
		playerData.pendingBuySlime({
			active = true,
			slimeId = slimeId,
			mutationId = mutationId,
			offerIndex = normalizedOfferIndex,
			playpenLevel = playpenLevel,
			productKey = productKey,
		})
		self.networker:fire(player, "promptBuySlimePurchase", productKey)
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
		purchasedWithRobux = false,
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
	saveRolledOffers(
		playerData,
		self.currentSlimeId,
		self.currentMutationId,
		self.secondarySlimeId,
		self.secondaryMutationId
	)
	self.networker:fireAll("slimeBought", slimeData, normalizedOfferIndex)
	TutorialServiceServer:recordAction(player, "boughtSlime", slimeData.instanceId)

	return true
end

function PlotServer.completeBuySlimeReceipt(self: Plot, purchaseId: string, purchasedProductKey: string): boolean
	if self.destroyed or purchaseId == "" or not SlimePurchaseProducts.isProductKey(purchasedProductKey) then
		return false
	end

	local playerData = Data[self.player]
	if not playerData then
		return false
	end

	local instanceId = `{ROBUX_SLIME_INSTANCE_PREFIX}{purchaseId}`
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
			TutorialServiceServer:recordAction(self.player, "boughtSlime", slimeData.instanceId)
			return true
		end
	end

	local pending = playerData.pendingBuySlime()
	if not pending.active or not Slimes.isValidSlimeId(pending.slimeId) then
		return false
	end
	local slimeRarity = Slimes.getSlimeInfo(pending.slimeId).rarity
	local expectedProductKey = SlimePurchaseProducts.getProductKey(slimeRarity)
	if expectedProductKey ~= purchasedProductKey then
		local savedProductKey = if type(pending.productKey) == "string" then pending.productKey else ""
		local isLegacyGenericReceipt = savedProductKey == "" and purchasedProductKey == "buyCommonSlime"
		if not isLegacyGenericReceipt then
			return false
		end
	elseif type(pending.productKey) == "string"
		and pending.productKey ~= ""
		and pending.productKey ~= purchasedProductKey
	then
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
		purchasedWithRobux = true,
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
	if offerStillMatches then
		saveRolledOffers(
			playerData,
			self.currentSlimeId,
			self.currentMutationId,
			self.secondarySlimeId,
			self.secondaryMutationId
		)
	end

	clearPendingBuySlime(playerData)
	if offerStillMatches then
		self.networker:fireAll("slimeBought", slimeData, offerIndex)
	else
		self.networker:fireAll("slimeGranted", slimeData)
	end
	TutorialServiceServer:recordAction(self.player, "boughtSlime", slimeData.instanceId)
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
		purchasedWithRobux = false,
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
			if playerData.hasPurchasedBoardCashUpgrade() then
				promptUpgradePurchase(self, playerData, "luck", mode)
			else
				self.networker:fire(player, "insufficientMoney")
			end
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
			if playerData.hasPurchasedBoardCashUpgrade() then
				promptUpgradePurchase(self, playerData, "cash", mode)
			else
				self.networker:fire(player, "insufficientMoney")
			end
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
function PlotServer.upgradeSlime(
	self: Plot,
	player: Player,
	instanceId: string
): (SlimeUpgradeTypes.Result, number?, number?)
	if not self:isOwner(player)
		or self.slimeManagementLocked
		or type(instanceId) ~= "string"
		or #instanceId > 64
	then
		return "rejected"
	end

	local playerData = Data[player]
	if not playerData then
		return "rejected"
	end

	for index, slimeData in playerData.slimes() do
		if slimeData.instanceId ~= instanceId or not Slimes.isValidSlimeId(slimeData.slimeId) then
			continue
		end

		local slimeInfo = Slimes.getSlimeInfo(slimeData.slimeId)
		local level = SlimeEconomy.getLevel(slimeData.level)
		local upgradeCost = SlimeEconomy.getUpgradeCost(slimeInfo.cost, level)
		local currency = getSafeCurrency(playerData.currency())
		if upgradeCost == math.huge or currency < upgradeCost then
			if upgradeCost ~= math.huge then
				self.networker:fire(player, "insufficientMoney")
			end
			return "insufficientMoney", level, currency
		end

		local previousInvestment = math.max(0, slimeData.upgradeInvestment or 0)
		local nextLevel = level + 1
		local nextCurrency = currency - upgradeCost
		local nextInvestment = previousInvestment + upgradeCost

		self.slimeManagementLocked = true
		local success, upgradeError = xpcall(function()
			playerData.slimes[index].level(nextLevel)
			playerData.slimes[index].upgradeInvestment(nextInvestment)
			playerData.currency(nextCurrency)
		end, debug.traceback)

		if not success then
			local rollbackSuccess, rollbackError = xpcall(function()
				playerData.slimes[index].level(level)
				playerData.slimes[index].upgradeInvestment(previousInvestment)
				playerData.currency(currency)
			end, debug.traceback)
			self.slimeManagementLocked = false
			warn(`[SlimeUpgrade] Failed to upgrade {instanceId} for {player.Name}: {upgradeError}`)
			if not rollbackSuccess then
				warn(`[SlimeUpgrade] Failed to roll back {instanceId} for {player.Name}: {rollbackError}`)
			end
			return "failed", level, getSafeCurrency(playerData.currency())
		end

		self.slimeManagementLocked = false
		local broadcastSuccess, broadcastError = pcall(function()
			self.networker:fireAll("slimeUpgraded", instanceId, nextLevel)
		end)
		if not broadcastSuccess then
			warn(`[SlimeUpgrade] Failed to broadcast {instanceId}: {broadcastError}`)
		end
		pcall(function()
			TutorialServiceServer:recordAction(player, "upgradedSlime", instanceId)
		end)
		return "success", nextLevel, nextCurrency
	end

	return "notFound"
end

function PlotServer.sellSlime(self: Plot, player: Player, instanceId: string): boolean
	if not self:isOwner(player)
		or self.slimeManagementLocked
		or type(instanceId) ~= "string"
		or #instanceId > 64
	then
		return false
	end
	if TutorialServiceServer:isProtectedSlime(player, instanceId) then
		self.networker:fire(player, "tutorialSlimeProtected")
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
	playerData.slimesPerSecond(SellingConfig.DefaultSlimesPerSecond)
	playerData.sellUpgradeLevel(0)
	playerData.slimeLuckLevel(0)
	playerData.cashMultiplierLevel(0)
	local preservedSlimes: { DataTemplate.SlimeData } = {}
	for _, slimeData in playerData.slimes() do
		if slimeData.purchasedWithRobux == true and Slimes.isValidSlimeId(slimeData.slimeId) then
			table.insert(preservedSlimes, {
				instanceId = slimeData.instanceId,
				slimeId = slimeData.slimeId,
				mutationId = SlimeMutations.getId(slimeData.mutationId),
				storedSlime = 0,
				level = 1,
				upgradeInvestment = 0,
				playpenLevel = PlotLevelConfig.getLevel(slimeData.playpenLevel),
				purchasedWithRobux = true,
			})
		end
	end
	playerData.slimes(preservedSlimes)
	self.activeRollSeed = nil
	self.currentSlimeId = nil
	self.currentMutationId = nil
	self.secondarySlimeId = nil
	self.secondaryMutationId = nil
	saveRolledOffers(playerData, nil, nil, nil, nil)
	playerData.rebirths(rebirthCount + 1)
	table.clear(self.lastCollectionAt)
	self.slimeManagementLocked = false

	SellingServiceServer.refresh(player, self.plotModel)
	self.networker:fireAll("syncOffers", nil, nil, nil, nil)
	self.networker:fireAll("rebirthed", rebirthCount + 1, preservedSlimes)
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
		TutorialServiceServer:recordAction(player, "collectedSlime", instanceId)

		return true
	end

	return false
end

function PlotServer.destroy(self: Plot)
	if self.destroyed then return end
	self.destroyed = true
	local function cleanup(label: string, callback: () -> ())
		local success, cleanupError = xpcall(callback, debug.traceback)
		if not success then
			warn(`[PlotAssignment] Failed to clean {label} for plot {self.index}: {cleanupError}`)
		end
	end

	if self.characterConnection then
		cleanup("character connection", function() self.characterConnection:Disconnect() end)
		self.characterConnection = nil
	end
	self.activeRollSeed = nil
	self.currentMutationId = nil
	self.currentSlimeId = nil
	self.secondarySlimeId = nil
	self.secondaryMutationId = nil
	self.plotLevelPurchaseLocked = false
	if self.sellingHandle then
		cleanup("selling handle", function() self.sellingHandle:destroy() end)
		self.sellingHandle = nil
	end
	if self.upgradeHandle then
		cleanup("upgrade handle", function() self.upgradeHandle:destroy() end)
		self.upgradeHandle = nil
	end
	if self.networker then
		cleanup("networker", function() self.networker:destroy() end)
		rawset(self :: any, "networker", nil)
	end
	if self.plotModel then
		cleanup("plot model", function() self.plotModel:Destroy() end)
		rawset(self :: any, "plotModel", nil)
	end
	if self.levelTemplates then
		cleanup("level templates", function() self.levelTemplates:Destroy() end)
		rawset(self :: any, "levelTemplates", nil)
	end
end

return PlotServer
