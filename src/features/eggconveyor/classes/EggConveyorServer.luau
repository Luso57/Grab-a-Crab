--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local LuckConfig = require(ReplicatedStorage.Source.Features.EggConveyor.Modules.LuckConfig)
local GiganticEggConfig = require(ReplicatedStorage.Source.Features.EggConveyor.Modules.GiganticEggConfig)
local EggServer = require(ServerScriptService.Features.Egg.Classes.EggServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)

local SPAWN_INTERVAL = 1.4
local TRAVEL_SPEED = 5
local DISTANCE_TOLERANCE = 2

local EggConveyorServer = {}
EggConveyorServer.__index = EggConveyorServer

export type EggConveyorServer = typeof(setmetatable({} :: {
	plotModel: Model,
	conveyorFolder: Folder,
	spawnA: BasePart,
	spawnB: BasePart,
	templatesByRarity: { [string]: { Model } },
	activeFolder: Folder,
	activeEggs: { [EggServer.EggServer]: boolean },
	purchasing: { [Player]: boolean },
	onNotEnoughMoney: (Player, string, boolean) -> (),
	onPurchased: (Player) -> (),
	random: Random,
	running: boolean,
	eggsUntilGigantic: number,
}, EggConveyorServer))

function EggConveyorServer.new(plotModel: Model, templates: { Model }, onNotEnoughMoney: (Player, string, boolean) -> (), onPurchased: (Player) -> ()): EggConveyorServer?
	local conveyor = plotModel:FindFirstChild("EggConveyor")
	if not conveyor or not conveyor:IsA("Folder") then
		warn(plotModel.Name .. " needs EggConveyor")
		return nil
	end
	local spawnA = conveyor:FindFirstChild("SpawnA")
	local spawnB = conveyor:FindFirstChild("SpawnB")
	if not spawnA or not spawnA:IsA("BasePart") or not spawnB or not spawnB:IsA("BasePart") then
		warn(plotModel.Name .. " needs SpawnA and SpawnB")
		return nil
	end
	if (spawnA.Position - spawnB.Position).Magnitude == 0 then
		warn(plotModel.Name .. " has overlapping egg conveyor markers")
		return nil
	end

	local templatesByRarity: { [string]: { Model } } = {}
	for _, template in templates do
		local rarity = Eggs.getRarity(template.Name)
		if rarity then
			local bucket = templatesByRarity[rarity]
			if not bucket then
				bucket = {}
				templatesByRarity[rarity] = bucket
			end
			table.insert(bucket, template)
		end
	end

	local activeFolder = Instance.new("Folder")
	activeFolder.Name = "ActiveEggs"
	activeFolder.Parent = conveyor
	return setmetatable({
		plotModel = plotModel,
		conveyorFolder = conveyor,
		spawnA = spawnA,
		spawnB = spawnB,
		templatesByRarity = templatesByRarity,
		activeFolder = activeFolder,
		activeEggs = {} :: { [EggServer.EggServer]: boolean },
		purchasing = {} :: { [Player]: boolean },
	onNotEnoughMoney = onNotEnoughMoney,
		onPurchased = onPurchased,
		random = Random.new(),
		running = false,
		eggsUntilGigantic = GiganticEggConfig.EGGS_PER_GIGANTIC,
	}, EggConveyorServer) :: EggConveyorServer
end

local function canCollect(self: EggConveyorServer, player: Player, egg: EggServer.EggServer): boolean
	if not self.running or not self.activeEggs[egg] or egg.destroyed or egg.model.Parent ~= self.activeFolder then
		return false
	end
	if player.Parent ~= Players or self.plotModel:GetAttribute("OwnerUserId") ~= player.UserId then
		return false
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - egg.driver.Position).Magnitude <= egg.prompt.MaxActivationDistance + DISTANCE_TOLERANCE
end

