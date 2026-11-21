local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataServiceTyped = require(ReplicatedStorage.Packages.DataServiceTyped)
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local Money = require(ReplicatedStorage.Source.Game.Money)

local data = DataServiceTyped({
	template = DataTemplate,
	profileStoreIndex = "Playtest3",
	useMock = false,
	resetData = true,
	dontSave = false,
})

if RunService:IsServer() then
	local service = data.server.Service
	local previousOnPlayerInit = service.onPlayerInit
	function service:onPlayerInit(player: Player, profileData: any)
		profileData.money = Money.normalize(profileData.money)
		profileData.maxMoney = Money.normalize(profileData.maxMoney)
		previousOnPlayerInit(self, player, profileData)
	end
end

return data
