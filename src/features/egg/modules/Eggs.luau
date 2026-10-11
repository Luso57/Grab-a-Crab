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
	AlienEgg = { name = "Alien Egg", imageId = assets.AlienEggImg, price = 2500000000000 },
	AngelEgg = { name = "Angel Egg", imageId = assets.AngelEggImg, price = 100000000000 },
	ArtistEgg = { name = "Artist Egg", imageId = assets.ArtisitEggImg, price = 5000000 },
	BasicEgg = { name = "Basic Egg", imageId = assets.BasicEggImg, price = 0 },
	BeachEgg = { name = "Beach Egg", imageId = assets.BeachEggImg, price = 0 },
	BlueEgg = { name = "Blue Egg", imageId = assets.BlueEggImg, price = 500000 },
	ChefEgg = { name = "Chef Egg", imageId = assets.ChefEggImg, price = 10000000 },
	CookieEgg = { name = "Cookie Egg", imageId = assets.CookieEggImg, price = 15000000 },
	CowboyEgg = { name = "Cowboy Egg", imageId = assets.CowboyEggImg, price = 25000000 },
	DeepSeaEgg = { name = "Deep Sea Egg", imageId = assets.DeepSeaEggImg, price = 2500000000 },
	DevilEgg = { name = "Devil Egg", imageId = assets.DevilEggImg, price = 5000000000000 },
	FossilizedEgg = { name = "Fossilized Egg", imageId = assets.FossilizedEggImg, price = 100000000 },
	FrozenEgg = { name = "Frozen Egg", imageId = assets.FrozenEggImg, price = 200000000 },
	GhostEgg = { name = "Ghost Egg", imageId = assets.GhostEggImg, price = 5000000000 },
	JungleEgg = { name = "Jungle Egg", imageId = assets.JungleEggImg, price = 40000000 },
	KingEgg = { name = "King Egg", imageId = assets.KingCrabEggImg, price = 100000000000000000 },
	MoonEgg = { name = "Moon Egg", imageId = assets.MoonEggImg, price = 1000000000000 },
	MossEgg = { name = "Moss Egg", imageId = assets.MossEggImg, price = 1000000 },
	NinjaEgg = { name = "Ninja Egg", imageId = assets.NinjaEggImg, price = 500000000 },
	PirateEgg = { name = "Pirate Egg", imageId = assets.PirateEggImg, price = 750000000 },
	PumpkinEgg = { name = "Pumpkin Egg", imageId = assets.PumpkinEggImg, price = 50000000 },
	RadioactiveEgg = { name = "Radioactive Egg", imageId = assets.RadioActiveEggImg, price = 10000000000000 },
	SakuraEgg = { name = "Sakura Egg", imageId = assets.SakuraEggImg, price = 10000000000 },
	ScientistEgg = { name = "Scientist Egg", imageId = assets.ScientistEggImg, price = 900000000 },
	SkeletonEgg = { name = "Skeleton Egg", imageId = assets.SkeletonEggImg, price = 1000000000 },
	StoneEgg = { name = "Stone Egg", imageId = assets.StoneEggImg, price = 1500000 },
	VampireEgg = { name = "Vampire Egg", imageId = assets.VampireEggImg, price = 15000000000 },
	WatermelonEgg = { name = "Watermelon Egg", imageId = assets.WatermelonEggImg, price = 2500000 },
	ZombieEgg = { name = "Zombie Egg", imageId = assets.ZombieEggImg, price = 25000000000 },
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
