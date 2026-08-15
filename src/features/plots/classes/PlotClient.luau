local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotTypes = require(ReplicatedStorage.Source.Features.Plots.PlotTypes)
local PlotLevelConfig = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelConfig)
local PlotLevelSlice = require(ReplicatedStorage.Source.Features.PlotLevels.PlotLevelSlice)
local InventorySlice = require(ReplicatedStorage.Source.Features.Inventory.InventorySlice)
local NotificationSlice = require(ReplicatedStorage.Source.Features.App.NotificationSlice)
local MonetizationServiceClient = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient)
local MonetizationPadBillboards = require(ReplicatedStorage.Source.Features.Monetization.Modules.MonetizationPadBillboards)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local CashCollectionVFX = require(ReplicatedStorage.Source.Features.Selling.Modules.CashCollectionVFX)
local DepositConfetti = require(ReplicatedStorage.Source.Features.Selling.Modules.DepositConfetti)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)
local SlimeClient = require(ReplicatedStorage.Source.Features.Slimes.Classes.SlimeClient)
local SlimeRollVFX = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeRollVFX)
local UpgradeSlice = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeSlice)
local RobuxBoardSlice = require(ReplicatedStorage.Source.Features.RobuxBoard.RobuxBoardSlice)

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
		playpenBases: { [number]: BasePart },
		collectCashAttachment: Attachment,
		collectCashEntryId: string,
		slimeDepositAttachment: Attachment,
		slimeDepositEntryId: string,
		slimeSignEntryId: string,
		upgradePadAttachment: Attachment,
		upgradePadEntryId: string,
		upgradeBoardEntryId: string?,
		robuxBoardEntryId: string?,
		monetizationBillboardCleanup: (() -> ())?,
		levelSignEntryId: string,
		currentSlime: SlimeClient.SlimeClient?,
		secondarySlime: SlimeClient.SlimeClient?,
		playpenSlimes: { SlimeClient.SlimeClient },
		rollPrompt: ProximityPrompt?,
		activeRoll: SlimeRollVFX.RollHandle?,
		secondaryActiveRoll: SlimeRollVFX.RollHandle?,
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

local function getUpperPlaypenBase(plotModel: Model, level: number): BasePart
	local levelModel = plotModel:WaitForChild(`PlayPenBaseLvl{level}`)
	assert(levelModel:IsA("Model"), `PlayPenBaseLvl{level} must be a Model`)
	local playpenArea = levelModel:WaitForChild("PlayPenArea")
	assert(playpenArea:IsA("BasePart"), `PlayPenBaseLvl{level}.PlayPenArea must be a BasePart`)
	return playpenArea
end

function PlotClient.teleportHome(self: PlotClient)
	self.networker:fire("teleportHome")
end

local function createRollSlimeBillboard(spawnerButton: BasePart)
	local existing = spawnerButton:FindFirstChild("RollSlimeBillboard")
	if existing then
		existing:Destroy()
	end
	local existingAttachment = spawnerButton:FindFirstChild("RollSlimeBillboardAttachment")
	if existingAttachment then
		existingAttachment:Destroy()
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "RollSlimeBillboardAttachment"
	attachment.Position = spawnerButton.CFrame:PointToObjectSpace(spawnerButton.Position + Vector3.new(0, 4, 0))
	attachment.Parent = spawnerButton

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RollSlimeBillboard"
	billboard.Adornee = attachment
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.Size = UDim2.fromScale(2.4, 2.4)
	billboard.Parent = spawnerButton

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxthumb://type=Asset&id=125264363254178&w=420&h=420"
	icon.Position = UDim2.fromScale(0.5, 0.32)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(0.66, 0.66)
	icon.Parent = billboard

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Position = UDim2.fromScale(0.05, 0.02)
	label.Size = UDim2.fromScale(0.9, 0.28)
	label.Text = "ROLL"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 32
	textConstraint.MinTextSize = 1
	textConstraint.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 3
	stroke.Parent = label
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

	return attachment, SellingSlice.actions.addDeposit(attachment, plotModel)
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

local function registerLevelSign(
	plotModel: Model,
	currentLevel: number,
	canPurchase: boolean,
	onPurchase: (() -> ())?
): string
	local levelSign = plotModel:WaitForChild("LevelSign")
	assert(levelSign:IsA("Model"), "Plot LevelSign must be a Model")

	local board = levelSign:WaitForChild("board")
	assert(board:IsA("BasePart"), "Plot LevelSign.board must be a BasePart")

	return PlotLevelSlice.actions.addSign(board, plotModel, currentLevel, canPurchase, onPurchase)
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

