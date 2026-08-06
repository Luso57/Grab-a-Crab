local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local CashCollectionVFX = require(ReplicatedStorage.Source.Features.Selling.Modules.CashCollectionVFX)
local DepositConfetti = require(ReplicatedStorage.Source.Features.Selling.Modules.DepositConfetti)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)
local SlimeClient = require(ReplicatedStorage.Source.Features.Slimes.Classes.SlimeClient)
local SlimeRollVFX = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeRollVFX)
local UpgradeSlice = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeSlice)

local PlotClient = {}
PlotClient.__index = PlotClient

type SlimeData = DataTemplate.SlimeData

export type PlotClient = typeof(setmetatable(
	{} :: {
		cf: CFrame,
		index: number,
		player: Player,
		plotModel: Model,
		networker: Networker.Client,
		spawner: BasePart,
		playpenBase: BasePart,
		collectCashAttachment: Attachment,
		collectCashEntryId: string,
		slimeDepositAttachment: Attachment,
		slimeDepositEntryId: string,
		slimeSignEntryId: string,
		upgradePadAttachment: Attachment,
		upgradePadEntryId: string,
		upgradeBoardEntryId: string?,
		currentSlime: SlimeClient.SlimeClient?,
		playpenSlimes: { SlimeClient.SlimeClient },
		rollPrompt: ProximityPrompt?,
		activeRoll: SlimeRollVFX.RollHandle?,
		promptConnection: RBXScriptConnection?,
		destroyed: boolean,
	},
	PlotClient
))

local function getPlaypenBase(plotModel: Model): BasePart
	for _, descendant in plotModel:GetDescendants() do
		if descendant:IsA("BasePart") and string.lower(descendant.Name) == "playpenbase" then
			return descendant
		end
	end

	error("Plot is missing its PlaypenBase BasePart")
end

local function createSlimeDepositAttachment(plotModel: Model): (Attachment, string)
	local slimeDeposit = plotModel:WaitForChild("SlimeDeposit")
	assert(slimeDeposit:IsA("Model"), "Plot SlimeDeposit must be a Model")

	local adorneePart = slimeDeposit:FindFirstChildWhichIsA("BasePart", true)
	assert(adorneePart, "Plot SlimeDeposit must contain a BasePart")

	local boundingBoxCFrame, boundingBoxSize = slimeDeposit:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position
		+ boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2 + 2)

	local attachment = Instance.new("Attachment")
	attachment.Name = "DepositBillboardAttachment"
	attachment.Position = adorneePart.CFrame:PointToObjectSpace(topPosition)
	attachment.Parent = adorneePart

	return attachment, SellingSlice.actions.addDeposit(attachment)
end

local function createCollectCashAttachment(plotModel: Model): (Attachment, string)
	local collectCash = plotModel:WaitForChild("CollectCash")
	assert(collectCash:IsA("Model"), "Plot CollectCash must be a Model")

	local adorneePart = collectCash:FindFirstChildWhichIsA("BasePart", true)
	assert(adorneePart, "Plot CollectCash must contain a BasePart")

	local boundingBoxCFrame, boundingBoxSize = collectCash:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position
		+ boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2 + 2)

	local attachment = Instance.new("Attachment")
	attachment.Name = "CollectCashBillboardAttachment"
	attachment.Position = adorneePart.CFrame:PointToObjectSpace(topPosition)
	attachment.Parent = adorneePart

	return attachment, SellingSlice.actions.addCashCollector(attachment, plotModel)
end

local function registerSlimeSign(plotModel: Model): string
	local slimeSign = plotModel:WaitForChild("SlimeSign")
	assert(slimeSign:IsA("Model"), "Plot SlimeSign must be a Model")

	local display = slimeSign:WaitForChild("display")
	assert(display:IsA("BasePart"), "Plot SlimeSign.display must be a BasePart")

	return SellingSlice.actions.addSlimeSign(display, plotModel)
end

local function createUpgradePadAttachment(plotModel: Model): (Attachment, string)
	local upgradePad = plotModel:WaitForChild("UpgradePerSecond")
	assert(upgradePad:IsA("Model"), "Plot UpgradePerSecond must be a Model")

	local adorneePart = upgradePad:FindFirstChildWhichIsA("BasePart", true)
	assert(adorneePart, "Plot UpgradePerSecond must contain a BasePart")

	local boundingBoxCFrame, boundingBoxSize = upgradePad:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position
		+ boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2 + 2)

	local attachment = Instance.new("Attachment")
	attachment.Name = "UpgradePerSecondBillboardAttachment"
	attachment.Position = adorneePart.CFrame:PointToObjectSpace(topPosition)
	attachment.Parent = adorneePart

	return attachment, SellingSlice.actions.addUpgradePad(attachment, plotModel)
