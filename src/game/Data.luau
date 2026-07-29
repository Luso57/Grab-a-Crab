local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataServiceTyped = require(ReplicatedStorage.Packages.DataServiceTyped)
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)

return DataServiceTyped({
	template = DataTemplate,
	profileStoreIndex = "OFFICIAL",
	useMock = RunService:IsStudio(),
	resetData = false,
	dontSave = false,
})
