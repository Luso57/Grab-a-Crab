--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)

export type CrabDefinition = { name: string, imageId: number, modelName: string, rarity: Rarities.Rarity, incomePerSecond: number }

local definitions: { [string]: CrabDefinition } = {
	AlienCrab = { name = "Alien Crab", imageId = assets.AlienCrabImg, modelName = "AlienCrab", rarity = "Legendary", incomePerSecond = 25000000000 },
	AngelCrab = { name = "Angel Crab", imageId = assets.AngelCrabImg, modelName = "AngelCrab", rarity = "Legendary", incomePerSecond = 1000000000 },
	ArtistCrab = { name = "Artist Crab", imageId = assets.ArtistCrabImg, modelName = "ArtistCrab", rarity = "Uncommon", incomePerSecond = 50000 },
	BasicCrab = { name = "Basic Crab", imageId = assets.BasicCrabImg, modelName = "BasicCrab", rarity = "Common", incomePerSecond = 1000 },
	BeachCrab = { name = "Beach Crab", imageId = assets.BeachCrabImg, modelName = "BeachCrab", rarity = "Common", incomePerSecond = 2500 },
	BlueCrab = { name = "Blue Crab", imageId = assets.BlueCrabImg, modelName = "BlueCrab", rarity = "Common", incomePerSecond = 5000 },
	ChefCrab = { name = "Chef Crab", imageId = assets.ChefCrabImg, modelName = "ChefCrab", rarity = "Uncommon", incomePerSecond = 100000 },
	CookieCrab = { name = "Cookie Crab", imageId = assets.CookieCrabImg, modelName = "CookieCrab", rarity = "Uncommon", incomePerSecond = 150000 },
	CowboyCrab = { name = "Cowboy Crab", imageId = assets.CowboyCrabImg, modelName = "CowboyCrab", rarity = "Uncommon", incomePerSecond = 250000 },
	DeepSeaCrab = { name = "Deep Sea Crab", imageId = assets.DeepSeaCrabImg, modelName = "DeepSeaCrab", rarity = "Epic", incomePerSecond = 25000000 },
	DevilCrab = { name = "Devil Crab", imageId = assets.DevilCrabImg, modelName = "DevilCrab", rarity = "Legendary", incomePerSecond = 50000000000 },
	FossilizedCrab = { name = "Fossilized Crab", imageId = assets.FossilizedCrabImg, modelName = "FossilizedCrab", rarity = "Rare", incomePerSecond = 1000000 },
	FrozenCrab = { name = "Frozen Crab", imageId = assets.FrozenCrabImg, modelName = "FrozenCrab", rarity = "Rare", incomePerSecond = 2000000 },
	GhostCrab = { name = "Ghost Crab", imageId = assets.GhostCrabImg, modelName = "GhostCrab", rarity = "Epic", incomePerSecond = 50000000 },
	JungleCrab = { name = "Jungle Crab", imageId = assets.JungleCrabImg, modelName = "JungleCrab", rarity = "Uncommon", incomePerSecond = 400000 },
	kingCrab = { name = "King Crab", imageId = assets.KingCrabImg, modelName = "kingCrab", rarity = "Mythic", incomePerSecond = 1000000000000000 },
	MoonCrab = { name = "Moon Crab", imageId = assets.MoonCrabImg, modelName = "MoonCrab", rarity = "Legendary", incomePerSecond = 10000000000 },
	MossCrab = { name = "Moss Crab", imageId = assets.MossCrabImg, modelName = "MossCrab", rarity = "Common", incomePerSecond = 10000 },
	NinjaCrab = { name = "Ninja Crab", imageId = assets.NinjaCrabImg, modelName = "NinjaCrab", rarity = "Rare", incomePerSecond = 5000000 },
	PirateCrab = { name = "Pirate Crab", imageId = assets.PirateCrabImg, modelName = "PirateCrab", rarity = "Rare", incomePerSecond = 7500000 },
	PumpkinCrab = { name = "Pumpkin Crab", imageId = assets.PumpkinCrabImg, modelName = "PumpkinCrab", rarity = "Uncommon", incomePerSecond = 500000 },
	RadioactiveCrab = { name = "Radioactive Crab", imageId = assets.RadioactiveCrabImg, modelName = "RadioactiveCrab", rarity = "Legendary", incomePerSecond = 100000000000 },
	SakuraCrab = { name = "Sakura Crab", imageId = assets.SakuraCrabImg, modelName = "SakuraCrab", rarity = "Epic", incomePerSecond = 100000000 },
	ScientistCrab = { name = "Scientist Crab", imageId = assets.ScientistCrabImg, modelName = "ScientistCrab", rarity = "Rare", incomePerSecond = 9000000 },
	SkeletonCrab = { name = "Skeleton Crab", imageId = assets.SkeletonCrabImg, modelName = "SkeletonCrab", rarity = "Rare", incomePerSecond = 10000000 },
	StoneCrab = { name = "Stone Crab", imageId = assets.StoneCrabImg, modelName = "StoneCrab", rarity = "Common", incomePerSecond = 15000 },
	VampireCrab = { name = "Vampire Crab", imageId = assets.VampireCrabImg, modelName = "VampireCrab", rarity = "Epic", incomePerSecond = 150000000 },
	WatermelonCrab = { name = "Watermelon Crab", imageId = assets.WatermelonCrabImg, modelName = "WatermelonCrab", rarity = "Common", incomePerSecond = 25000 },
	ZombieCrab = { name = "Zombie Crab", imageId = assets.ZombieCrabImg, modelName = "ZombieCrab", rarity = "Epic", incomePerSecond = 250000000 },
}

local Crabs = {}
function Crabs.get(crabId: string): CrabDefinition?
	return definitions[crabId]
end

return Crabs
