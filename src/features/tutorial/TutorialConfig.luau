export type StepId = "roll" | "buySlime" | "collectSlime" | "depositSlime" | "collectMoney" | "upgradeSlime" | "done"
export type ActionId = "rolled" | "boughtSlime" | "collectedSlime" | "depositedSlime" | "collectedMoney" | "upgradedSlime"
export type TargetId = "rollButton" | "offerSlime" | "tutorialSlime" | "depositPad" | "cashPad"

export type StepDefinition = {
	number: number,
	text: string,
	target: TargetId?,
	action: ActionId?,
	nextStep: StepId?,
}

local TutorialConfig = {
	Version = 1,
	DoneDuration = 2,
	UpgradePromptCurrency = 300,
	PlotPromptCurrency = 11_000,
	Steps = {
		roll = {
			number = 1,
			text = "ROLL A SLIME",
			target = "rollButton",
			action = "rolled",
			nextStep = "buySlime",
		},
		buySlime = {
			number = 2,
			text = "BUY THE SLIME",
			target = "offerSlime",
			action = "boughtSlime",
			nextStep = "collectSlime",
		},
		collectSlime = {
			number = 3,
			text = "COLLECT SLIME",
			target = "tutorialSlime",
			action = "collectedSlime",
			nextStep = "depositSlime",
		},
		depositSlime = {
			number = 4,
			text = "SELL SLIME",
			target = "depositPad",
			action = "depositedSlime",
			nextStep = "collectMoney",
		},
		collectMoney = {
			number = 5,
			text = "COLLECT CASH",
			target = "cashPad",
			action = "collectedMoney",
			nextStep = "upgradeSlime",
		},
		upgradeSlime = {
			number = 6,
			text = "UPGRADE YOUR SLIME",
			target = "tutorialSlime",
			action = "upgradedSlime",
			nextStep = "done",
		},
		done = {
			number = 7,
			text = "ALL DONE!",
		},
	} :: { [StepId]: StepDefinition },
}

function TutorialConfig.isUpgradePromptActive(tutorial, currency: number, slimeLuckLevel: number, rebirths: number): boolean
	return tutorial.completed
		and tutorial.version == TutorialConfig.Version
		and rebirths <= 0
		and currency >= TutorialConfig.UpgradePromptCurrency
		and slimeLuckLevel <= 0
end

function TutorialConfig.isPlotPromptActive(tutorial, currency: number, plotLevel: number, rebirths: number): boolean
	return tutorial.completed
		and tutorial.version == TutorialConfig.Version
		and rebirths <= 0
		and currency >= TutorialConfig.PlotPromptCurrency
		and plotLevel <= 1
end

return TutorialConfig
