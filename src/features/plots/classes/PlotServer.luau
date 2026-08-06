local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
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
local COLLECTION_HORIZONTAL_MARGIN = 6
local COLLECTION_VERTICAL_MARGIN = 10

export type Plot = typeof(setmetatable(
	{} :: {
		cf: CFrame,
		index: number,
		player: Player,
		plotModel: Model,
		playpenBase: BasePart,
		currentSlimeId: string?,
		networker: Networker.Server,
		activeRollSeed: number?,
		random: Random,
		destroyed: boolean,
		lastCollectionAt: { [string]: number },
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
		networker = nil :: any,
		activeRollSeed = nil,
		random = Random.new(),
		destroyed = false,
		lastCollectionAt = {},
		sellingHandle = nil,
		upgradeHandle = nil,
	}, PlotServer)

	local plotModel = PlotModel:Clone()
	plotModel:PivotTo(plotSpawn.part.CFrame)
	plotModel.Parent = workspace
	self.plotModel = plotModel
	self.playpenBase = self:getPlaypenBase()
	self.networker = Networker.server.new(`Plot{self.index}`, self, {
		self.rollSlime,
		self.buySlime,
		self.collectSlime,
		self.purchaseSlimeLuck,
		self.purchaseCashMultiplier,
	})

	Data.Service:waitForData(player)
	self:migrateSlimeData()
	self.upgradeHandle = UpgradeServiceServer.attachPlot(player, self.plotModel)
	self.sellingHandle = SellingServiceServer.attachPlot(player, self.plotModel, function(amount)
		self.networker:fire(player, "slimeDeposited", amount)
	end, function(amount)
		self.networker:fire(player, "cashCollected", amount)
	end, function()
		self.networker:fire(player, "upgradePerSecondStepped")
	end)
	self:startProduction()

	self.charInit(self)

	return self
end

function PlotServer.getPlaypenBase(self: Plot): BasePart
	for _, descendant in self.plotModel:GetDescendants() do
		if descendant:IsA("BasePart") and string.lower(descendant.Name) == "playpenbase" then
			return descendant
		end
	end

	error("Plot is missing its PlaypenBase BasePart")
end

function PlotServer.isPlayerNearPlaypen(self: Plot, player: Player): boolean
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local localPosition = self.playpenBase.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = self.playpenBase.Size / 2

	return math.abs(localPosition.X) <= halfSize.X + COLLECTION_HORIZONTAL_MARGIN
		and math.abs(localPosition.Z) <= halfSize.Z + COLLECTION_HORIZONTAL_MARGIN
		and math.abs(localPosition.Y) <= halfSize.Y + COLLECTION_VERTICAL_MARGIN
end

function PlotServer.migrateSlimeData(self: Plot)
	local playerData = Data[self.player]
	if not playerData then
		return
	end

	for index, slimeData in playerData.slimes() do
		local slimeValue = playerData.slimes[index]

		if not slimeData.instanceId then
			slimeValue.instanceId(HttpService:GenerateGUID(false))
		end

		if slimeData.mutationId == nil then
			slimeValue.mutationId("normal")
		end

		if slimeData.storedSlime == nil then
			slimeValue.storedSlime(0)
		end
	end
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

			for index, slimeData in playerData.slimes() do
				if not Slimes.isValidSlimeId(slimeData.slimeId) then
					continue
				end

				local income = Slimes.getSlimeInfo(slimeData.slimeId).income
				local storedSlime = playerData.slimes[index].storedSlime(function(previous)
					return previous + income
				end)

				productionUpdates[slimeData.instanceId] = storedSlime
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
		slimes = savedSlimes,
	}
end

function PlotServer.charInit(self: Plot)
	local character = self.player.Character or self.player.CharacterAdded:Wait()

	character:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	self.player.CharacterAdded:Connect(function(newCharacter)
		newCharacter:PivotTo(self.plotModel:GetPivot() * CHAR_SPAWN_OFFSET)
	end)
end

function PlotServer.isOwner(self: Plot, player: Player): boolean
	return self.player == player
end

function PlotServer.rollSlime(self: Plot, player: Player): boolean
	if not self:isOwner(player) or self.activeRollSeed then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end

	local luckMultiplier = UpgradeConfig.getLuckMultiplier(playerData.slimeLuckLevel())
	local slimeId = Slimes.getLuckyRandomSlimeId(luckMultiplier, self.random)
	local animationSeed = self.random:NextInteger(1, 2_147_483_647)
	self.currentSlimeId = slimeId
	self.activeRollSeed = animationSeed

	self.networker:fireAll("playSlimeRoll", slimeId, animationSeed)

	task.delay(ROLL_LOCK_DURATION, function()
		if self.activeRollSeed == animationSeed then
			self.activeRollSeed = nil
		end
	end)

	return true
end

function PlotServer.buySlime(self: Plot, player: Player): boolean
	if not self:isOwner(player) then
		return false
	end

	local slimeId = self.currentSlimeId
	if not slimeId or not Slimes.isValidSlimeId(slimeId) then
		return false
	end

	local slimeInfo = Slimes.getSlimeInfo(slimeId)
	local cost = slimeInfo.cost
	local playerData = Data[player]
	if not playerData then
		return false
	end

	local currency = playerData.currency()

	print(`{player.Name} has {currency} currency; {slimeInfo.name} costs {cost}`)

	if currency < cost then
		return false
	end

	local slimeData: DataTemplate.SlimeData = {
		instanceId = HttpService:GenerateGUID(false),
		slimeId = slimeId,
		mutationId = "normal",
		storedSlime = 0,
	}

	playerData.currency(function(value)
		return value - cost
	end)
	playerData.slimes.Insert(slimeData)

	self.currentSlimeId = nil
	self.networker:fireAll("slimeBought", slimeData)

	return true
end

function PlotServer.purchaseSlimeLuck(self: Plot, player: Player, mode: UpgradeTypes.PurchaseMode): boolean
	if not self:isOwner(player) or (mode ~= "single" and mode ~= "max") or not self.upgradeHandle then
		return false
	end

	return UpgradeServiceServer.purchase(player, self.plotModel, mode)
end

function PlotServer.purchaseCashMultiplier(self: Plot, player: Player, mode: UpgradeTypes.PurchaseMode): boolean
	if not self:isOwner(player) or (mode ~= "single" and mode ~= "max") or not self.upgradeHandle then
		return false
	end

	return UpgradeServiceServer.purchaseCashMultiplier(player, self.plotModel, mode)
end

function PlotServer.collectSlime(self: Plot, player: Player, instanceId: string): boolean
	if type(instanceId) ~= "string" or #instanceId > 64 then
		return false
	end

	if not self:isOwner(player) or not self:isPlayerNearPlaypen(player) then
		return false
	end

	local now = os.clock()
	local lastCollectedAt = self.lastCollectionAt[instanceId]
	if lastCollectedAt and now - lastCollectedAt < COLLECTION_REQUEST_COOLDOWN then
		return false
	end
	self.lastCollectionAt[instanceId] = now

	local playerData = Data[player]
	if not playerData then
		return false
	end

	for index, slimeData in playerData.slimes() do
		if slimeData.instanceId ~= instanceId then
			continue
		end

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
end

return PlotServer