local function collect(self: EggConveyorServer, player: Player, egg: EggServer.EggServer)
	if self.purchasing[player] or not canCollect(self, player, egg) or not egg:reserve() then
		return
	end
	self.purchasing[player] = true
	local insufficientFunds = false
	local inventoryFull = false
	local ok, purchased = pcall(function(): string?
		local eggId = egg.model:GetAttribute("EggId")
		if typeof(eggId) ~= "string" then
			return nil
		end
		local definition = Eggs.get(eggId)
		if not definition then
			return nil
		end
		local price = definition.price
		local data = Data.Service:waitForData(player)
		if not data or not canCollect(self, player, egg) then
			return nil
		end
		local money = Money.get(data, "money")
		if Money.compare(money, tostring(price)) < 0 then
			insufficientFunds = true
			return nil
		end
		local instanceId = InventoryServiceServer:grantItem(player, "Egg." .. eggId, function()
			return canCollect(self, player, egg) and Money.compare(Money.get(data, "money"), tostring(price)) >= 0
		end, nil, egg.model:GetAttribute("IsGiganticEgg") == true)
		if not instanceId then
			local currentMoney = Money.get(data, "money")
			insufficientFunds = Money.compare(currentMoney, tostring(price)) < 0
			inventoryFull = not insufficientFunds and InventoryServiceServer:isFull(player)
			return nil
		end
		if price > 0 then
			Money.set(data, "money", Money.subtract(Money.get(data, "money"), tostring(price)))
		end
		return instanceId
	end)
	self.purchasing[player] = nil
	if ok and purchased then
		self.activeEggs[egg] = nil
		egg:destroy()
		TutorialServiceServer:eggBought(player, purchased)
		local equipped, err = pcall(function()
			InventoryServiceServer:equipGrantedEgg(player, purchased)
		end)
		if not equipped then
			warn("Could not auto-equip purchased egg:", err)
		end
		self.onPurchased(player)
	else
		egg:release()
		if ok and insufficientFunds then
			local eggId = egg.model:GetAttribute("EggId")
			if typeof(eggId) == "string" then
				self.onNotEnoughMoney(player, eggId, egg.model:GetAttribute("IsGiganticEgg") == true)
			end
		elseif ok and inventoryFull then
			InventoryServiceServer:showInventoryFull(player)
		end
		if not ok then
			warn("Egg purchase failed:", purchased)
		end
	end
end

local function chooseTemplate(self: EggConveyorServer): Model?
	local ownerUserId = self.plotModel:GetAttribute("OwnerUserId")
	local owner = if typeof(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
	if owner and TutorialServiceServer:isTutorialActive(owner) then
		local commonEggs = self.templatesByRarity.Common or {}
		if #commonEggs == 0 then
			return nil
		end
		return commonEggs[self.random:NextInteger(1, #commonEggs)]
	end
	-- Recalculate for every spawn so a purchased upgrade affects the next egg.
	local weights = LuckConfig.getWeights(self.plotModel:GetAttribute("ConveyorLuck"))
	local total = 0
	for _, entry in weights do
		local bucket = self.templatesByRarity[entry.rarity]
		if entry.weight > 0 and bucket and #bucket > 0 then
			total += entry.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = self.random:NextNumber(0, total)
	local lastAvailable: { Model }? = nil
	for _, entry in weights do
		local bucket = self.templatesByRarity[entry.rarity]
		if entry.weight > 0 and bucket and #bucket > 0 then
			lastAvailable = bucket
			roll -= entry.weight
			if roll <= 0 then
				return bucket[self.random:NextInteger(1, #bucket)]
			end
		end
	end
	-- Account for rounding at the upper edge of the random roll.
	return if lastAvailable then lastAvailable[self.random:NextInteger(1, #lastAvailable)] else nil
end

function EggConveyorServer.start(self: EggConveyorServer)
	if self.running then
		return
	end
	self.running = true
	self.eggsUntilGigantic = GiganticEggConfig.EGGS_PER_GIGANTIC
	self.conveyorFolder:SetAttribute("GiganticEggsRemaining", self.eggsUntilGigantic)
	task.spawn(function()
		task.wait(SPAWN_INTERVAL)
		while self.running do
			local template = chooseTemplate(self)
			if not template then
				task.wait(SPAWN_INTERVAL)
				continue
			end
			local ownerUserId = self.plotModel:GetAttribute("OwnerUserId")
			local owner = if typeof(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
			local isTutorialEgg = owner ~= nil and TutorialServiceServer:isBuyingEgg(owner)
			local isGigantic = not isTutorialEgg and self.eggsUntilGigantic == 1
			local egg = EggServer.new(template, self.activeFolder, self.spawnA, self.spawnB, TRAVEL_SPEED, isGigantic)
			if not isTutorialEgg then
				self.eggsUntilGigantic = if isGigantic then GiganticEggConfig.EGGS_PER_GIGANTIC else self.eggsUntilGigantic - 1
			end
			self.conveyorFolder:SetAttribute("GiganticEggsRemaining", self.eggsUntilGigantic)
			self.activeEggs[egg] = true
			egg:start(function()
				self.activeEggs[egg] = nil
			end, function(player)
				collect(self, player, egg)
			end)
			task.wait(SPAWN_INTERVAL)
		end
	end)
end

function EggConveyorServer.stop(self: EggConveyorServer)
	self.running = false
	self.conveyorFolder:SetAttribute("GiganticEggsRemaining", nil)
	for egg in self.activeEggs do
		egg:destroy()
	end
	table.clear(self.activeEggs)
	self.activeFolder:Destroy()
end

return EggConveyorServer
