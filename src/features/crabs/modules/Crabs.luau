--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)

export type CrabDefinition = { name: string, imageId: number, modelName: string, rarity: Rarities.Rarity, incomePerSecond: number }

local definitions: { [string]: CrabDefinition } = {
	AlienCrab = { name = "Alien Crab", imageId = assets.AlienCrabImg, modelName = "AlienCrab", rarity = "Legendary", incomePerSecond = 30000000 },
	AngelCrab = { name = "Angel Crab", imageId = assets.AngelCrabImg, modelName = "AngelCrab", rarity = "Legendary", incomePerSecond = 1200000 },
	ArtistCrab = { name = "Artist Crab", imageId = assets.ArtistCrabImg, modelName = "ArtistCrab", rarity = "Uncommon", incomePerSecond = 80 },
	BasicCrab = { name = "Basic Crab", imageId = assets.BasicCrabImg, modelName = "BasicCrab", rarity = "Common", incomePerSecond = 5 },
	BeachCrab = { name = "Beach Crab", imageId = assets.BeachCrabImg, modelName = "BeachCrab", rarity = "Common", incomePerSecond = 10 },
	BlueCrab = { name = "Blue Crab", imageId = assets.BlueCrabImg, modelName = "BlueCrab", rarity = "Common", incomePerSecond = 20 },
	ChefCrab = { name = "Chef Crab", imageId = assets.ChefCrabImg, modelName = "ChefCrab", rarity = "Uncommon", incomePerSecond = 120 },
	CookieCrab = { name = "Cookie Crab", imageId = assets.CookieCrabImg, modelName = "CookieCrab", rarity = "Uncommon", incomePerSecond = 180 },
	CowboyCrab = { name = "Cowboy Crab", imageId = assets.CowboyCrabImg, modelName = "CowboyCrab", rarity = "Uncommon", incomePerSecond = 300 },
	DeepSeaCrab = { name = "Deep Sea Crab", imageId = assets.DeepSeaCrabImg, modelName = "DeepSeaCrab", rarity = "Epic", incomePerSecond = 30000 },
	DevilCrab = { name = "Devil Crab", imageId = assets.DevilCrabImg, modelName = "DevilCrab", rarity = "Legendary", incomePerSecond = 60000000 },
	FossilizedCrab = { name = "Fossilized Crab", imageId = assets.FossilizedCrabImg, modelName = "FossilizedCrab", rarity = "Rare", incomePerSecond = 1200 },
	FrozenCrab = { name = "Frozen Crab", imageId = assets.FrozenCrabImg, modelName = "FrozenCrab", rarity = "Rare", incomePerSecond = 2400 },
	GhostCrab = { name = "Ghost Crab", imageId = assets.GhostCrabImg, modelName = "GhostCrab", rarity = "Epic", incomePerSecond = 60000 },
	JungleCrab = { name = "Jungle Crab", imageId = assets.JungleCrabImg, modelName = "JungleCrab", rarity = "Uncommon", incomePerSecond = 480 },
	kingCrab = { name = "King Crab", imageId = assets.KingCrabImg, modelName = "kingCrab", rarity = "Mythic", incomePerSecond = 1200000000 },
	MoonCrab = { name = "Moon Crab", imageId = assets.MoonCrabImg, modelName = "MoonCrab", rarity = "Legendary", incomePerSecond = 12000000 },
	MossCrab = { name = "Moss Crab", imageId = assets.MossCrabImg, modelName = "MossCrab", rarity = "Common", incomePerSecond = 30 },
	NinjaCrab = { name = "Ninja Crab", imageId = assets.NinjaCrabImg, modelName = "NinjaCrab", rarity = "Rare", incomePerSecond = 6000 },
	PirateCrab = { name = "Pirate Crab", imageId = assets.PirateCrabImg, modelName = "PirateCrab", rarity = "Rare", incomePerSecond = 9000 },
	PumpkinCrab = { name = "Pumpkin Crab", imageId = assets.PumpkinCrabImg, modelName = "PumpkinCrab", rarity = "Uncommon", incomePerSecond = 600 },
	RadioactiveCrab = { name = "Radioactive Crab", imageId = assets.RadioactiveCrabImg, modelName = "RadioactiveCrab", rarity = "Legendary", incomePerSecond = 120000000 },
	SakuraCrab = { name = "Sakura Crab", imageId = assets.SakuraCrabImg, modelName = "SakuraCrab", rarity = "Epic", incomePerSecond = 120000 },
	ScientistCrab = { name = "Scientist Crab", imageId = assets.ScientistCrabImg, modelName = "ScientistCrab", rarity = "Rare", incomePerSecond = 10800 },
	SkeletonCrab = { name = "Skeleton Crab", imageId = assets.SkeletonCrabImg, modelName = "SkeletonCrab", rarity = "Rare", incomePerSecond = 12000 },
	StoneCrab = { name = "Stone Crab", imageId = assets.StoneCrabImg, modelName = "StoneCrab", rarity = "Common", incomePerSecond = 40 },
	VampireCrab = { name = "Vampire Crab", imageId = assets.VampireCrabImg, modelName = "VampireCrab", rarity = "Epic", incomePerSecond = 180000 },
	WatermelonCrab = { name = "Watermelon Crab", imageId = assets.WatermelonCrabImg, modelName = "WatermelonCrab", rarity = "Common", incomePerSecond = 60 },
	ZombieCrab = { name = "Zombie Crab", imageId = assets.ZombieCrabImg, modelName = "ZombieCrab", rarity = "Epic", incomePerSecond = 300000 },
}

local Crabs = {}
function Crabs.get(crabId: string): CrabDefinition?
	return definitions[crabId]
end

function Crabs.getOrderedIds(): { string }
	local ids = {}
	for crabId in definitions do
		table.insert(ids, crabId)
	end
	table.sort(ids, function(a, b)
		local aDefinition = definitions[a]
		local bDefinition = definitions[b]
		if aDefinition.incomePerSecond == bDefinition.incomePerSecond then
			return aDefinition.name < bDefinition.name
		end
		return aDefinition.incomePerSecond < bDefinition.incomePerSecond
	end)
	return ids
end

function Crabs.sellValue(crabId: string): number?
	local definition = definitions[crabId]
	return if definition then math.floor(definition.incomePerSecond * 0.55 + 0.5) else nil
end

return Crabs