end

local function registerUpgradeBoard(
	plotModel: Model,
	canPurchase: boolean,
	onBuyLuckOne: (() -> ())?,
	onBuyLuckMax: (() -> ())?,
	onBuyCashOne: (() -> ())?,
	onBuyCashMax: (() -> ())?
): string
	local upgradeBoard = plotModel:WaitForChild("UpgradeBoard")
	assert(upgradeBoard:IsA("Model"), "Plot UpgradeBoard must be a Model")

	local title = upgradeBoard:WaitForChild("Title")
	assert(title:IsA("BasePart"), "Plot UpgradeBoard.Title must be a BasePart")
	local board = upgradeBoard:WaitForChild("board")
	assert(board:IsA("BasePart"), "Plot UpgradeBoard.board must be a BasePart")

	return UpgradeSlice.actions.addBoard(
		title,
		board,
		plotModel,
		canPurchase,
		onBuyLuckOne,
		onBuyLuckMax,
		onBuyCashOne,
		onBuyCashMax
	)
end

function PlotClient.new(plotData: PlotTypes.PlotData): PlotClient
	local slimeSpawner = plotData.plotModel:WaitForChild("SlimeSpawner")
	local spawner = slimeSpawner:WaitForChild("Spawner")
	assert(spawner:IsA("BasePart"), "Plot SlimeSpawner.Spawner must be a BasePart")
	local playpenBase = getPlaypenBase(plotData.plotModel)
	local collectCashAttachment, collectCashEntryId = createCollectCashAttachment(plotData.plotModel)
	local slimeDepositAttachment, slimeDepositEntryId = createSlimeDepositAttachment(plotData.plotModel)
	local slimeSignEntryId = registerSlimeSign(plotData.plotModel)
	local upgradePadAttachment, upgradePadEntryId = createUpgradePadAttachment(plotData.plotModel)

	local self = setmetatable({
		cf = plotData.cf,
		index = plotData.index,
		player = plotData.player,
		plotModel = plotData.plotModel,
		networker = nil :: any,
		spawner = spawner,
		playpenBase = playpenBase,
		collectCashAttachment = collectCashAttachment,
		collectCashEntryId = collectCashEntryId,
		slimeDepositAttachment = slimeDepositAttachment,
		slimeDepositEntryId = slimeDepositEntryId,
		slimeSignEntryId = slimeSignEntryId,
		upgradePadAttachment = upgradePadAttachment,
		upgradePadEntryId = upgradePadEntryId,
		upgradeBoardEntryId = nil :: string?,
		currentSlime = nil,
		playpenSlimes = {},
		rollPrompt = nil,
		activeRoll = nil,
		promptConnection = nil,
		destroyed = false,
	}, PlotClient)

	self.networker = Networker.client.new(`Plot{self.index}`, self)
	local canPurchaseUpgrades = self.player == Players.LocalPlayer
	self.upgradeBoardEntryId = registerUpgradeBoard(
		self.plotModel,
		canPurchaseUpgrades,
		if canPurchaseUpgrades
			then function()
				self.networker:fire("purchaseSlimeLuck", "single")
			end
			else nil,
		if canPurchaseUpgrades
			then function()
				self.networker:fire("purchaseSlimeLuck", "max")
			end
			else nil,
		if canPurchaseUpgrades
			then function()
				self.networker:fire("purchaseCashMultiplier", "single")
			end
			else nil,
		if canPurchaseUpgrades
			then function()
				self.networker:fire("purchaseCashMultiplier", "max")
			end
			else nil
	)

	if self.player == Players.LocalPlayer then
		self:initModel()
	end

	if plotData.currentSlimeId then
		self:showSlime(plotData.currentSlimeId)
	end

	self:syncPlaypenSlimes(plotData.slimes)

	return self
end

function PlotClient.initModel(self: PlotClient)
	local buttonModel = self.plotModel:WaitForChild("Button")
	local spawnerButton = buttonModel:WaitForChild("SpawnerButton")
	local proximityPrompt = spawnerButton:WaitForChild("ProximityPrompt")

	assert(proximityPrompt:IsA("ProximityPrompt"), "Plot roll button is missing its ProximityPrompt")

	self.rollPrompt = proximityPrompt
	self.promptConnection = proximityPrompt.Triggered:Connect(function()
		self.networker:fire("rollSlime")
	end)
end

