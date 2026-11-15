--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local LeaderboardConfig = require(ReplicatedStorage.Source.Features.Leaderboard.Modules.LeaderboardConfig)

local LeaderboardServiceServer = {}
local initialized = false
local networker = nil
local startedAt: { [Player]: number } = {}
local published: { [number]: { [string]: number } } = {}
local publishing: { [Player]: boolean } = {}
local names: { [number]: string } = {}
local nameQueue: { number } = {}
local queuedNames: { [number]: boolean } = {}
local snapshots: { [string]: any } = {}
local stores: { [string]: OrderedDataStore } = {}

local function queueName(userId: number)
	if not names[userId] and not queuedNames[userId] then
		queuedNames[userId] = true
		table.insert(nameQueue, userId)
	end
end

local function values(data: any): { [string]: number }
	return {
		MostMoney = data.maxMoney(),
		TimePlayed = data.lifetimePlaySeconds(),
		BiggestCrabG = data.biggestCrabGrams(),
	}
end

local function publish(userId: number, currentValues: { [string]: number })
	local last = published[userId]
	if not last then
		last = {}
		published[userId] = last
	end
	for _, board in LeaderboardConfig.boards do
		local score = LeaderboardConfig.score(board.key, currentValues[board.key])
		if score > 0 and score > (last[board.key] or 0) then
			local ok, result = pcall(function()
				return stores[board.key]:UpdateAsync(tostring(userId), function(old: number?)
					return math.max(if typeof(old) == "number" then old else 0, score)
				end)
			end)
			if ok then
				last[board.key] = result
			else
				warn(`Leaderboard {board.key} write failed for {userId}: {result}`)
			end
		end
		task.wait(0.1)
	end
end

local function checkpoint(player: Player, data: any)
	local start = startedAt[player]
	if not start then
		return
	end
	local now = os.clock()
	startedAt[player] = now
	local elapsed = math.max(0, now - start)
	if elapsed > 0 then
		data.lifetimePlaySeconds(function(previous: number)
			return previous + elapsed
		end)
	end
end

local function publishPlayer(player: Player)
	if publishing[player] then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	publishing[player] = true
	checkpoint(player, data)
	publish(player.UserId, values(data))
	publishing[player] = nil
end

local function watchPlayer(player: Player)
	startedAt[player] = os.clock()
	names[player.UserId] = player.Name
	task.spawn(function()
		local data = Data.Service:waitForData(player)
		if not data or player.Parent ~= Players then
			return
		end
		local biggest = data.biggestCrabGrams()
		for _, item in data.inventory() do
			if typeof(item) == "table" and typeof(item.itemId) == "string"
				and string.match(item.itemId, "^Crab%.[%w_]+$")
				and typeof(item.weightGrams) == "number" and item.weightGrams == item.weightGrams
				and item.weightGrams > biggest and item.weightGrams <= 10000000000 then
				biggest = item.weightGrams
			end
		end
		if biggest > data.biggestCrabGrams() then
			data.biggestCrabGrams(biggest)
		end
		publishPlayer(player)
	end)
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		networker:fire(player, "updateBoards", snapshots)
	end
end

local function resolveNames()
	local batch: { number } = {}
	while #batch < 50 and #nameQueue > 0 do
		local userId = table.remove(nameQueue, 1)
		queuedNames[userId] = nil
		if not names[userId] then
			table.insert(batch, userId)
		end
	end
	if #batch == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, batch)
	if not ok then
		warn(`Leaderboard user names unavailable: {infos}`)
		for _, userId in batch do
			queueName(userId)
		end
		return
	end
	for _, info in infos do
		if typeof(info.Id) == "number" and typeof(info.Username) == "string" then
			names[info.Id] = info.Username
		end
	end
	for _, userId in batch do
		if not names[userId] then
			names[userId] = `Player {userId}`
		end
	end
	for _, board in LeaderboardConfig.boards do
		for _, row in snapshots[board.key].rows do
			row.name = names[row.userId] or row.name
		end
	end
	broadcast()
end

local function refreshBoard(key: string)
	local ok, page = pcall(function()
		return stores[key]:GetSortedAsync(false, 100)
	end)
	if not ok then
		warn(`Leaderboard {key} read failed: {page}`)
		if snapshots[key].status ~= "Ready" then
			snapshots[key] = { status = "Unavailable", rows = {} }
		end
		return
	end
	local entries = page:GetCurrentPage()
	local rows = {}
	for _, entry in entries do
		local userId = tonumber(entry.key)
		if userId and userId > 0 then
			queueName(userId)
			table.insert(rows, { userId = userId, score = entry.value })
		end
	end
	for _, row in rows do
		row.name = names[row.userId] or `Player {row.userId}`
		row.value = LeaderboardConfig.value(key, row.score)
		row.score = nil
	end
	snapshots[key] = { status = "Ready", rows = rows }
end

function LeaderboardServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	for _, board in LeaderboardConfig.boards do
		stores[board.key] = DataStoreService:GetOrderedDataStore("GrabACrab_Leaderboard_" .. board.key .. "_v1")
		snapshots[board.key] = { status = "Loading", rows = {} }
	end
	networker = Networker.server.new("LeaderboardService", self, { self.ready })
	Data.Service:addPlayerRemovingCallback(function(player, savedData)
		local start = startedAt[player]
		if start then
			savedData.lifetimePlaySeconds = (savedData.lifetimePlaySeconds or 0) + math.max(0, os.clock() - start)
			startedAt[player] = nil
		end
		local finalValues = {
			MostMoney = savedData.maxMoney or 0,
			TimePlayed = savedData.lifetimePlaySeconds or 0,
			BiggestCrabG = savedData.biggestCrabGrams or 0,
		}
		task.spawn(publish, player.UserId, finalValues)
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	task.spawn(function()
		while true do
			resolveNames()
			task.wait(15)
		end
	end)
	task.spawn(function()
		while true do
			for _, board in LeaderboardConfig.boards do
				refreshBoard(board.key)
				broadcast()
				task.wait(4)
			end
			task.wait(108)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				task.spawn(publishPlayer, player)
			end
		end
	end)
end

function LeaderboardServiceServer:ready(player: Player)
	if player.Parent == Players then
		networker:fire(player, "updateBoards", snapshots)
	end
end

return LeaderboardServiceServer
