--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).client
local Vide = require(ReplicatedStorage.Packages.Vide)
local MoneyHud = require(script.Parent.UI.MoneyHud)

local MoneyServiceClient = {}
local initialized = false

function MoneyServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local balance = Vide.source(0)
	Vide.mount(function()
		return MoneyHud({ balance = balance })
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))

	Data.money.Changed(function(value: number)
		balance(value)
	end)
	balance(Data.money())
end

return MoneyServiceClient