local function registerRobuxBoard(plotModel: Model): string
	local gamePassesBoard = plotModel:WaitForChild("GamePassesBoard")
	assert(gamePassesBoard:IsA("Model"), "Plot GamePassesBoard must be a Model")

	local title = gamePassesBoard:WaitForChild("Title")
	assert(title:IsA("BasePart"), "Plot GamePassesBoard.Title must be a BasePart")
	local board = gamePassesBoard:WaitForChild("Board")
	assert(board:IsA("BasePart"), "Plot GamePassesBoard.Board must be a BasePart")

	return RobuxBoardSlice.actions.addBoard(title, board)
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
	local monetizationBillboardCleanup = MonetizationPadBillboards.attach(
		plotData.plotModel,
		plotData.player == Players.LocalPlayer
	)

	local self = setmetatable({
		cf = plotData.cf,
		index = plotData.index,
		player = plotData.player,
		plotModel = plotData.plotModel,
		networker = nil :: any,
		spawner = spawner,
		playpenBase = playpenBase,
		playpenBases = { [PlotLevelConfig.StartingLevel] = playpenBase },
		collectCashAttachment = collectCashAttachment,
		collectCashEntryId = collectCashEntryId,
		slimeDepositAttachment = slimeDepositAttachment,
		slimeDepositEntryId = slimeDepositEntryId,
		slimeSignEntryId = slimeSignEntryId,
		levelSignEntryId = "",
		upgradePadAttachment = upgradePadAttachment,
		upgradePadEntryId = upgradePadEntryId,
		upgradeBoardEntryId = nil :: string?,
		robuxBoardEntryId = nil :: string?,
		monetizationBillboardCleanup = monetizationBillboardCleanup,
		currentSlime = nil,
		secondarySlime = nil,
		playpenSlimes = {},
		rollPrompt = nil,
		activeRoll = nil,
		secondaryActiveRoll = nil,
		promptConnection = nil,
		destroyed = false,
	}, PlotClient)

	for level = PlotLevelConfig.StartingLevel + 1, PlotLevelConfig.getLevel(plotData.plotLevel) do
		self.playpenBases[level] = getUpperPlaypenBase(self.plotModel, level)
	end

	self.networker = Networker.client.new(`Plot{self.index}`, self)
	local canPurchaseUpgrades = self.player == Players.LocalPlayer
	self.levelSignEntryId = registerLevelSign(
		self.plotModel,
		plotData.plotLevel,
		canPurchaseUpgrades,
		if canPurchaseUpgrades
			then function()
				self.networker:fire("purchasePlotLevel")
			end
			else nil
	)
	self.robuxBoardEntryId = registerRobuxBoard(self.plotModel)
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
		self:showSlime(plotData.currentSlimeId, plotData.currentMutationId)
	end
	if plotData.secondarySlimeId then
		self:showSlime(plotData.secondarySlimeId, plotData.secondaryMutationId, nil, 2, 4)
	end

	self:syncPlaypenSlimes(plotData.slimes)

	return self
end

function PlotClient.initModel(self: PlotClient)
	local buttonModel = self.plotModel:WaitForChild("Button")
	local spawnerButton = buttonModel:WaitForChild("SpawnerButton")
	local proximityPrompt = spawnerButton:WaitForChild("ProximityPrompt")

	assert(spawnerButton:IsA("BasePart"), "Plot roll button SpawnerButton must be a BasePart")
	assert(proximityPrompt:IsA("ProximityPrompt"), "Plot roll button is missing its ProximityPrompt")

	createRollSlimeBillboard(spawnerButton)
	self.rollPrompt = proximityPrompt
	self.promptConnection = proximityPrompt.Triggered:Connect(function()
		self.networker:fire("rollSlime")
	end)
end

function PlotClient.slimeBought(self: PlotClient, slimeData: SlimeData, offerIndex: number?)
	local normalizedOfferIndex = if offerIndex == 2 then 2 else 1
	local preview = if normalizedOfferIndex == 2 then self.secondarySlime else self.currentSlime
	if preview then
		preview:destroy()
	end
	if normalizedOfferIndex == 2 then
		self.secondarySlime = nil
	else
		self.currentSlime = nil
	end

	self:addPlaypenSlime(slimeData)
end

function PlotClient.addPlaypenSlime(self: PlotClient, slimeData: SlimeData)
	if self.destroyed then
		return
	end
	for _, slime in self.playpenSlimes do
		if slime.slimeData.instanceId == slimeData.instanceId then
			return
		end
	end

	local onTouched = if self.player == Players.LocalPlayer
		then function()
			if not self.destroyed then
				self.networker:fire("collectSlime", slimeData.instanceId)
			end
		end
		else nil
	local onClicked = if self.player == Players.LocalPlayer
		then function()
			UISounds.playSelect()
			InventorySlice.actions.inspectSlime(slimeData.instanceId)
		end
		else nil
	local assignedLevel = PlotLevelConfig.getLevel(slimeData.playpenLevel)
	local assignedPlaypen = self.playpenBases[assignedLevel] or self.playpenBase
	local slime = SlimeClient.newPlaypenSlime(slimeData, assignedPlaypen, onTouched, onClicked)
	table.insert(self.playpenSlimes, slime)
