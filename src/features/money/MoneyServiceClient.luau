--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage.Source.Game.Data).client
local Money = require(ReplicatedStorage.Source.Game.Money)
local Vide = require(ReplicatedStorage.Packages.Vide)
local MoneyHud = require(script.Parent.UI.MoneyHud)

local MoneyServiceClient = {}
local initialized = false
local playCollection: ((Vector2?) -> ())? = nil

function MoneyServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local initialBalance: any = Money.normalize(Data.money())
	local balance = Vide.source(initialBalance)
	local displayedBalance = initialBalance
	local savedBalance = initialBalance
	local startBalance = initialBalance
	local targetBalance = initialBalance
	local startTime = 0
	local animationConnection: RBXScriptConnection? = nil
	local function updateCountdown(now: number)
		local progress = math.clamp(now - startTime, 0, 1)
		displayedBalance = startBalance + (targetBalance - startBalance) * progress
		balance(displayedBalance)
		if progress >= 1 then
			if animationConnection then
				animationConnection:Disconnect()
				animationConnection = nil
			end
		end
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	Vide.mount(function()
		local gui, play = MoneyHud({ balance = balance }, playerGui)
		playCollection = play
		return gui
	end, playerGui)

	Data.money.Changed(function(value: any)
		value = Money.normalize(value)
		if typeof(value) ~= "number" or typeof(savedBalance) ~= "number" then
			savedBalance = value
			displayedBalance = value
			balance(value)
			return
		end
		local now = os.clock()
		if animationConnection then
			updateCountdown(now)
		end
		local previousSavedBalance = savedBalance
		savedBalance = value
		if value < previousSavedBalance then
			startBalance = displayedBalance
			targetBalance = value
			startTime = now
			if not animationConnection then
				animationConnection = RunService.RenderStepped:Connect(function()
					updateCountdown(os.clock())
				end)
			end
		elseif animationConnection then
			local increase = value - previousSavedBalance
			startBalance += increase
			targetBalance = value
			displayedBalance += increase
			balance(displayedBalance)
		else
			displayedBalance = value
			balance(value)
		end
	end)
	local currentBalance = Money.normalize(Data.money())
	if currentBalance ~= savedBalance then
		savedBalance = currentBalance
		displayedBalance = currentBalance
		balance(currentBalance)
	end
end

function MoneyServiceClient:playCollection(startPosition: Vector2?)
	local play = playCollection
	if play then
		play(startPosition)
	end
end

return MoneyServiceClient
