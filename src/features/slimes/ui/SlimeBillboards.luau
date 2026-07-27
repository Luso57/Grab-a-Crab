local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)
local SlimeSlice = require(ReplicatedStorage.Source.Features.Slimes.SlimeSlice)

local e = React.createElement

local function formatCompactNumber(value: number): string
	local divisor = 1
	local suffix = ""

	if value >= 1_000_000_000 then
		divisor = 1_000_000_000
		suffix = "b"
	elseif value >= 1_000_000 then
		divisor = 1_000_000
		suffix = "m"
	elseif value >= 1_000 then
		divisor = 1_000
		suffix = "k"
	end

	local scaledValue = value / divisor
	local formattedValue = if scaledValue % 1 == 0
		then tostring(math.floor(scaledValue))
		else string.format("%.1f", scaledValue)

	return formattedValue .. suffix
end

local function createStatLabel(text: string, color: Color3, layoutOrder: number)
	return e("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
	})
end

local function SlimeBillboards()
	local activeSlimes = ReactCharm.useAtom(SlimeSlice.state.slimes)
	local billboards = {}

	for entryId, entry in activeSlimes do
		local slimeInfo = Slimes.getSlimeInfo(entry.slimeId)
		local oneInOdds = Slimes.getSlimeOneInOdds(entry.slimeId)

		billboards[entryId] = e("BillboardGui", {
			Adornee = entry.adornee,
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 100,
			Size = UDim2.fromOffset(190, 288),
		}, {
			Stats = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, -12),
				Size = UDim2.fromOffset(190, 132),
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				Name = createStatLabel(slimeInfo.name, Color3.new(1, 1, 1), 1),
				Odds = createStatLabel(`1 in {oneInOdds}`, Color3.fromRGB(65, 255, 55), 2),
				Income = createStatLabel(
					`${formatCompactNumber(slimeInfo.income)}/s`,
					Color3.fromRGB(255, 221, 33),
					3
				),
				Cost = createStatLabel(`${formatCompactNumber(slimeInfo.cost)}`, Color3.fromRGB(65, 255, 55), 4),
			}),
		})
	end

	return e(React.Fragment, nil, billboards)
end

return SlimeBillboards