end

function PlotClient.syncPlaypenSlimes(self: PlotClient, slimes: { SlimeData })
	if self.destroyed then return end
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

function PlotClient.slimeUpgraded(self: PlotClient, instanceId: string, level: number)
	for _, slime in self.playpenSlimes do
		if slime.slimeData.instanceId == instanceId then
			slime:setLevel(level)
			if self.player == Players.LocalPlayer then
				DepositConfetti.playSound()
			end
			return
		end
	end
end

function PlotClient.slimeSold(self: PlotClient, instanceId: string)
	for index, slime in self.playpenSlimes do
		if slime.slimeData.instanceId == instanceId then
			slime:destroy()
			table.remove(self.playpenSlimes, index)
			return
		end
	end
end

function PlotClient.requestSlimeUpgrade(self: PlotClient, instanceId: string)
	if not self.destroyed and self.player == Players.LocalPlayer then
		self.networker:fire("upgradeSlime", instanceId)
	end
end

function PlotClient.requestSlimeSale(self: PlotClient, instanceId: string)
	if not self.destroyed and self.player == Players.LocalPlayer then
		self.networker:fire("sellSlime", instanceId)
	end
end

function PlotClient.requestRebirth(self: PlotClient)
	if not self.destroyed and self.player == Players.LocalPlayer then
		self.networker:fire("rebirth")
	end
end

function PlotClient.rebirthed(self: PlotClient, _rebirthCount: number)
	for _, slime in self.playpenSlimes do
		slime:destroy()
	end
	table.clear(self.playpenSlimes)
end

function PlotClient.plotLevelPurchased(self: PlotClient, level: number)
	if self.destroyed then
		return
	end

	local safeLevel = PlotLevelConfig.getLevel(level)
	if safeLevel > PlotLevelConfig.StartingLevel and self.playpenBases[safeLevel] == nil then
		self.playpenBases[safeLevel] = getUpperPlaypenBase(self.plotModel, safeLevel)
	end
	PlotLevelSlice.actions.setLevel(self.levelSignEntryId, safeLevel)
	if self.player == Players.LocalPlayer then
		UISounds.playSelect()
	end
end

function PlotClient.setPlotLevel(self: PlotClient, level: number)
	if self.destroyed or self.levelSignEntryId == "" then
		return
	end

	local safeLevel = PlotLevelConfig.getLevel(level)
	for unlockedLevel = PlotLevelConfig.StartingLevel + 1, safeLevel do
		if self.playpenBases[unlockedLevel] == nil then
			self.playpenBases[unlockedLevel] = getUpperPlaypenBase(self.plotModel, unlockedLevel)
		end
	end
	PlotLevelSlice.actions.setLevel(self.levelSignEntryId, safeLevel)
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

function PlotClient.plotFull(self: PlotClient)
	if self.destroyed or self.player ~= Players.LocalPlayer then
		return
	end

	NotificationSlice.actions.show("PLOT FULL! EXPAND OR SELL A SLIME")
end

function PlotClient.insufficientMoney(self: PlotClient)
	if self.destroyed or self.player ~= Players.LocalPlayer then
		return
	end

	NotificationSlice.actions.showInsufficientMoney()
end

function PlotClient.playSlimeRoll(
	self: PlotClient,
	winnerId: string,
	mutationId: string,
	animationSeed: number,
	secondaryWinnerId: string?,
	secondaryMutationId: string?,
	secondaryAnimationSeed: number?,
	durationScale: number?
)
	if self.destroyed
		or (self.activeRoll and self.activeRoll:isActive())
		or (self.secondaryActiveRoll and self.secondaryActiveRoll:isActive())
	then
		return
	end

	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end
	if self.secondarySlime then
		self.secondarySlime:destroy()
		self.secondarySlime = nil
	end

	if self.rollPrompt then
		self.rollPrompt.Enabled = false
	end

	local hasSecondary = secondaryWinnerId ~= nil and secondaryAnimationSeed ~= nil
	local remainingRolls = if hasSecondary then 2 else 1
	local function finishRoll()
		remainingRolls -= 1
		if remainingRolls == 0 and self.rollPrompt then
			self.rollPrompt.Enabled = true
		end
	end

	local primaryOffset = if hasSecondary then -4 else 0
	local primaryHandle: SlimeRollVFX.RollHandle
	primaryHandle = SlimeRollVFX.play(self.spawner, winnerId, animationSeed, function(finalRotation)
		if self.destroyed or self.activeRoll ~= primaryHandle then
			return
		end
		self.activeRoll = nil
		self:showSlime(winnerId, mutationId, finalRotation, 1, primaryOffset)
		finishRoll()
	end, durationScale, primaryOffset)
	self.activeRoll = primaryHandle

	if hasSecondary then
		local secondaryHandle: SlimeRollVFX.RollHandle
		secondaryHandle = SlimeRollVFX.play(
			self.spawner,
			secondaryWinnerId :: string,
			secondaryAnimationSeed :: number,
			function(finalRotation)
				if self.destroyed or self.secondaryActiveRoll ~= secondaryHandle then
					return
				end
				self.secondaryActiveRoll = nil
				self:showSlime(secondaryWinnerId :: string, secondaryMutationId, finalRotation, 2, 4)
				finishRoll()
			end,
			durationScale,
			4
		)
		self.secondaryActiveRoll = secondaryHandle
	end
