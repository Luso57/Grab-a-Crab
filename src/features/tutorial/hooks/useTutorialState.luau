local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)
local TutorialConfig = require(ReplicatedStorage.Source.Features.Tutorial.TutorialConfig)

type TutorialData = DataTemplate.TutorialData

local function useTutorialState(): (TutorialData, boolean, boolean, boolean)
	local tutorial, setTutorial = React.useState(Data.tutorial())
	local currency, setCurrency = React.useState(Data.currency())
	local slimeLuckLevel, setSlimeLuckLevel = React.useState(Data.slimeLuckLevel())
	local plotLevel, setPlotLevel = React.useState(Data.plotLevel())
	local rebirths, setRebirths = React.useState(Data.rebirths())

	React.useEffect(function()
		local tutorialConnection = Data.tutorial.Changed(function(nextTutorial: TutorialData)
			setTutorial(table.clone(nextTutorial))
		end)
		local currencyConnection = Data.currency.Changed(setCurrency)
		local slimeLuckConnection = Data.slimeLuckLevel.Changed(setSlimeLuckLevel)
		local plotLevelConnection = Data.plotLevel.Changed(setPlotLevel)
		local rebirthsConnection = Data.rebirths.Changed(setRebirths)

		return function()
			tutorialConnection()
			currencyConnection()
			slimeLuckConnection()
			plotLevelConnection()
			rebirthsConnection()
		end
	end, {})

	local isActive = not tutorial.completed
		and tutorial.version == TutorialConfig.Version
		and TutorialConfig.Steps[tutorial.step] ~= nil
	local isUpgradePromptActive = TutorialConfig.isUpgradePromptActive(tutorial, currency, slimeLuckLevel, rebirths)
	local isPlotPromptActive = TutorialConfig.isPlotPromptActive(tutorial, currency, plotLevel, rebirths)

	return tutorial, isActive, isUpgradePromptActive, isPlotPromptActive
end

return useTutorialState
