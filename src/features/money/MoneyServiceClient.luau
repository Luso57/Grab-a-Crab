--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage.Source.Game.Data).client
local Vide = require(ReplicatedStorage.Packages.Vide)
local MoneyHud = require(script.Parent.UI.MoneyHud)

local MoneyServiceClient = {}
local initialized = false
local playCollection: (() -> ())? = nil

function MoneyServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local initialBalance = Data.money()
	local balance = Vide.source(initialBalance)
	local countingDown = Vide.source(false)
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
			countingDown(false)
		end
	end
	Vide.mount(function()
		local gui, play = MoneyHud({ balance = balance, countingDown = countingDown })
		playCollection = play
		return gui
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))

	Data.money.Changed(function(value: number)
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
			countingDown(true)
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
	local currentBalance = Data.money()
	if currentBalance ~= savedBalance then
		savedBalance = currentBalance
		displayedBalance = currentBalance
		balance(currentBalance)
	end
end

function MoneyServiceClient:playCollection()
	local play = playCollection
	if play then
		play()
	end
end

return MoneyServiceClient
