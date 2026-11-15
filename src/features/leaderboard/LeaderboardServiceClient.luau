--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Vide = require(ReplicatedStorage.Packages.Vide)
local LeaderboardConfig = require(script.Parent.Modules.LeaderboardConfig)
local LeaderboardBoard = require(script.Parent.UI.LeaderboardBoard)

local LeaderboardServiceClient = {}
local initialized = false
local states: { [string]: any } = {}

function LeaderboardServiceClient:init()
	if initialized then
		return
	end
	initialized = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local folder = Workspace:WaitForChild("Leaderboard")
	for _, board in LeaderboardConfig.boards do
		local model = folder:WaitForChild(board.model)
		states[board.key] = Vide.source({ status = "Loading", rows = {} })
		LeaderboardBoard.mount(playerGui, model :: Model, board.key, board.title, states[board.key])
	end
	local networker = Networker.client.new("LeaderboardService", self)
	networker:fire("ready")
end

function LeaderboardServiceClient:updateBoards(snapshot: any)
	if typeof(snapshot) ~= "table" then
		return
	end
	for _, board in LeaderboardConfig.boards do
		local incoming = snapshot[board.key]
		if typeof(incoming) == "table" and typeof(incoming.rows) == "table" and states[board.key] then
			states[board.key](incoming)
		end
	end
end

return LeaderboardServiceClient
