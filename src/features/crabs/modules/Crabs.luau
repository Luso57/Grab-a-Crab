--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)

export type CrabDefinition = { name: string, imageId: number, modelName: string, rarity: Rarities.Rarity, incomePerSecond: number, tankIncomeMultiplier: number? }

local definitions: { [string]: CrabDefinition } = {
	AlienCrab = { name = "Alien Crab", imageId = assets.AlienCrabImg, modelName = "AlienCrab", rarity = "Legendary", incomePerSecond = 60000000 },
	AngelCrab = { name = "Angel Crab", imageId = assets.AngelCrabImg, modelName = "AngelCrab", rarity = "Legendary", incomePerSecond = 2400000 },
	ArtistCrab = { name = "Artist Crab", imageId = assets.ArtistCrabImg, modelName = "ArtistCrab", rarity = "Uncommon", incomePerSecond = 160 },
	BasicCrab = { name = "Basic Crab", imageId = assets.BasicCrabImg, modelName = "BasicCrab", rarity = "Common", incomePerSecond = 10 },
	BeachCrab = { name = "Beach Crab", imageId = assets.BeachCrabImg, modelName = "BeachCrab", rarity = "Common", incomePerSecond = 20 },
	BlueCrab = { name = "Blue Crab", imageId = assets.BlueCrabImg, modelName = "BlueCrab", rarity = "Common", incomePerSecond = 40 },
	ChefCrab = { name = "Chef Crab", imageId = assets.ChefCrabImg, modelName = "ChefCrab", rarity = "Uncommon", incomePerSecond = 240 },
	CookieCrab = { name = "Cookie Crab", imageId = assets.CookieCrabImg, modelName = "CookieCrab", rarity = "Uncommon", incomePerSecond = 360 },
	CowboyCrab = { name = "Cowboy Crab", imageId = assets.CowboyCrabImg, modelName = "CowboyCrab", rarity = "Uncommon", incomePerSecond = 600 },
	DeepSeaCrab = { name = "Deep Sea Crab", imageId = assets.DeepSeaCrabImg, modelName = "DeepSeaCrab", rarity = "Epic", incomePerSecond = 60000 },
	DevilCrab = { name = "Devil Crab", imageId = assets.DevilCrabImg, modelName = "DevilCrab", rarity = "Legendary", incomePerSecond = 120000000 },
	FossilizedCrab = { name = "Fossilized Crab", imageId = assets.FossilizedCrabImg, modelName = "FossilizedCrab", rarity = "Rare", incomePerSecond = 2400 },
	FrozenCrab = { name = "Frozen Crab", imageId = assets.FrozenCrabImg, modelName = "FrozenCrab", rarity = "Rare", incomePerSecond = 4800 },
	GhostCrab = { name = "Ghost Crab", imageId = assets.GhostCrabImg, modelName = "GhostCrab", rarity = "Epic", incomePerSecond = 120000 },
	JungleCrab = { name = "Jungle Crab", imageId = assets.JungleCrabImg, modelName = "JungleCrab", rarity = "Uncommon", incomePerSecond = 960 },
	kingCrab = { name = "King Crab", imageId = assets.KingCrabImg, modelName = "kingCrab", rarity = "Mythic", incomePerSecond = 0, tankIncomeMultiplier = 2 },
	MoonCrab = { name = "Moon Crab", imageId = assets.MoonCrabImg, modelName = "MoonCrab", rarity = "Legendary", incomePerSecond = 24000000 },
	MossCrab = { name = "Moss Crab", imageId = assets.MossCrabImg, modelName = "MossCrab", rarity = "Common", incomePerSecond = 64 },
	NinjaCrab = { name = "Ninja Crab", imageId = assets.NinjaCrabImg, modelName = "NinjaCrab", rarity = "Rare", incomePerSecond = 12000 },
	PirateCrab = { name = "Pirate Crab", imageId = assets.PirateCrabImg, modelName = "PirateCrab", rarity = "Rare", incomePerSecond = 0, tankIncomeMultiplier = 1.5 },
	PumpkinCrab = { name = "Pumpkin Crab", imageId = assets.PumpkinCrabImg, modelName = "PumpkinCrab", rarity = "Uncommon", incomePerSecond = 1200 },
	RadioactiveCrab = { name = "Radioactive Crab", imageId = assets.RadioactiveCrabImg, modelName = "RadioactiveCrab", rarity = "Legendary", incomePerSecond = 240000000 },
	SakuraCrab = { name = "Sakura Crab", imageId = assets.SakuraCrabImg, modelName = "SakuraCrab", rarity = "Epic", incomePerSecond = 300000 },
	ScientistCrab = { name = "Scientist Crab", imageId = assets.ScientistCrabImg, modelName = "ScientistCrab", rarity = "Rare", incomePerSecond = 21600 },
	SkeletonCrab = { name = "Skeleton Crab", imageId = assets.SkeletonCrabImg, modelName = "SkeletonCrab", rarity = "Rare", incomePerSecond = 24000 },
	StoneCrab = { name = "Stone Crab", imageId = assets.StoneCrabImg, modelName = "StoneCrab", rarity = "Common", incomePerSecond = 80 },
	VampireCrab = { name = "Vampire Crab", imageId = assets.VampireCrabImg, modelName = "VampireCrab", rarity = "Epic", incomePerSecond = 360000 },
	WatermelonCrab = { name = "Watermelon Crab", imageId = assets.WatermelonCrabImg, modelName = "WatermelonCrab", rarity = "Common", incomePerSecond = 120 },
	ZombieCrab = { name = "Zombie Crab", imageId = assets.ZombieCrabImg, modelName = "ZombieCrab", rarity = "Epic", incomePerSecond = 600000 },
	BubbleCrab = { name = "Bubble Crab", imageId = assets.BubbleCrabImg, modelName = "BubbleCrab", rarity = "Common", incomePerSecond = 50 },
	CoffeeCrab = { name = "Coffee Crab", imageId = assets.CoffeeCrabImg, modelName = "CoffeeCrab", rarity = "Common", incomePerSecond = 52 },
	MushroomCrab = { name = "Mushroom Crab", imageId = assets.MushroomCrabImg, modelName = "MushroomCrab", rarity = "Common", incomePerSecond = 54 },
	PizzaCrab = { name = "Pizza Crab", imageId = assets.PizzaCrabImg, modelName = "PizzaCrab", rarity = "Common", incomePerSecond = 56 },
	StrawberryCrab = { name = "Strawberry Crab", imageId = assets.StrawberryCrabImg, modelName = "StrawberryCrab", rarity = "Common", incomePerSecond = 58 },
	SunflowerCrab = { name = "Sunflower Crab", imageId = assets.SunflowerCrabImg, modelName = "SunflowerCrab", rarity = "Common", incomePerSecond = 60 },
	CactusCrab = { name = "Cactus Crab", imageId = assets.CactusCrabImg, modelName = "CactusCrab", rarity = "Uncommon", incomePerSecond = 480 },
	CupcakeCrab = { name = "Cupcake Crab", imageId = assets.CupcakeCrabImg, modelName = "CupcakeCrab", rarity = "Uncommon", incomePerSecond = 500 },
	HoneycombCrab = { name = "Honeycomb Crab", imageId = assets.HoneycombCrabImg, modelName = "HoneycombCrab", rarity = "Uncommon", incomePerSecond = 520 },
	PineappleCrab = { name = "Pineapple Crab", imageId = assets.PineappleCrabImg, modelName = "PineappleCrab", rarity = "Uncommon", incomePerSecond = 540 },
	PopcornCrab = { name = "Popcorn Crab", imageId = assets.PopcornCrabImg, modelName = "PopcornCrab", rarity = "Uncommon", incomePerSecond = 560 },
	SushiCrab = { name = "Sushi Crab", imageId = assets.SushiCrabImg, modelName = "SushiCrab", rarity = "Uncommon", incomePerSecond = 580 },
	CoralReefCrab = { name = "Coral Reef Crab", imageId = assets.CoralReefCrabImg, modelName = "CoralReefCrab", rarity = "Rare", incomePerSecond = 15000 },
	DetectiveCrab = { name = "Detective Crab", imageId = assets.DetectiveCrabImg, modelName = "DetectiveCrab", rarity = "Rare", incomePerSecond = 15600 },
	FirefighterCrab = { name = "Firefighter Crab", imageId = assets.FirefighterCrabImg, modelName = "FirefighterCrab", rarity = "Rare", incomePerSecond = 16200 },
	RamenCrab = { name = "Ramen Crab", imageId = assets.RamenCrabImg, modelName = "RamenCrab", rarity = "Rare", incomePerSecond = 16800 },
	RobotCrab = { name = "Robot Crab", imageId = assets.RobotCrabImg, modelName = "RobotCrab", rarity = "Rare", incomePerSecond = 17400 },
	VikingCrab = { name = "Viking Crab", imageId = assets.VikingCrabImg, modelName = "VikingCrab", rarity = "Rare", incomePerSecond = 18000 },
	ArcadeCrab = { name = "Arcade Crab", imageId = assets.ArcadeCrabImg, modelName = "ArcadeCrab", rarity = "Epic", incomePerSecond = 240000 },
	ClockworkCrab = { name = "Clockwork Crab", imageId = assets.ClockworkCrabImg, modelName = "ClockworkCrab", rarity = "Epic", incomePerSecond = 250000 },
	CrystalCrab = { name = "Crystal Crab", imageId = assets.CrystalCrabImg, modelName = "CrystalCrab", rarity = "Epic", incomePerSecond = 260000 },
	KnightCrab = { name = "Knight Crab", imageId = assets.KnightCrabImg, modelName = "KnightCrab", rarity = "Epic", incomePerSecond = 270000 },
	MusicCrab = { name = "Music Crab", imageId = assets.MusicCrabImg, modelName = "MusicCrab", rarity = "Epic", incomePerSecond = 280000 },
	PorcelainCrab = { name = "Porcelain Crab", imageId = assets.PorcelainCrabImg, modelName = "PorcelainCrab", rarity = "Epic", incomePerSecond = 290000 },
	CloudCrab = { name = "Cloud Crab", imageId = assets.CloudCrabImg, modelName = "CloudCrab", rarity = "Legendary", incomePerSecond = 62000000 },
	DiscoCrab = { name = "Disco Crab", imageId = assets.DiscoCrabImg, modelName = "DiscoCrab", rarity = "Legendary", incomePerSecond = 64000000 },
	LavaCrab = { name = "Lava Crab", imageId = assets.LavaCrabImg, modelName = "LavaCrab", rarity = "Legendary", incomePerSecond = 66000000 },
	OrigamiCrab = { name = "Origami Crab", imageId = assets.OrigamiCrabImg, modelName = "OrigamiCrab", rarity = "Legendary", incomePerSecond = 68000000 },
	PatchworkCrab = { name = "Patchwork Crab", imageId = assets.PatchworkCrabImg, modelName = "PatchworkCrab", rarity = "Legendary", incomePerSecond = 70000000 },
	RaceCarCrab = { name = "Race Car Crab", imageId = assets.RaceCarCrabImg, modelName = "RaceCarCrab", rarity = "Legendary", incomePerSecond = 72000000 },
	GalaxyCrab = { name = "Galaxy Crab", imageId = assets.GalaxyCrabImg, modelName = "GalaxyCrab", rarity = "Mythic", incomePerSecond = 2400000000 },
	PharaohCrab = { name = "Pharaoh Crab", imageId = assets.PharaohCrabImg, modelName = "PharaohCrab", rarity = "Mythic", incomePerSecond = 2600000000 },
	PrismCrab = { name = "Prism Crab", imageId = assets.PrismCrabImg, modelName = "PrismCrab", rarity = "Mythic", incomePerSecond = 2700000000 },
	StormCrab = { name = "Storm Crab", imageId = assets.StormCrabImg, modelName = "StormCrab", rarity = "Mythic", incomePerSecond = 2800000000 },
	ThunderCrab = { name = "Thunder Crab", imageId = assets.ThunderCrabImg, modelName = "ThunderCrab", rarity = "Mythic", incomePerSecond = 2900000000 },
	TreasureCrab = { name = "Treasure Crab", imageId = assets.TreasureCrabImg, modelName = "TreasureCrab", rarity = "Mythic", incomePerSecond = 3000000000 },
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
	return if definition and not definition.tankIncomeMultiplier then math.floor(definition.incomePerSecond * 0.55 + 0.5) else nil
end

return Crabs