function PlotClient.slimeBought(self: PlotClient, slimeData: SlimeData)
	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end

	self:addPlaypenSlime(slimeData)
end

function PlotClient.addPlaypenSlime(self: PlotClient, slimeData: SlimeData)
	if self.destroyed then
		return
	end

	local onTouched = if self.player == Players.LocalPlayer
		then function()
			if not self.destroyed then
				self.networker:fire("collectSlime", slimeData.instanceId)
			end
		end
		else nil
	local slime = SlimeClient.newPlaypenSlime(slimeData, self.playpenBase, onTouched)
	table.insert(self.playpenSlimes, slime)
end

function PlotClient.syncPlaypenSlimes(self: PlotClient, slimes: { SlimeData })
	for _, slime in self.playpenSlimes do
		slime:destroy()
	end
	table.clear(self.playpenSlimes)

	for _, slimeData in slimes do
		self:addPlaypenSlime(slimeData)
	end
end

function PlotClient.slimeProductionUpdated(self: PlotClient, productionUpdates: { [string]: number })
	for _, slime in self.playpenSlimes do
		local storedSlime = productionUpdates[slime.slimeData.instanceId]
		if storedSlime ~= nil then
			slime:setStoredSlime(storedSlime)
		end
	end
end

function PlotClient.slimeCollected(self: PlotClient, instanceId: string, _amount: number)
	for _, slime in self.playpenSlimes do
		if slime.slimeData.instanceId == instanceId then
			slime:playCollectionSound()
			return
		end
	end
end

function PlotClient.slimeDeposited(self: PlotClient, _amount: number)
	if self.destroyed or self.player ~= Players.LocalPlayer then
		return
	end

	DepositConfetti.play(self.plotModel)
end

function PlotClient.upgradePerSecondStepped(self: PlotClient)
	if self.destroyed or self.player ~= Players.LocalPlayer then
		return
	end

	DepositConfetti.playSound()
end

function PlotClient.cashCollected(self: PlotClient, amount: number)
	if self.destroyed or self.player ~= Players.LocalPlayer then
		return
	end

	CashCollectionVFX.play(amount)
end

function PlotClient.playSlimeRoll(self: PlotClient, winnerId: string, animationSeed: number)
	if self.destroyed or (self.activeRoll and self.activeRoll:isActive()) then
		return
	end

	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end

	if self.rollPrompt then
		self.rollPrompt.Enabled = false
	end

	local rollHandle: SlimeRollVFX.RollHandle
	rollHandle = SlimeRollVFX.play(self.spawner, winnerId, animationSeed, function(finalRotation)
		if self.destroyed or self.activeRoll ~= rollHandle then
			return
		end

		self.activeRoll = nil
		self:showSlime(winnerId, finalRotation)

		if self.rollPrompt then
			self.rollPrompt.Enabled = true
		end
	end)

	self.activeRoll = rollHandle
end

function PlotClient.showSlime(self: PlotClient, slimeId: string, startingRotation: number?)
	if self.currentSlime then
		self.currentSlime:destroy()
	end

	local slime = SlimeClient.new({
		instanceId = "preview",
		slimeId = slimeId,
		mutationId = "normal",
		storedSlime = 0,
	}, self.spawner, self.player == Players.LocalPlayer, startingRotation)

	if self.player == Players.LocalPlayer then
		slime.onBought = function()
			self.networker:fire("buySlime")
		end
	end

	self.currentSlime = slime
end

function PlotClient.destroy(self: PlotClient)
	self.destroyed = true
	SellingSlice.actions.removeCashCollector(self.collectCashEntryId)
	self.collectCashAttachment:Destroy()
	SellingSlice.actions.removeDeposit(self.slimeDepositEntryId)
	self.slimeDepositAttachment:Destroy()
	SellingSlice.actions.removeSlimeSign(self.slimeSignEntryId)
	SellingSlice.actions.removeUpgradePad(self.upgradePadEntryId)
	self.upgradePadAttachment:Destroy()
	if self.upgradeBoardEntryId then
		UpgradeSlice.actions.removeBoard(self.upgradeBoardEntryId)
		self.upgradeBoardEntryId = nil
	end

	if self.activeRoll then
		self.activeRoll:cancel()
		self.activeRoll = nil
	end

	if self.promptConnection then
		self.promptConnection:Disconnect()
		self.promptConnection = nil
	end

	self.rollPrompt = nil

	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end

	for _, slime in self.playpenSlimes do
		slime:destroy()
	end
	table.clear(self.playpenSlimes)

	self.networker:destroy()
	self.plotModel:Destroy()
end

return PlotClient
