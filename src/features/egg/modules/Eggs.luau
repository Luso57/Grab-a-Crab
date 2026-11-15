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
	AlienEgg = { name = "Alien Egg", imageId = assets.AlienEggImg, price = 4050000000 },
	AngelEgg = { name = "Angel Egg", imageId = assets.AngelEggImg, price = 162000000 },
	ArtistEgg = { name = "Artist Egg", imageId = assets.ArtisitEggImg, price = 3600 },
	BasicEgg = { name = "Basic Egg", imageId = assets.BasicEggImg, price = 225 },
	BeachEgg = { name = "Beach Egg", imageId = assets.BeachEggImg, price = 450 },
	BlueEgg = { name = "Blue Egg", imageId = assets.BlueEggImg, price = 900 },
	ChefEgg = { name = "Chef Egg", imageId = assets.ChefEggImg, price = 5400 },
	CookieEgg = { name = "Cookie Egg", imageId = assets.CookieEggImg, price = 8100 },
	CowboyEgg = { name = "Cowboy Egg", imageId = assets.CowboyEggImg, price = 13500 },
	DeepSeaEgg = { name = "Deep Sea Egg", imageId = assets.DeepSeaEggImg, price = 4050000 },
	DevilEgg = { name = "Devil Egg", imageId = assets.DevilEggImg, price = 8100000000 },
	FossilizedEgg = { name = "Fossilized Egg", imageId = assets.FossilizedEggImg, price = 162000 },
	FrozenEgg = { name = "Frozen Egg", imageId = assets.FrozenEggImg, price = 324000 },
	GhostEgg = { name = "Ghost Egg", imageId = assets.GhostEggImg, price = 8100000 },
	JungleEgg = { name = "Jungle Egg", imageId = assets.JungleEggImg, price = 21600 },
	KingEgg = { name = "King Egg", imageId = assets.KingCrabEggImg, price = 166500000000 },
	MoonEgg = { name = "Moon Egg", imageId = assets.MoonEggImg, price = 1620000000 },
	MossEgg = { name = "Moss Egg", imageId = assets.MossEggImg, price = 1575 },
	NinjaEgg = { name = "Ninja Egg", imageId = assets.NinjaEggImg, price = 810000 },
	PirateEgg = { name = "Pirate Egg", imageId = assets.PirateEggImg, price = 1215000 },
	PumpkinEgg = { name = "Pumpkin Egg", imageId = assets.PumpkinEggImg, price = 27000 },
	RadioactiveEgg = { name = "Radioactive Egg", imageId = assets.RadioActiveEggImg, price = 16200000000 },
	SakuraEgg = { name = "Sakura Egg", imageId = assets.SakuraEggImg, price = 19440000 },
	ScientistEgg = { name = "Scientist Egg", imageId = assets.ScientistEggImg, price = 1458000 },
	SkeletonEgg = { name = "Skeleton Egg", imageId = assets.SkeletonEggImg, price = 1620000 },
	StoneEgg = { name = "Stone Egg", imageId = assets.StoneEggImg, price = 1800 },
	VampireEgg = { name = "Vampire Egg", imageId = assets.VampireEggImg, price = 24300000 },
	WatermelonEgg = { name = "Watermelon Egg", imageId = assets.WatermelonEggImg, price = 2700 },
	ZombieEgg = { name = "Zombie Egg", imageId = assets.ZombieEggImg, price = 40500000 },
	BubbleEgg = { name = "Bubble Egg", imageId = assets.BubbleEggImg, price = 1125 },
	CoffeeEgg = { name = "Coffee Egg", imageId = assets.CoffeeEggImg, price = 1200 },
	MushroomEgg = { name = "Mushroom Egg", imageId = assets.MushroomEggImg, price = 1275 },
	PizzaEgg = { name = "Pizza Egg", imageId = assets.PizzaEggImg, price = 1350 },
	StrawberryEgg = { name = "Strawberry Egg", imageId = assets.StrawberryEggImg, price = 1425 },
	SunflowerEgg = { name = "Sunflower Egg", imageId = assets.SunflowerEggImg, price = 1500 },
	CactusEgg = { name = "Cactus Egg", imageId = assets.CactusEggImg, price = 10800 },
	CupcakeEgg = { name = "Cupcake Egg", imageId = assets.CupcakeEggImg, price = 11250 },
	HoneycombEgg = { name = "Honeycomb Egg", imageId = assets.HoneycombEggImg, price = 11700 },
	PineappleEgg = { name = "Pineapple Egg", imageId = assets.PineappleEggImg, price = 12150 },
	PopcornEgg = { name = "Popcorn Egg", imageId = assets.PopcornEggImg, price = 12600 },
	SushiEgg = { name = "Sushi Egg", imageId = assets.SushiEggImg, price = 13050 },
	CoralReefEgg = { name = "Coral Reef Egg", imageId = assets.CoralReefEggImg, price = 1012500 },
	DetectiveEgg = { name = "Detective Egg", imageId = assets.DetectiveEggImg, price = 1044000 },
	FirefighterEgg = { name = "Firefighter Egg", imageId = assets.FirefighterEggImg, price = 1075500 },
	RamenEgg = { name = "Ramen Egg", imageId = assets.RamenEggImg, price = 1107000 },
	RobotEgg = { name = "Robot Egg", imageId = assets.RobotEggImg, price = 1138500 },
	VikingEgg = { name = "Viking Egg", imageId = assets.VikingEggImg, price = 1170000 },
	ArcadeEgg = { name = "Arcade Egg", imageId = assets.ArcadeEggImg, price = 16200000 },
	ClockworkEgg = { name = "Clockwork Egg", imageId = assets.ClockworkEggImg, price = 16740000 },
	CrystalEgg = { name = "Crystal Egg", imageId = assets.CrystalEggImg, price = 17280000 },
	KnightEgg = { name = "Knight Egg", imageId = assets.KnightEggImg, price = 17820000 },
	MusicEgg = { name = "Music Egg", imageId = assets.MusicEggImg, price = 18360000 },
	PorcelainEgg = { name = "Porcelain Egg", imageId = assets.PorcelainEggImg, price = 18900000 },
	CloudEgg = { name = "Cloud Egg", imageId = assets.CloudEggImg, price = 4185000000 },
	DiscoEgg = { name = "Disco Egg", imageId = assets.DiscoEggImg, price = 4320000000 },
	LavaEgg = { name = "Lava Egg", imageId = assets.LavaEggImg, price = 4455000000 },
	OrigamiEgg = { name = "Origami Egg", imageId = assets.OrigamiEggImg, price = 4590000000 },
	PatchworkEgg = { name = "Patchwork Egg", imageId = assets.PatchworkEggImg, price = 4725000000 },
	RaceCarEgg = { name = "Race Car Egg", imageId = assets.RaceCarEggImg, price = 4860000000 },
	GalaxyEgg = { name = "Galaxy Egg", imageId = assets.GalaxyEggImg, price = 162000000000 },
	PharaohEgg = { name = "Pharaoh Egg", imageId = assets.PharaohEggImg, price = 171000000000 },
	PrismEgg = { name = "Prism Egg", imageId = assets.PrismEggImg, price = 175500000000 },
	StormEgg = { name = "Storm Egg", imageId = assets.StormEggImg, price = 180000000000 },
	ThunderEgg = { name = "Thunder Egg", imageId = assets.ThunderEggImg, price = 184500000000 },
	TreasureEgg = { name = "Treasure Egg", imageId = assets.TreasureEggImg, price = 189000000000 },
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
		if child.Name == "PirateEgg" or child.Name == "KingEgg" then
			continue
		end
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
	if #templates ~= 63 then
		warn("Expected 63 egg templates, found", #templates)
	end
	table.sort(templates, function(left, right)
		return left.Name < right.Name
	end)
	return templates
end

return Eggs
