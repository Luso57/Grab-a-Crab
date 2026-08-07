local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local LeaderboardConfig = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardConfig)
local LeaderboardTypes = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardTypes)
local Networker = require(ReplicatedStorage.Packages.Networker)

type BoardKind = LeaderboardTypes.BoardKind
type Entry = LeaderboardTypes.Entry
type Snapshot = LeaderboardTypes.Snapshot

local MONEY_EXPONENT_SCALE = 1_000_000_000_000
local MONEY_MANTISSA_SCALE = 1_000_000_000
local MAX_SAFE_SCORE = 1e300

local LeaderboardServiceServer = {
	snapshot = {
		timePlayed = {},
		mostMoney = {},
		robuxSpent = {},
	} :: Snapshot,
	sessionStartedAt = {} :: { [Player]: number },
	nameCache = {} :: { [number]: string },
	refreshing = false,
}

local orderedStores = {
	timePlayed = DataStoreService:GetOrderedDataStore(`RNG_Global_TimePlayed_{LeaderboardConfig.StoreVersion}`),
	mostMoney = DataStoreService:GetOrderedDataStore(`RNG_Global_MostMoney_{LeaderboardConfig.StoreVersion}`),
	robuxSpent = DataStoreService:GetOrderedDataStore(`RNG_Global_RobuxSpent_{LeaderboardConfig.StoreVersion}`),
}
local displayStore = DataStoreService:GetDataStore(`RNG_Global_LeaderboardDisplay_{LeaderboardConfig.StoreVersion}`)

local function getSafeScore(value: number?): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(math.clamp(value, 0, MAX_SAFE_SCORE))
end

local function encodeMoney(value: number): number
	local score = getSafeScore(value)
	if score <= 0 then
		return 0
	end

	local exponent = math.floor(math.log10(score))
	local mantissa = score / 10 ^ exponent
	return exponent * MONEY_EXPONENT_SCALE + math.floor(mantissa * MONEY_MANTISSA_SCALE + 0.5)
end

local function decodeMoney(value: number): number
	local encoded = getSafeScore(value)
	if encoded <= 0 then
		return 0
	end

	local exponent = math.floor(encoded / MONEY_EXPONENT_SCALE)
	local mantissa = (encoded - exponent * MONEY_EXPONENT_SCALE) / MONEY_MANTISSA_SCALE
	return mantissa * 10 ^ exponent
end

local function getPlayerScores(player: Player): { [BoardKind]: number }?
	local playerData = Data[player]
	if not playerData then
		return nil
	end

	return {
		timePlayed = getSafeScore(playerData.timePlayedSeconds()),
		mostMoney = getSafeScore(playerData.currency()),
		robuxSpent = getSafeScore(playerData.robuxSpent()),
	}
end

local function commitSessionTime(player: Player)
	local startedAt = LeaderboardServiceServer.sessionStartedAt[player]
	local playerData = Data[player]
	if not startedAt or not playerData then
		return
	end

	local now = os.clock()
	local elapsed = math.max(0, math.floor(now - startedAt))
	LeaderboardServiceServer.sessionStartedAt[player] = now
	if elapsed > 0 then
		playerData.timePlayedSeconds(function(previous)
			return getSafeScore(previous) + elapsed
		end)
	end
end

local function getUsername(userId: number): string
	local cached = LeaderboardServiceServer.nameCache[userId]
	if cached then
		return cached
	end

	local success, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local username = if success and type(result) == "string" then result else `User {userId}`
	LeaderboardServiceServer.nameCache[userId] = username
	return username
end

local function writeOrderedScore(kind: BoardKind, userId: number, score: number)
	local store = orderedStores[kind]
	local storedScore = if kind == "mostMoney" then encodeMoney(score) else getSafeScore(score)
	local key = tostring(userId)

	local success, message = pcall(function()
		if storedScore > 0 then
			store:SetAsync(key, storedScore)
		else
			store:RemoveAsync(key)
		end
	end)
	if not success then
		warn(`Failed to write {kind} leaderboard score for {userId}: {message}`)
	end
end

