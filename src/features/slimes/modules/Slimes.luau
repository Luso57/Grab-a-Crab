local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)

export type SlimeRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Exotic" | "Secret"

export type SlimeDefinition = {
	name: string,
	rarity: SlimeRarity,
	image: string,
	cost: number,
	income: number,
	chance: number,
}

export type SlimeInfo = SlimeDefinition & {
	id: string,
}

local slimeDefinitions: { [string]: SlimeDefinition } = {
	green = {
		name = "Green Slime",
		rarity = "Common",
		image = "rbxassetid://133166580358352",
		cost = 0,
		income = 5,
		chance = 1.6059219164651048,
	},

	blue = {
		name = "Blue Slime",
		rarity = "Common",
		image = "rbxassetid://100827892652136",
		cost = 0,
		income = 6,
		chance = 8,
	},

	pink = {
		name = "Pink Slime",
		rarity = "Common",
		image = "rbxassetid://75259454937731",
		cost = 160,
		income = 8,
		chance = 12,
	},

	BearSlime = {
		name = "Bear Slime",
		rarity = "Common",
		image = "rbxassetid://108639255262823",
		cost = 200,
		income = 10,
		chance = 18,
	},

	BlueberrySlime = {
		name = "Blueberry Slime",
		rarity = "Common",
		image = "rbxassetid://73248167803995",
		cost = 240,
		income = 12,
		chance = 28,
	},

	BubbleSlime = {
		name = "Bubble Slime",
		rarity = "Common",
		image = "rbxassetid://114507399498520",
		cost = 300,
		income = 15,
		chance = 42,
	},

	BurgerSlime = {
		name = "Burger Slime",
		rarity = "Common",
		image = "rbxassetid://122688548654445",
		cost = 380,
		income = 19,
		chance = 60,
	},

	CakeSlime = {
		name = "Cake Slime",
		rarity = "Common",
		image = "rbxassetid://96453879522217",
		cost = 480,
		income = 24,
		chance = 85,
	},

	CherrySlime = {
		name = "Cherry Slime",
		rarity = "Common",
		image = "rbxassetid://133978275072546",
		cost = 600,
		income = 30,
		chance = 120,
	},

	CookieSlime = {
		name = "Cookie Slime",
		rarity = "Common",
		image = "rbxassetid://95386245753601",
		cost = 740,
		income = 37,
		chance = 180,
	},

	CowSlime = {
		name = "Cow Slime",
		rarity = "Common",
		image = "rbxassetid://83110343927709",
		cost = 940,
		income = 47,
		chance = 280,
	},

	CuriousSlime = {
		name = "Curious Slime",
		rarity = "Common",
		image = "rbxassetid://83375759686941",
		cost = 1_160,
		income = 58,
		chance = 420,
	},

	DuckSlime = {
		name = "Duck Slime",
		rarity = "Common",
		image = "rbxassetid://100744593141879",
		cost = 1_460,
		income = 73,
		chance = 600,
	},

	DumbSlime = {
		name = "Dumb Slime",
		rarity = "Common",
		image = "rbxassetid://110337809340947",
		cost = 1_820,
		income = 91,
		chance = 850,
	},

	FrogSlime = {
		name = "Frog Slime",
		rarity = "Common",
		image = "rbxassetid://116558728578057",
		cost = 2_280,
		income = 114,
		chance = 1_200,
	},

	HappyEyeSlime = {
		name = "Happy Eye Slime",
		rarity = "Common",
		image = "rbxassetid://115358501549358",
		cost = 2_840,
		income = 142,
		chance = 1_700,
	},

	KittenSlime = {
		name = "Kitten Slime",
		rarity = "Common",
		image = "rbxassetid://99771142201135",
		cost = 3_560,
		income = 178,
		chance = 2_400,
	},

	LemonSlime = {
		name = "Lemon Slime",
		rarity = "Common",
		image = "rbxassetid://130407673329340",
		cost = 4_440,
		income = 222,
		chance = 3_500,
	},

	OrangeSlime = {
		name = "Orange Slime",
		rarity = "Common",
		image = "rbxassetid://123691542156218",
		cost = 5_560,
		income = 278,
		chance = 5_000,
	},

	PoopSlime = {
		name = "Poop Slime",
		rarity = "Common",
		image = "rbxassetid://102137655950214",
		cost = 6_940,
		income = 347,
		chance = 7_000,
	},

	PumpkinSlime = {
		name = "Pumpkin Slime",
		rarity = "Common",
		image = "rbxassetid://140076234272523",
		cost = 8_680,
		income = 434,
		chance = 10_000,
	},

	RibbonSlime = {
		name = "Ribbon Slime",
		rarity = "Common",
		image = "rbxassetid://95506632925887",
		cost = 10_840,
		income = 542,
		chance = 15_000,
	},

	SleepySlime = {
		name = "Sleepy Slime",
		rarity = "Common",
		image = "rbxassetid://129974619198204",
		cost = 13_560,
		income = 678,
		chance = 22_000,
	},

	SproutSlime = {
		name = "Sprout Slime",
		rarity = "Common",
		image = "rbxassetid://90856175598591",
		cost = 16_940,
		income = 847,
		chance = 32_000,
	},

	SurprisedSlime = {
		name = "Surprised Slime",
		rarity = "Common",
		image = "rbxassetid://112984338341598",
		cost = 21_180,
		income = 1_059,
		chance = 48_000,
	},

	WinkyEyeSlime = {
		name = "Winky Eye Slime",
		rarity = "Common",
		image = "rbxassetid://109292762834092",
		cost = 26_460,
		income = 1_323,
		chance = 70_000,
	},

	BowTieSlime = {
		name = "Bow Tie Slime",
		rarity = "Uncommon",
		image = "rbxassetid://107824000400329",
		cost = 33_080,
		income = 1_654,
		chance = 100_000,
	},

	ConstructionSlime = {
		name = "Construction Slime",
		rarity = "Uncommon",
		image = "rbxassetid://72915873675775",
		cost = 41_360,
		income = 2_068,
		chance = 150_000,
	},

	CowboySlime = {
		name = "Cowboy Slime",
		rarity = "Uncommon",
		image = "rbxassetid://107923540324363",
		cost = 51_700,
		income = 2_585,
		chance = 220_000,
	},

	CrocodileSlime = {
		name = "Crocodile Slime",
		rarity = "Uncommon",
		image = "rbxassetid://130255902906674",
		cost = 64_620,
		income = 3_231,
		chance = 320_000,
	},

	DoctorSlime = {
		name = "Doctor Slime",
		rarity = "Uncommon",
		image = "rbxassetid://102220430167674",
		cost = 80_780,
		income = 4_039,
		chance = 480_000,
	},

	GardenerSlime = {
		name = "Gardener Slime",
		rarity = "Uncommon",
		image = "rbxassetid://132459398413072",
		cost = 100_980,
		income = 5_049,
		chance = 700_000,
	},

	GeniusSlime = {
		name = "Genius Slime",
		rarity = "Uncommon",
		image = "rbxassetid://101351398984532",
		cost = 126_220,
		income = 6_311,
		chance = 1e6,
	},

	HoneySlime = {
		name = "Honey Slime",
		rarity = "Uncommon",
		image = "rbxassetid://96065182896147",
		cost = 157_780,
		income = 7_889,
		chance = 1.5e6,
	},

	InventorSlime = {
		name = "Inventor Slime",
		rarity = "Uncommon",
		image = "rbxassetid://77722698112626",
		cost = 197_220,
		income = 9_861,
		chance = 2.2e6,
	},

	JungleSlime = {
		name = "Jungle Slime",
		rarity = "Uncommon",
		image = "rbxassetid://83886894599894",
		cost = 246_520,
		income = 12_326,
		chance = 3.2e6,
	},

	LifeguardSlime = {
		name = "Lifeguard Slime",
		rarity = "Uncommon",
		image = "rbxassetid://76177718237249",
		cost = 308_140,
		income = 15_407,
		chance = 4.8e6,
	},

	LoveSlime = {
		name = "Love Slime",
		rarity = "Uncommon",
		image = "rbxassetid://101028427419705",
		cost = 385_180,
		income = 19_259,
		chance = 7e6,
	},

	MonocleSlime = {
		name = "Monocle Slime",
		rarity = "Uncommon",
		image = "rbxassetid://117001086126432",
		cost = 481_480,
		income = 24_074,
		chance = 1e7,
	},

	MummySlime = {
		name = "Mummy Slime",
		rarity = "Uncommon",
		image = "rbxassetid://117719262442361",
		cost = 601_860,
		income = 30_093,
		chance = 1.5e7,
	},

	NerdSlime = {
		name = "Nerd Slime",
		rarity = "Uncommon",
		image = "rbxassetid://70420775413720",
		cost = 752_320,
		income = 37_616,
		chance = 2.2e7,
	},

	ProfessorSlime = {
		name = "Professor Slime",
		rarity = "Uncommon",
		image = "rbxassetid://76589887202025",
		cost = 940_400,
		income = 47_020,
		chance = 3.2e7,
	},

	RaccoonSlime = {
		name = "Raccoon Slime",
		rarity = "Uncommon",
		image = "rbxassetid://98799121913184",
		cost = 1.1755e6,
		income = 58_775,
		chance = 4.8e7,
	},

	ShySlime = {
		name = "Shy Slime",
		rarity = "Uncommon",
		image = "rbxassetid://83324105737697",
		cost = 1.46936e6,
		income = 73_468,
		chance = 7e7,
	},

	SparkleEyeSlime = {
		name = "Sparkle Eye Slime",
		rarity = "Uncommon",
		image = "rbxassetid://117247125565003",
		cost = 1.8367e6,
		income = 91_835,
		chance = 1e8,
	},

	AlienSlime = {
		name = "Alien Slime",
		rarity = "Rare",
		image = "rbxassetid://76620732951339",
		cost = 2.29588e6,
		income = 114_794,
		chance = 1.5e8,
	},

	BeachSlime = {
		name = "Beach Slime",
		rarity = "Rare",
		image = "rbxassetid://75122773539497",
		cost = 2.86986e6,
		income = 143_493,
		chance = 2.2e8,
	},

	BunnySlime = {
		name = "Bunny Slime",
		rarity = "Rare",
		image = "rbxassetid://137083260283725",
		cost = 3.58732e6,
		income = 179_366,
		chance = 3.2e8,
	},

	CloudPuffSlime = {
		name = "Cloud Puff Slime",
		rarity = "Rare",
		image = "rbxassetid://140067002817112",
		cost = 4.48416e6,
		income = 224_208,
		chance = 4.8e8,
	},

	DinoSlime = {
		name = "Dino Slime",
		rarity = "Rare",
		image = "rbxassetid://83101614763197",
		cost = 5.6052e6,
		income = 280_260,
		chance = 7e8,
	},

	FishSlime = {
		name = "Fish Slime",
		rarity = "Rare",
		image = "rbxassetid://72766055811759",
		cost = 7.0065e6,
		income = 350_325,
		chance = 1e9,
	},

	NinjaSlime = {
		name = "Ninja Slime",
		rarity = "Rare",
		image = "rbxassetid://90477627016089",
		cost = 8.75812e6,
		income = 437_906,
		chance = 1.5e9,
	},

	PancakeSlime = {
		name = "Pancake Slime",
		rarity = "Rare",
		image = "rbxassetid://108839583098309",
		cost = 1.094764e7,
		income = 547_382,
		chance = 2.2e9,
	},

	PirateSlime = {
		name = "Pirate Slime",
		rarity = "Rare",
		image = "rbxassetid://82006901866010",
		cost = 1.368456e7,
		income = 684_228,
		chance = 3.2e9,
	},

	SnowmanSlime = {
		name = "Snowman Slime",
		rarity = "Rare",
		image = "rbxassetid://71302491981968",
		cost = 1.71057e7,
		income = 855_285,
		chance = 4.8e9,
	},

	StrawberrySlime = {
		name = "Strawberry Slime",
		rarity = "Rare",
		image = "rbxassetid://130181065244224",
		cost = 2.138212e7,
		income = 1.069106e6,
		chance = 7e9,
	},

	SushiSlime = {
		name = "Sushi Slime",
		rarity = "Rare",
		image = "rbxassetid://82301461190594",
		cost = 2.672764e7,
		income = 1.336382e6,
		chance = 1e10,
	},

	ToadstoolSlime = {
		name = "Toadstool Slime",
		rarity = "Rare",
		image = "rbxassetid://86237180905899",
		cost = 3.340956e7,
		income = 1.670478e6,
		chance = 1.5e10,
	},

	WatermelonSlime = {
		name = "Watermelon Slime",
		rarity = "Rare",
		image = "rbxassetid://87138664581735",
		cost = 4.176194e7,
		income = 2.088097e6,
		chance = 2.2e10,
	},

	gold = {
		name = "Gold Slime",
		rarity = "Epic",
		image = "rbxassetid://99099579946538",
		cost = 5.220244e7,
		income = 2.610122e6,
		chance = 3.2e10,
	},

	purple = {
		name = "Purple Slime",
		rarity = "Epic",
		image = "rbxassetid://117087659767812",
		cost = 6.525304e7,
		income = 3.262652e6,
		chance = 4.8e10,
	},

	CoolSlime = {
		name = "Cool Slime",
		rarity = "Epic",
		image = "rbxassetid://77247600450862",
		cost = 8.15663e7,
		income = 4.078315e6,
		chance = 7e10,
	},

	CrystalSlime = {
		name = "Crystal Slime",
		rarity = "Epic",
		image = "rbxassetid://70975726869611",
		cost = 1.0195788e8,
		income = 5.097894e6,
		chance = 1e11,
	},

	GhostSlime = {
		name = "Ghost Slime",
		rarity = "Epic",
		image = "rbxassetid://139312242998103",
		cost = 1.2744736e8,
		income = 6.372368e6,
		chance = 1.5e11,
	},

	MoonNapSlime = {
		name = "Moon Nap Slime",
		rarity = "Epic",
		image = "rbxassetid://100055562786234",
		cost = 1.593092e8,
		income = 7.96546e6,
		chance = 2.2e11,
	},

	NismoSlime = {
		name = "Nismo Slime",
		rarity = "Epic",
		image = "rbxassetid://95383272881187",
		cost = 1.9913648e8,
		income = 9.956824e6,
		chance = 3.2e11,
	},

	SakuraSlime = {
		name = "Sakura Slime",
		rarity = "Epic",
		image = "rbxassetid://135136581733790",
		cost = 2.4892062e8,
		income = 1.2446031e7,
		chance = 4.8e11,
	},

	TeaPartySlime = {
		name = "Tea Party Slime",
		rarity = "Epic",
		image = "rbxassetid://134694924308460",
		cost = 3.1115076e8,
		income = 1.5557538e7,
		chance = 7e11,
	},

	VunnySlime = {
		name = "Vunny Slime",
		rarity = "Epic",
		image = "rbxassetid://91810528385492",
		cost = 3.8893846e8,
		income = 1.9446923e7,
		chance = 1e12,
	},

	AngelSlime = {
		name = "Angel Slime",
		rarity = "Legendary",
		image = "rbxassetid://102585313777954",
		cost = 4.8617306e8,
		income = 2.4308653e7,
		chance = 1e13,
	},

	DemonSlime = {
		name = "Demon Slime",
		rarity = "Legendary",
		image = "rbxassetid://118744151466836",
		cost = 6.0771634e8,
		income = 3.0385817e7,
		chance = 1e14,
	},

	FrogPrinceSlime = {
		name = "Frog Prince Slime",
		rarity = "Legendary",
		image = "rbxassetid://86084203444606",
		cost = 7.5964542e8,
		income = 3.7982271e7,
		chance = 1e15,
	},

	GalaxySlime = {
		name = "Galaxy Slime",
		rarity = "Legendary",
		image = "rbxassetid://105484082065206",
		cost = 9.4955678e8,
		income = 4.7477839e7,
		chance = 1e16,
	},

	RainbowSlime = {
		name = "Rainbow Slime",
		rarity = "Legendary",
		image = "rbxassetid://107338788324664",
		cost = 1.18694596e9,
		income = 5.9347298e7,
		chance = 1e17,
	},

	WizardSlime = {
		name = "Wizard Slime",
		rarity = "Legendary",
		image = "rbxassetid://80221548870741",
		cost = 1.48368246e9,
		income = 7.4184123e7,
		chance = 1e18,
	},

	AncientRunicSlime = {
		name = "Ancient Runic Slime",
		rarity = "Exotic",
		image = "rbxassetid://98831230287670",
		cost = 1.85460308e9,
		income = 9.2730154e7,
		chance = 1e21,
	},

	AstronautSlime = {
		name = "Astronaut Slime",
		rarity = "Exotic",
		image = "rbxassetid://131077182154061",
		cost = 2.31825384e9,
		income = 1.15912692e8,
		chance = 1e24,
	},

	TitanMechSlime = {
		name = "Titan Mech Slime",
		rarity = "Exotic",
		image = "rbxassetid://130776259450310",
		cost = 2.8978173e9,
		income = 1.44890865e8,
		chance = 1e27,
	},

	VoidEmperorSlime = {
		name = "Void Emperor Slime",
		rarity = "Exotic",
		image = "rbxassetid://80135732951725",
		cost = 3.62227164e9,
		income = 1.81113582e8,
		chance = 1e30,
	},

	Crystal = {
		name = "Crystal Slime",
		rarity = "Secret",
		image = "rbxassetid://77779673121493",
		cost = 4.52783954e9,
		income = 2.26391977e8,
		chance = 1e32,
	},

	rob = {
		name = "Rob Slime",
		rarity = "Secret",
		image = "rbxassetid://94530941461989",
		cost = 5.65979942e9,
		income = 2.82989971e8,
		chance = 9.5e35,
	},

}

