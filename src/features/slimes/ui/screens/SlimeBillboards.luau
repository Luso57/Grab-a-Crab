local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local SlimeEconomy = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeEconomy)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)
local SlimeSlice = require(ReplicatedStorage.Source.Features.Slimes.SlimeSlice)

local e = React.createElement
local PLAYPEN_BILLBOARD_SCALE = 0.625

local function createStatLabel(text: string, color: Color3, layoutOrder: number, scale: number?)
	local visualScale = scale or 1

	return e("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 30 * visualScale),
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
	})
end

local function createStatsFrame(height: number, children: { [string]: any }, scale: number?)
	local visualScale = scale or 1

	children.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 2 * visualScale),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.5, -12 * visualScale),
		Size = UDim2.fromOffset(190 * visualScale, height * visualScale),
	}, children)
end

local function createPurchaseStats(slimeInfo: Slimes.SlimeInfo, formattedOdds: string, mutationId: string)
	local rarityColor = Slimes.getRarityColor(slimeInfo.rarity)
	local mutation = SlimeMutations.get(mutationId)
	local isMutated = mutation.id ~= "normal"

	return createStatsFrame(if isMutated then 162 else 132, {
		Name = createStatLabel(slimeInfo.name, Color3.new(1, 1, 1), 1),
		Mutation = if isMutated then createStatLabel(string.upper(mutation.name), mutation.color, 2) else nil,
		Odds = createStatLabel(`1 in {formattedOdds}`, rarityColor, 3),
		Income = createStatLabel(
			`{CompactNumber.format(slimeInfo.income * mutation.incomeMultiplier, 1)} Slime/s`,
			Color3.fromRGB(255, 221, 33),
			4
		),
		Cost = createStatLabel(
			if slimeInfo.cost == 0 then "FREE" else `${CompactNumber.format(slimeInfo.cost, 1)}`,
			Color3.fromRGB(65, 255, 55),
			5
		),
	})
end

local function createPlaypenStats(
	slimeInfo: Slimes.SlimeInfo,
	formattedOdds: string,
	storedSlime: number,
	level: number,
	mutationId: string
)
	local mutation = SlimeMutations.get(mutationId)
	local isMutated = mutation.id ~= "normal"
	local production = SlimeEconomy.getProduction(slimeInfo.income, level) * mutation.incomeMultiplier
	return createStatsFrame(if isMutated then 122 else 100, {
		Name = createStatLabel(slimeInfo.name, Color3.new(1, 1, 1), 1, PLAYPEN_BILLBOARD_SCALE),
		Mutation = if isMutated
			then createStatLabel(
				`{string.upper(mutation.name)} • {mutation.incomeMultiplier}x`,
				mutation.color,
				2,
				PLAYPEN_BILLBOARD_SCALE
			)
			else nil,
		Rarity = createStatLabel(
			`{slimeInfo.rarity} • 1 in {formattedOdds}`,
			Slimes.getRarityColor(slimeInfo.rarity),
			3,
			PLAYPEN_BILLBOARD_SCALE
		),
		Production = createStatLabel(
			`+{CompactNumber.format(production, 1)} Slime/s • {CompactNumber.format(storedSlime, 1)} Slime`,
			Color3.fromRGB(255, 221, 33),
			4,
			PLAYPEN_BILLBOARD_SCALE
		),
	}, PLAYPEN_BILLBOARD_SCALE)
end

local function SlimeBillboards()
	local activeSlimes = ReactCharm.useAtom(SlimeSlice.state.slimes)
	local billboards = {}

	for entryId, entry in activeSlimes do
		local slimeInfo = Slimes.getSlimeInfo(entry.slimeId)
		local formattedOdds = Slimes.getFormattedSlimeOdds(entry.slimeId)

		billboards[entryId] = e("BillboardGui", {
			Adornee = entry.adornee,
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 100,
			Size = if entry.billboardType == "playpen"
				then UDim2.fromOffset(119, 144)
				else UDim2.fromOffset(190, 288),
		}, {
			Stats = if entry.billboardType == "playpen"
				then createPlaypenStats(slimeInfo, formattedOdds, entry.storedSlime, entry.level, entry.mutationId)
				else createPurchaseStats(slimeInfo, formattedOdds, entry.mutationId),
		})
	end

	return e(React.Fragment, nil, billboards)
end

return SlimeBillboards
