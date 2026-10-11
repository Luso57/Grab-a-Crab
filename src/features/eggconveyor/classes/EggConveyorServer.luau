--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local EggServer = require(ServerScriptService.Features.Egg.Classes.EggServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)

local SPAWN_INTERVAL = 1.6
local TRAVEL_SPEED = 5
local DISTANCE_TOLERANCE = 2

local EggConveyorServer = {}
EggConveyorServer.__index = EggConveyorServer

export type EggConveyorServer = typeof(setmetatable({} :: {
	plotModel: Model,
	spawnA: BasePart,
	spawnB: BasePart,
	templates: { Model },
	activeFolder: Folder,
	activeEggs: { [EggServer.EggServer]: boolean },
	random: Random,
	running: boolean,
}, EggConveyorServer))

function EggConveyorServer.new(plotModel: Model, templates: { Model }): EggConveyorServer?
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

	local activeFolder = Instance.new("Folder")
	activeFolder.Name = "ActiveEggs"
	activeFolder.Parent = conveyor
	return setmetatable({
		plotModel = plotModel,
		spawnA = spawnA,
		spawnB = spawnB,
		templates = templates,
		activeFolder = activeFolder,
		activeEggs = {} :: { [EggServer.EggServer]: boolean },
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
	if not canCollect(self, player, egg) or not egg:reserve() then
		return
	end
	local eggId = egg.model:GetAttribute("EggId")
	if typeof(eggId) ~= "string" then
		egg:release()
		return
	end
	local definition = Eggs.get(eggId)
	if not definition then
		egg:release()
		return
	end
	local instanceId = InventoryServiceServer:grantItem(player, "Egg." .. eggId, function()
		return canCollect(self, player, egg)
	end)
	if instanceId then
		self.activeEggs[egg] = nil
		egg:destroy()
	else
		egg:release()
	end
end

function EggConveyorServer.start(self: EggConveyorServer)
	if self.running or #self.templates == 0 then
		return
	end
	self.running = true
	task.spawn(function()
		while self.running do
			local template = self.templates[self.random:NextInteger(1, #self.templates)]
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
