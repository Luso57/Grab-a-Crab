local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local SlimeDetails = require(ReplicatedStorage.Source.Features.Inventory.UI.Components.SlimeDetails)
local InventorySlice = require(ReplicatedStorage.Source.Features.Inventory.InventorySlice)
local NotificationSlice = require(ReplicatedStorage.Source.Features.App.NotificationSlice)
local InventoryWindow = require(ReplicatedStorage.Source.Features.Inventory.UI.Screens.InventoryWindow)
local SlimeEconomy = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeEconomy)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function InventoryRoot(props: Props)
	local ownedSlimes, setOwnedSlimes = React.useState(table.clone(PlayerData.slimes()))
	local currency, setCurrency = React.useState(PlayerData.currency())
	local tutorial, setTutorial = React.useState(PlayerData.tutorial())
	local selectedInstanceId = ReactCharm.useAtom(InventorySlice.state.selectedInstanceId)
	local pendingUpgradeInstanceId, setPendingUpgradeInstanceId = React.useState(nil :: string?)
	local pendingUpgradeRef = React.useRef(nil :: string?)
	local pendingUpgradeTokenRef = React.useRef(0)

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

	React.useEffect(function()
		return PlayerData.tutorial.Changed(function(nextTutorial)
			setTutorial(table.clone(nextTutorial))
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
		local mutation = SlimeMutations.get(slimeData.mutationId)
		table.insert(items, {
			key = slimeData.instanceId,
			name = slimeInfo.name,
			image = slimeInfo.image,
			rarity = slimeInfo.rarity,
			rarityColor = Slimes.getRarityColor(slimeInfo.rarity),
			mutation = if mutation.id == "normal" then nil else string.upper(mutation.name),
			mutationColor = mutation.color,
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
		local mutation = SlimeMutations.get(selectedSlimeData.mutationId)
		local level = SlimeEconomy.getLevel(selectedSlimeData.level)
		local production = SlimeEconomy.getProduction(slimeInfo.income, level) * mutation.incomeMultiplier
		local nextProduction = SlimeEconomy.getProduction(slimeInfo.income, level + 1) * mutation.incomeMultiplier
		local upgradeCost = SlimeEconomy.getUpgradeCost(slimeInfo.cost, level)
		local sellValue = SlimeEconomy.getSellValue(slimeInfo.cost, selectedSlimeData.upgradeInvestment)
		local isTutorialSlime = not tutorial.completed
			and tutorial.targetSlimeInstanceId ~= ""
			and tutorial.targetSlimeInstanceId == selectedSlimeData.instanceId

		details = React.createElement(SlimeDetails, {
			Name = slimeInfo.name,
			Image = slimeInfo.image,
			Rarity = slimeInfo.rarity,
			RarityColor = Slimes.getRarityColor(slimeInfo.rarity),
			Mutation = if mutation.id == "normal" then nil else string.upper(mutation.name),
			MutationColor = mutation.color,
			MutationMultiplier = mutation.incomeMultiplier,
			Level = level,
			Production = production,
			NextProduction = nextProduction,
			UpgradeCost = upgradeCost,
			SellValue = sellValue,
			CanAfford = currency >= upgradeCost,
			CanSell = not isTutorialSlime,
			HighlightUpgrade = isTutorialSlime and tutorial.step == "upgradeSlime",
			OnClose = function()
				InventorySlice.actions.clearSelection()
			end,
			UpgradePending = pendingUpgradeInstanceId == selectedSlimeData.instanceId,
			OnUpgrade = function()
				if pendingUpgradeRef.current ~= nil then return end
				local plot = PlotServiceClient:getLocalPlayerPlot()
				if not plot then
					NotificationSlice.actions.show("UPGRADE FAILED. PLEASE TRY AGAIN.")
					return
				end

				local instanceId = selectedSlimeData.instanceId
				local requestToken = pendingUpgradeTokenRef.current + 1
				pendingUpgradeTokenRef.current = requestToken
				pendingUpgradeRef.current = instanceId
				setPendingUpgradeInstanceId(instanceId)

				task.delay(10, function()
					if pendingUpgradeTokenRef.current ~= requestToken then return end
					NotificationSlice.actions.show("UPGRADE IS TAKING LONGER THAN EXPECTED. PLEASE WAIT.")
				end)

				task.spawn(function()
					local requestSuccess, result, confirmedLevel, confirmedCurrency = pcall(function()
						return plot:requestSlimeUpgrade(instanceId)
					end)
					if pendingUpgradeTokenRef.current ~= requestToken then return end

					pendingUpgradeTokenRef.current += 1
					pendingUpgradeRef.current = nil
					setPendingUpgradeInstanceId(nil)

					if not requestSuccess then
						NotificationSlice.actions.show("UPGRADE FAILED. PLEASE TRY AGAIN.")
						return
					end
					if result == "success" and type(confirmedLevel) == "number" then
						setOwnedSlimes(function(previousSlimes)
							local nextSlimes = table.clone(previousSlimes)
							for index, slimeData in nextSlimes do
								if slimeData.instanceId == instanceId then
									local nextSlime = table.clone(slimeData)
									nextSlime.level = confirmedLevel
									nextSlimes[index] = nextSlime
									break
								end
							end
							return nextSlimes
						end)
						if type(confirmedCurrency) == "number" then
							setCurrency(confirmedCurrency)
						end
					elseif result ~= "insufficientMoney" then
						NotificationSlice.actions.show("UPGRADE FAILED. PLEASE TRY AGAIN.")
					end
				end)
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