local rarityColors: { [SlimeRarity]: Color3 } = {
	Common = Color3.fromRGB(255, 255, 255),
	Uncommon = Color3.fromRGB(65, 255, 55),
	Rare = Color3.fromRGB(0, 170, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 45),
	Exotic = Color3.fromRGB(255, 85, 0),
	Secret = Color3.fromRGB(255, 50, 150),
}

local slimes: { [string]: SlimeInfo } = {}
local slimeIds: { string } = {}
local freeSlimeIds: { string } = {}

for slimeId, slimeDefinition in slimeDefinitions do
	assert(slimeDefinition.chance > 0, `Slime chance must be greater than zero: {slimeId}`)
	assert(slimeDefinition.cost >= 0, `Slime cost cannot be negative: {slimeId}`)
	slimes[slimeId] = {
		id = slimeId,
		name = slimeDefinition.name,
		rarity = slimeDefinition.rarity,
		image = slimeDefinition.image,
		cost = slimeDefinition.cost,
		income = slimeDefinition.income,
		chance = slimeDefinition.chance,
	}
	table.insert(slimeIds, slimeId)
	if slimeDefinition.cost == 0 then
		table.insert(freeSlimeIds, slimeId)
	end
end

table.sort(slimeIds)
table.sort(freeSlimeIds)

