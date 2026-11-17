--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local Networker = require(ReplicatedStorage.Packages.Networker)
local SellConfig = require(ReplicatedStorage.Source.Features.SellStand.SellConfig)
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local SellStandBuilderServer = require(ServerScriptService.Features.SellStand.Modules.SellStandBuilderServer)

type SavedItem = { itemId: string, placedSlotId: string?, tankInstanceId: string?, incubatorInstanceId: string?, hatchAtUnixMs: number?, locked: boolean?, favorited: boolean? }
type Inventory = { [string]: SavedItem }
type Quote = { token: string, category: string, ids: { string }, total: number, expiresAt: number }

local SellStandServiceServer = {}
local initialized = false
local networker = nil
local prompt: ProximityPrompt? = nil
local openFor: { [Player]: boolean } = {}
local quotes: { [Player]: Quote } = {}
local busy: { [Player]: boolean } = {}

local function inRange(player: Player): boolean
	local currentPrompt = prompt
	local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	return player.Parent == Players and currentPrompt ~= nil and currentPrompt.Parent ~= nil
		and root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - (currentPrompt.Parent :: BasePart).Position).Magnitude <= SellConfig.interactionDistance
end

local function eligible(instanceId: string, item: SavedItem, category: string, inventory: Inventory): number?
	if typeof(item) ~= "table" or typeof(item.itemId) ~= "string"
		or item.placedSlotId ~= nil or item.tankInstanceId ~= nil or item.incubatorInstanceId ~= nil
		or item.hatchAtUnixMs ~= nil or item.locked == true or item.favorited == true then
		return nil
	end
	local itemCategory, value = SellConfig.getValue(item.itemId)
	if itemCategory ~= category or not value or value <= 0 then
		return nil
	end
	if item.itemId == "Incubator" or string.match(item.itemId, "^Tank%.") then
		for _, other in inventory do
			if typeof(other) == "table" and (other.incubatorInstanceId == instanceId or other.tankInstanceId == instanceId) then
				return nil
			end
		end
	end
	return value
end

local function makeQuote(inventory: Inventory, category: string): Quote
	local ids = {}
	local total = 0
	for instanceId, item in inventory do
		local value = eligible(instanceId, item, category, inventory)
		if value then
			table.insert(ids, instanceId)
			total += value
		end
	end
	table.sort(ids)
	return { token = HttpService:GenerateGUID(false), category = category, ids = ids, total = total, expiresAt = os.clock() + 15 }
end

local function send(player: Player, method: string, ...: any)
	if networker and player.Parent == Players then
		networker:fire(player, method, ...)
	end
end

function SellStandServiceServer:init()
	if initialized then return end
	initialized = true
	networker = Networker.server.new("SellStandService", self, { self.requestQuote, self.confirmSale, self.close })
	local _, newPrompt = SellStandBuilderServer.create()
	prompt = newPrompt
	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			if not inRange(player) then return end
			openFor[player] = true
			quotes[player] = nil
			send(player, "openDialogue")
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		openFor[player] = nil
		quotes[player] = nil
		busy[player] = nil
	end)
end

function SellStandServiceServer:close(player: Player)
	openFor[player] = nil
	quotes[player] = nil
end

function SellStandServiceServer:requestQuote(player: Player, category: any)
	if category ~= "Eggs" and category ~= "Crabs" and category ~= "Equipment" then return end
	if not openFor[player] or not inRange(player) or busy[player] then return end
	busy[player] = true
	local ok, result = pcall(function()
		local data = Data.Service:waitForData(player)
		if not data or not openFor[player] or not inRange(player) then return nil end
		return makeQuote(data.inventory() :: Inventory, category)
	end)
	busy[player] = nil
	if not ok then
		warn(`SellStand quote failed for {player.Name}: {result}`)
		send(player, "showError")
		return
	end
	local quote = result :: Quote?
	if not quote then
		send(player, "showError")
		return
	end
	if #quote.ids == 0 then
		quotes[player] = nil
		send(player, "showEmpty", category)
	else
		quotes[player] = quote
		send(player, "showQuote", category, #quote.ids, quote.total, quote.token)
	end
end

function SellStandServiceServer:confirmSale(player: Player, token: any)
	if typeof(token) ~= "string" or not openFor[player] or not inRange(player) or busy[player] then return end
	local quote = quotes[player]
	if not quote or quote.token ~= token then return end
	if os.clock() > quote.expiresAt then
		quotes[player] = nil
		send(player, "showChanged")
		return
	end
	quotes[player] = nil -- Consume before touching saved data; repeated requests cannot pay twice.
	busy[player] = true
	local ok, result = pcall(function()
		local data = Data.Service:waitForData(player)
		if not data or not openFor[player] or not inRange(player) then return nil end
		local inventory = data.inventory() :: Inventory
		local current = makeQuote(inventory, quote.category)
		if current.total ~= quote.total or #current.ids ~= #quote.ids then return "changed" end
		for index, instanceId in quote.ids do
			if current.ids[index] ~= instanceId then return "changed" end
		end
		local balance = Money.get(data, "money")
		local newBalance = Money.add(balance, tostring(quote.total))
		local updated = table.clone(inventory)
		local sold = {}
		for _, instanceId in quote.ids do
			updated[instanceId] = nil
			sold[instanceId] = true
		end
		local hotbar = table.clone(data.hotbar() :: { string })
		for index, instanceId in hotbar do
			if sold[instanceId] then hotbar[index] = InventoryConfig.emptySlot end
		end
		data.inventory(updated)
		data.hotbar(hotbar)
		Money.set(data, "money", newBalance)
		InventoryServiceServer:refreshTools(player)
		return "sold"
	end)
	busy[player] = nil
	if not ok then
		warn(`SellStand sale failed for {player.Name}: {result}`)
		send(player, "showError")
	elseif result == "sold" then
		send(player, "showSold", #quote.ids, quote.total)
	elseif result == "changed" then
		send(player, "showChanged")
	else
		send(player, "showError")
	end
end

return SellStandServiceServer
