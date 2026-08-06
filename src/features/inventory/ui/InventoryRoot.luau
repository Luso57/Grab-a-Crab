local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local InventoryWindow = require(ReplicatedStorage.Source.Features.Inventory.UI.Screens.InventoryWindow)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function InventoryRoot(props: Props)
	local ownedSlimes, setOwnedSlimes = React.useState(table.clone(PlayerData.slimes()))

	React.useEffect(function()
		return PlayerData.slimes.Changed(function(nextSlimes)
			setOwnedSlimes(table.clone(nextSlimes))
		end)
	end, {})

	local validSlimes = {}
	for _, slimeData in ownedSlimes do
		if Slimes.isValidSlimeId(slimeData.slimeId) then
			table.insert(validSlimes, slimeData)
		end
	end

	table.sort(validSlimes, function(left, right)
		local leftInfo = Slimes.getSlimeInfo(left.slimeId)
		local rightInfo = Slimes.getSlimeInfo(right.slimeId)

		if leftInfo.chance ~= rightInfo.chance then
			return leftInfo.chance < rightInfo.chance
		end
		if leftInfo.name ~= rightInfo.name then
			return leftInfo.name < rightInfo.name
		end
		return left.instanceId < right.instanceId
	end)

	local items = table.create(#validSlimes)
	for _, slimeData in validSlimes do
		local slimeInfo = Slimes.getSlimeInfo(slimeData.slimeId)
		table.insert(items, {
			key = slimeData.instanceId,
			name = slimeInfo.name,
			image = slimeInfo.image,
			rarity = slimeInfo.rarity,
			rarityColor = Slimes.getRarityColor(slimeInfo.rarity),
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.IsOpen,
		ZIndex = 20,
	}, {
		Window = React.createElement(InventoryWindow, {
			OnClose = props.OnClose,
			Items = items,
			EmptyMessage = "You don't have any slimes yet!",
		}),
	})
end

return InventoryRoot
