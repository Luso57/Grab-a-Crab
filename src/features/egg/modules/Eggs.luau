--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)

export type EggDefinition = {
	name: string,
	imageId: number,
	price: number,
}

local definitions: { [string]: EggDefinition } = {
	AlienEgg = { name = "Alien Egg", imageId = assets.AlienEggImg, price = 300000000 },
	AngelEgg = { name = "Angel Egg", imageId = assets.AngelEggImg, price = 12000000 },
	ArtistEgg = { name = "Artist Egg", imageId = assets.ArtisitEggImg, price = 800 },
	BasicEgg = { name = "Basic Egg", imageId = assets.BasicEggImg, price = 50 },
	BeachEgg = { name = "Beach Egg", imageId = assets.BeachEggImg, price = 100 },
	BlueEgg = { name = "Blue Egg", imageId = assets.BlueEggImg, price = 200 },
	ChefEgg = { name = "Chef Egg", imageId = assets.ChefEggImg, price = 1200 },
	CookieEgg = { name = "Cookie Egg", imageId = assets.CookieEggImg, price = 1800 },
	CowboyEgg = { name = "Cowboy Egg", imageId = assets.CowboyEggImg, price = 3000 },
	DeepSeaEgg = { name = "Deep Sea Egg", imageId = assets.DeepSeaEggImg, price = 300000 },
	DevilEgg = { name = "Devil Egg", imageId = assets.DevilEggImg, price = 600000000 },
	FossilizedEgg = { name = "Fossilized Egg", imageId = assets.FossilizedEggImg, price = 12000 },
	FrozenEgg = { name = "Frozen Egg", imageId = assets.FrozenEggImg, price = 24000 },
	GhostEgg = { name = "Ghost Egg", imageId = assets.GhostEggImg, price = 600000 },
	JungleEgg = { name = "Jungle Egg", imageId = assets.JungleEggImg, price = 4800 },
	KingEgg = { name = "King Egg", imageId = assets.KingCrabEggImg, price = 12000000000 },
	MoonEgg = { name = "Moon Egg", imageId = assets.MoonEggImg, price = 120000000 },
	MossEgg = { name = "Moss Egg", imageId = assets.MossEggImg, price = 300 },
	NinjaEgg = { name = "Ninja Egg", imageId = assets.NinjaEggImg, price = 60000 },
	PirateEgg = { name = "Pirate Egg", imageId = assets.PirateEggImg, price = 90000 },
	PumpkinEgg = { name = "Pumpkin Egg", imageId = assets.PumpkinEggImg, price = 6000 },
	RadioactiveEgg = { name = "Radioactive Egg", imageId = assets.RadioActiveEggImg, price = 1200000000 },
	SakuraEgg = { name = "Sakura Egg", imageId = assets.SakuraEggImg, price = 1200000 },
	ScientistEgg = { name = "Scientist Egg", imageId = assets.ScientistEggImg, price = 108000 },
	SkeletonEgg = { name = "Skeleton Egg", imageId = assets.SkeletonEggImg, price = 120000 },
	StoneEgg = { name = "Stone Egg", imageId = assets.StoneEggImg, price = 400 },
	VampireEgg = { name = "Vampire Egg", imageId = assets.VampireEggImg, price = 1800000 },
	WatermelonEgg = { name = "Watermelon Egg", imageId = assets.WatermelonEggImg, price = 600 },
	ZombieEgg = { name = "Zombie Egg", imageId = assets.ZombieEggImg, price = 3000000 },
}

local Eggs = {}

function Eggs.get(eggId: string): EggDefinition?
	return definitions[eggId]
end

function Eggs.getCrabId(eggId: string): string?
	if not definitions[eggId] then
		return nil
	end
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local eggsFolder = if assetsFolder then assetsFolder:FindFirstChild("Eggs") else nil
	local template = if eggsFolder then eggsFolder:FindFirstChild(eggId) else nil
	local crabId = if template and template:IsA("Model") then template:GetAttribute("CrabId") else nil
	return if typeof(crabId) == "string" and Crabs.get(crabId) then crabId else nil
end

function Eggs.getRarity(eggId: string): Rarities.Rarity?
	local crabId = Eggs.getCrabId(eggId)
	local crab = if crabId then Crabs.get(crabId) else nil
	return if crab then crab.rarity else nil
end

function Eggs.getTemplates(): { Model }
	local folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Eggs", 10)
	local templates: { Model } = {}
	if not folder or not folder:IsA("Folder") then
		warn("Assets.Eggs folder is missing")
		return templates
	end
	local crabIds: { [string]: boolean } = {}
	for _, child in folder:GetChildren() do
		if not child:IsA("Model") or not child.PrimaryPart or not definitions[child.Name] then
			warn("Skipping invalid egg template:", child.Name)
			continue
		end
		local crabId = child:GetAttribute("CrabId")
		if typeof(crabId) ~= "string" or not Crabs.get(crabId) or crabIds[crabId] then
			warn("Skipping egg without a unique CrabId:", child.Name)
			continue
		end
		crabIds[crabId] = true
		table.insert(templates, child)
	end
	if #templates ~= 29 then
		warn("Expected 29 egg templates, found", #templates)
	end
	table.sort(templates, function(left, right)
		return left.Name < right.Name
	end)
	return templates
end

return Eggs