local function writePlayer(player: Player)
	commitSessionTime(player)
	local scores = getPlayerScores(player)
	if not scores then
		return
	end

	local userId = player.UserId
	local displaySuccess, displayMessage = pcall(function()
		displayStore:SetAsync(tostring(userId), scores)
	end)
	if not displaySuccess then
		warn(`Failed to write leaderboard display scores for {userId}: {displayMessage}`)
	end

	writeOrderedScore("timePlayed", userId, scores.timePlayed)
	writeOrderedScore("mostMoney", userId, scores.mostMoney)
	writeOrderedScore("robuxSpent", userId, scores.robuxSpent)
end

local function readDisplayScores(userId: number): { [BoardKind]: number }?
	local success, result = pcall(displayStore.GetAsync, displayStore, tostring(userId))
	if success and type(result) == "table" then
		return result :: any
	end
	return nil
end

local function readBoard(kind: BoardKind): { Entry }
	local success, pages = pcall(orderedStores[kind].GetSortedAsync, orderedStores[kind], false, LeaderboardConfig.TopCount)
	if not success then
		warn(`Failed to read {kind} global leaderboard: {pages}`)
		return {}
	end

	local entries = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if not userId then
			continue
		end

		local displayScores = readDisplayScores(userId)
		local fallbackScore = if kind == "mostMoney" then decodeMoney(item.value) else item.value
		local displayScore = if displayScores then displayScores[kind] else nil
		table.insert(entries, {
			userId = userId,
			username = getUsername(userId),
			score = getSafeScore(displayScore or fallbackScore),
		})
	end

	return entries
end

local function mergeActivePlayers(kind: BoardKind, storedEntries: { Entry }): { Entry }
	local byUserId: { [number]: Entry } = {}
	for _, entry in storedEntries do
		if entry.score > 0 then
			byUserId[entry.userId] = entry
		end
	end

	for _, player in Players:GetPlayers() do
		local scores = getPlayerScores(player)
		if not scores then
			continue
		end
		local score = scores[kind]
		if score > 0 then
			byUserId[player.UserId] = {
				userId = player.UserId,
				username = player.Name,
				score = score,
			}
		else
			byUserId[player.UserId] = nil
		end
	end

	local merged = {}
	for _, entry in byUserId do
		table.insert(merged, entry)
	end
	table.sort(merged, function(a, b)
		if a.score == b.score then
			return a.userId < b.userId
		end
		return a.score > b.score
	end)
	while #merged > LeaderboardConfig.TopCount do
		table.remove(merged)
	end
	return merged
end

function LeaderboardServiceServer.refresh(self)
	if self.refreshing then
		return
	end
	self.refreshing = true

	for _, player in Players:GetPlayers() do
		writePlayer(player)
	end

	local nextSnapshot: Snapshot = {
		timePlayed = mergeActivePlayers("timePlayed", readBoard("timePlayed")),
		mostMoney = mergeActivePlayers("mostMoney", readBoard("mostMoney")),
		robuxSpent = mergeActivePlayers("robuxSpent", readBoard("robuxSpent")),
	}
	self.snapshot = nextSnapshot
	self.refreshing = false
	self.networker:fireAll("snapshot", nextSnapshot)
end

function LeaderboardServiceServer.requestSnapshot(self, player: Player)
	self.networker:fire(player, "snapshot", self.snapshot)
end

function LeaderboardServiceServer.recordRobuxSpent(player: Player, amount: number): boolean
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return false
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end
	playerData.robuxSpent(function(previous)
		return getSafeScore(previous) + amount
	end)
	return true
end

function LeaderboardServiceServer.init(self)
	self.networker = Networker.server.new("LeaderboardService", self, {
		self.requestSnapshot,
	})

	local function playerAdded(player: Player)
		Data.Service:waitForData(player)
		if player.Parent == Players then
			self.sessionStartedAt[player] = os.clock()
		end
	end

	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(playerAdded, player)
	end)
	Data.Service:addPlayerRemovingCallback(function(player)
		writePlayer(player)
		self.sessionStartedAt[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			writePlayer(player)
		end
	end)

	task.spawn(function()
		task.wait(2)
		while true do
			self:refresh()
			task.wait(LeaderboardConfig.RefreshInterval)
		end
	end)
end

return LeaderboardServiceServer
