--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local LuckConfig = require(ReplicatedStorage.Source.Features.EggConveyor.Modules.LuckConfig)
local EggServer = require(ServerScriptService.Features.Egg.Classes.EggServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)

local SPAWN_INTERVAL = 1.4
local TRAVEL_SPEED = 5
local DISTANCE_TOLERANCE = 2

local EggConveyorServer = {}
EggConveyorServer.__index = EggConveyorServer

export type EggConveyorServer = typeof(setmetatable({} :: {
	plotModel: Model,
	spawnA: BasePart,
	spawnB: BasePart,
	templatesByRarity: { [string]: { Model } },
	activeFolder: Folder,
	activeEggs: { [EggServer.EggServer]: boolean },
	purchasing: { [Player]: boolean },
	onNotEnoughMoney: (Player) -> (),
	onPurchased: (Player) -> (),
	random: Random,
	running: boolean,
}, EggConveyorServer))

function EggConveyorServer.new(plotModel: Model, templates: { Model }, onNotEnoughMoney: (Player) -> (), onPurchased: (Player) -> ()): EggConveyorServer?
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
		local money = data.money()
		if typeof(money) ~= "number" or money < price then
			insufficientFunds = typeof(money) == "number" and money < price
			return nil
		end
		local instanceId = InventoryServiceServer:grantItem(player, "Egg." .. eggId, function()
			return canCollect(self, player, egg) and data.money() >= price
		end)
		if not instanceId then
			local currentMoney = data.money()
			insufficientFunds = typeof(currentMoney) == "number" and currentMoney < price
			return nil
		end
		if price > 0 then
			data.money(data.money() - price)
		end
		return instanceId
	end)
	self.purchasing[player] = nil
	if ok and purchased then
		self.activeEggs[egg] = nil
		egg:destroy()
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
			self.onNotEnoughMoney(player)
		end
		if not ok then
			warn("Egg purchase failed:", purchased)
		end
	end
end

local function chooseTemplate(self: EggConveyorServer): Model?
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
	task.spawn(function()
		while self.running do
			local template = chooseTemplate(self)
			if not template then
				task.wait(SPAWN_INTERVAL)
				continue
			end
			local egg = EggServer.new(template, self.activeFolder, self.spawnA, self.spawnB, TRAVEL_SPEED)
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
	for egg in self.activeEggs do
		egg:destroy()
	end
	table.clear(self.activeEggs)
	self.activeFolder:Destroy()
end

return EggConveyorServer
