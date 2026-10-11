local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServiceTyped = require(ReplicatedStorage.Packages.DataServiceTyped)
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)

return DataServiceTyped({
	template = DataTemplate,
	profileStoreIndex = "TEST",
	useMock = false,
	resetData = false,
	dontSave = false,
})
