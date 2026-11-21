--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).client
local RunService = game:GetService("RunService")

local TutorialHudVisibilityClient = {}
local initialized = false

local ALWAYS_VISIBLE_DURING_TUTORIAL = {
	TutorialStrip = true,
	MoneyHud = true,
	MoneyCollectionEffect = true,
	MoneyPadDisplay = true,
	InventoryHotbar = true,
	InventoryPanel = true,
	InventoryToggleGui = true,
	HatchReveal = true,
}

local SHOP_STAGE_ONLY = {
	TutorialShopOverlay = true,
}

local STATE_MANAGED_SCREEN_GUIS = {
	ShopMenu = true,
	DecorShopMenu = true,
	SellDialogue = true,
	TankPopup = true,
	IndexMenu = true,
	ShopMonoMenu = true,
	StarterPackMenu = true,
	HatchReveal = true,
}

local function isTutorialActive(stage: string): boolean
	return stage ~= "Complete" and stage ~= "Skipped"
end

function TutorialHudVisibilityClient:init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local originalEnabled: { [ScreenGui]: boolean } = setmetatable({}, { __mode = "k" })
	local stage = Data.tutorialStage()

	local function apply(screenGui: ScreenGui)
		if originalEnabled[screenGui] == nil then
			originalEnabled[screenGui] = screenGui.Enabled
		end

		if STATE_MANAGED_SCREEN_GUIS[screenGui.Name]
			and (stage == "VisitShop" or not isTutorialActive(stage)) then
			return
		end

		if not isTutorialActive(stage) then
			screenGui.Enabled = originalEnabled[screenGui]
			return
		end
		if stage == "VisitShop" then
			if not SHOP_STAGE_ONLY[screenGui.Name] then
				originalEnabled[screenGui] = true
			end
			screenGui.Enabled = true
			return
		end

		local allowed = ALWAYS_VISIBLE_DURING_TUTORIAL[screenGui.Name] == true
		if not allowed then
			screenGui.Enabled = false
		end
	end

	local function watch(instance: Instance)
		if instance:IsA("ScreenGui") then
			apply(instance)
		end
	end

	playerGui.ChildAdded:Connect(watch)
	for _, child in playerGui:GetChildren() do
		watch(child)
	end

	Data.tutorialStage.Changed(function(value: string)
		stage = value
		for _, child in playerGui:GetChildren() do
			watch(child)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		stage = Data.tutorialStage()
		for _, child in playerGui:GetChildren() do
			watch(child)
		end
	end)
end

return TutorialHudVisibilityClient
