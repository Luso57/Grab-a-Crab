local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local SlimeDetails = require(ReplicatedStorage.Source.Features.Inventory.UI.Components.SlimeDetails)
local InventorySlice = require(ReplicatedStorage.Source.Features.Inventory.InventorySlice)
local InventoryWindow = require(ReplicatedStorage.Source.Features.Inventory.UI.Screens.InventoryWindow)
local SlimeEconomy = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeEconomy)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function InventoryRoot(props: Props)
	local ownedSlimes, setOwnedSlimes = React.useState(table.clone(PlayerData.slimes()))
	local currency, setCurrency = React.useState(PlayerData.currency())
	local selectedInstanceId = ReactCharm.useAtom(InventorySlice.state.selectedInstanceId)

	React.useEffect(function()
		return PlayerData.slimes.Changed(function(nextSlimes)
			setOwnedSlimes(table.clone(nextSlimes))
		end)
	end, {})

	React.useEffect(function()
		return PlayerData.currency.Changed(function(nextCurrency)
			setCurrency(nextCurrency)
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
			onActivated = function()
				InventorySlice.actions.select(slimeData.instanceId)
			end,
		})
	end

	local selectedSlimeData = nil
	if selectedInstanceId then
		for _, slimeData in ownedSlimes do
			if slimeData.instanceId == selectedInstanceId and Slimes.isValidSlimeId(slimeData.slimeId) then
				selectedSlimeData = slimeData
				break
			end
		end
	end

	local details = nil
	if selectedSlimeData then
		local slimeInfo = Slimes.getSlimeInfo(selectedSlimeData.slimeId)
		local level = SlimeEconomy.getLevel(selectedSlimeData.level)
		local production = SlimeEconomy.getProduction(slimeInfo.income, level)
		local nextProduction = SlimeEconomy.getProduction(slimeInfo.income, level + 1)
		local upgradeCost = SlimeEconomy.getUpgradeCost(slimeInfo.cost, level)
		local sellValue = SlimeEconomy.getSellValue(slimeInfo.cost, selectedSlimeData.upgradeInvestment)

		details = React.createElement(SlimeDetails, {
			Name = slimeInfo.name,
			Image = slimeInfo.image,
			Rarity = slimeInfo.rarity,
			RarityColor = Slimes.getRarityColor(slimeInfo.rarity),
			Level = level,
			Production = production,
			NextProduction = nextProduction,
			UpgradeCost = upgradeCost,
			SellValue = sellValue,
			CanAfford = currency >= upgradeCost,
			OnClose = function()
				InventorySlice.actions.clearSelection()
			end,
			OnUpgrade = function()
				local plot = PlotServiceClient:getLocalPlayerPlot()
				if plot then
					plot:requestSlimeUpgrade(selectedSlimeData.instanceId)
				end
			end,
			OnSell = function()
				local plot = PlotServiceClient:getLocalPlayerPlot()
				if plot then
					plot:requestSlimeSale(selectedSlimeData.instanceId)
				end
			end,
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
		Details = details,
	})
end

return InventoryRoot
