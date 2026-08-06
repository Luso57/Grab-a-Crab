local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local InventoryWindow = require(ReplicatedStorage.Source.Features.Inventory.UI.Screens.InventoryWindow)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function getIndexItems()
	local slimeIds = table.clone(Slimes.slimeIds)

	table.sort(slimeIds, function(leftId, rightId)
		local left = Slimes.getSlimeInfo(leftId)
		local right = Slimes.getSlimeInfo(rightId)

		if left.chance == right.chance then
			return left.name < right.name
		end

		return left.chance < right.chance
	end)

	local items = table.create(#slimeIds)
	for _, slimeId in slimeIds do
		local slime = Slimes.getSlimeInfo(slimeId)
		table.insert(items, {
			name = slime.name,
			image = slime.image,
			rarity = slime.rarity,
			rarityColor = Slimes.getRarityColor(slime.rarity),
		})
	end

	return items
end

local INDEX_ITEMS = getIndexItems()

local function IndexRoot(props: Props)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.IsOpen,
		ZIndex = 20,
	}, {
		Window = React.createElement(InventoryWindow, {
			OnClose = props.OnClose,
			Title = "INDEX",
			Items = INDEX_ITEMS,
		}),
	})
end

return IndexRoot