local Slimes = {
	slimes = slimes,
	slimeIds = slimeIds,
}

local function getWeightedRandomSlimeId(luckMultiplier: number, random: Random?): string
	local weightExponent = 1 / math.max(1, luckMultiplier)
	local totalWeight = 0
	for _, slimeId in slimeIds do
		totalWeight += (1 / slimes[slimeId].chance) ^ weightExponent
	end

	local roll = (if random then random:NextNumber() else math.random()) * totalWeight
	local cumulativeWeight = 0
	for _, slimeId in slimeIds do
		cumulativeWeight += (1 / slimes[slimeId].chance) ^ weightExponent
		if roll <= cumulativeWeight then
			return slimeId
		end
	end
	return slimeIds[#slimeIds]
end

function Slimes.isValidSlimeId(slimeId: string): boolean
	return slimes[slimeId] ~= nil
end

function Slimes.getSlimeInfo(slimeId: string): SlimeInfo
	local slimeInfo = slimes[slimeId]
	assert(slimeInfo, `Invalid slime ID: {slimeId}`)
	return slimeInfo
end

function Slimes.getSlimeOneInOdds(slimeId: string): number
	return math.max(1, math.round(Slimes.getSlimeInfo(slimeId).chance))
end

function Slimes.getFormattedSlimeOdds(slimeId: string): string
	return CompactNumber.format(Slimes.getSlimeOneInOdds(slimeId), 1, true)
end

function Slimes.getRarityColor(rarity: SlimeRarity): Color3
	local color = rarityColors[rarity]
	assert(color, `Invalid slime rarity: {rarity}`)
	return color
end

function Slimes.getRandomSlimeId(random: Random?): string
	assert(#slimeIds > 0, "Cannot roll a slime because the slime catalog is empty")
	return getWeightedRandomSlimeId(1, random)
end

function Slimes.getLuckyRandomSlimeId(luckMultiplier: number, random: Random?): string
	assert(#slimeIds > 0, "Cannot roll a slime because the slime catalog is empty")
	return getWeightedRandomSlimeId(luckMultiplier, random)
end

function Slimes.getRandomFreeSlimeId(random: Random?): string
	assert(#freeSlimeIds > 0, "Cannot perform a zero-cash safety roll because the slime catalog has no free slimes")
	local index = if random then random:NextInteger(1, #freeSlimeIds) else math.random(1, #freeSlimeIds)
	return freeSlimeIds[index]
end

function Slimes.getSlimeModel(slimeId: string): Model
	Slimes.getSlimeInfo(slimeId)
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local slimeAssets = assets:WaitForChild("Slimes")
	local slimeAsset = slimeAssets:FindFirstChild(slimeId)
	assert(slimeAsset and slimeAsset:IsA("Model"), `Missing or invalid slime model: {slimeId}`)
	return slimeAsset:Clone()
end

return Slimes