end

function PlotClient.syncOffers(
	self: PlotClient,
	currentSlimeId: string?,
	currentMutationId: string?,
	secondarySlimeId: string?,
	secondaryMutationId: string?
)
	if self.destroyed then return end
	if self.currentSlime then
		self.currentSlime:destroy()
		self.currentSlime = nil
	end
	if self.secondarySlime then
		self.secondarySlime:destroy()
		self.secondarySlime = nil
	end
	if currentSlimeId then
		self:showSlime(currentSlimeId, currentMutationId, nil, 1, if secondarySlimeId then -4 else 0)
	end
	if secondarySlimeId then
		self:showSlime(secondarySlimeId, secondaryMutationId, nil, 2, 4)
	end
end

function PlotClient.promptBuySlimePurchase(self: PlotClient)
	if self.destroyed or self.player ~= Players.LocalPlayer then
		return
	end

	local prompted, message = MonetizationServiceClient:promptProduct("buySlime")
	if not prompted and message then
		warn(message)
	end
end

function PlotClient.slimeGranted(self: PlotClient, slimeData: SlimeData)
	self:addPlaypenSlime(slimeData)
end

function PlotClient.showSlime(
	self: PlotClient,
	slimeId: string,
	mutationId: string?,
	startingRotation: number?,
	offerIndex: number?,
	lateralOffset: number?
)
	local normalizedOfferIndex = if offerIndex == 2 then 2 else 1
	local currentPreview = if normalizedOfferIndex == 2 then self.secondarySlime else self.currentSlime
	if currentPreview then
		currentPreview:destroy()
	end

	local slime = SlimeClient.new({
		instanceId = "preview",
		slimeId = slimeId,
		mutationId = mutationId or "normal",
		storedSlime = 0,
		level = 1,
		upgradeInvestment = 0,
		playpenLevel = 1,
	}, self.spawner, self.player == Players.LocalPlayer, startingRotation, lateralOffset)

	if self.player == Players.LocalPlayer then
		slime.onBought = function()
			self.networker:fire("buySlime", normalizedOfferIndex)
		end
	end

	if normalizedOfferIndex == 2 then
		self.secondarySlime = slime
	else
		self.currentSlime = slime
	end
end

function PlotClient.destroy(self: PlotClient)
	self.destroyed = true
	if self.monetizationBillboardCleanup then
		self.monetizationBillboardCleanup()
		self.monetizationBillboardCleanup = nil
	end
	SellingSlice.actions.removeCashCollector(self.collectCashEntryId)
	self.collectCashAttachment:Destroy()
	SellingSlice.actions.removeDeposit(self.slimeDepositEntryId)
	self.slimeDepositAttachment:Destroy()
	SellingSlice.actions.removeSlimeSign(self.slimeSignEntryId)
	if self.levelSignEntryId ~= "" then
		PlotLevelSlice.actions.removeSign(self.levelSignEntryId)
		self.levelSignEntryId = ""
	end
	SellingSlice.actions.removeUpgradePad(self.upgradePadEntryId)
	self.upgradePadAttachment:Destroy()
	if self.upgradeBoardEntryId then
		UpgradeSlice.actions.removeBoard(self.upgradeBoardEntryId)
		self.upgradeBoardEntryId = nil
	end

	if self.robuxBoardEntryId then
		RobuxBoardSlice.actions.removeBoard(self.robuxBoardEntryId)
		self.robuxBoardEntryId = nil
	end
	if self.activeRoll then
		self.activeRoll:cancel()
		self.activeRoll = nil
	end
	if self.secondaryActiveRoll then
		self.secondaryActiveRoll:cancel()
		self.secondaryActiveRoll = nil
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
	if self.secondarySlime then
		self.secondarySlime:destroy()
		self.secondarySlime = nil
	end

	for _, slime in self.playpenSlimes do
		slime:destroy()
	end
	table.clear(self.playpenSlimes)

	self.networker:destroy()
	self.plotModel:Destroy()
end

return PlotClient
