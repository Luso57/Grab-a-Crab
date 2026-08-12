local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local InventoryWindow = require(ReplicatedStorage.Source.Features.Inventory.UI.Screens.InventoryWindow)
local SlimeDiscovery = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeDiscovery)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)

local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"

type MutationId = "normal" | "fire" | "blackMatter"

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function getIndexItems(mutationId: MutationId, discoveredSlimes: { [string]: boolean })
	local slimeIds = table.clone(Slimes.slimeIds)
	local mutation = SlimeMutations.get(mutationId)

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
		local isDiscovered = SlimeDiscovery.isDiscovered(discoveredSlimes, slimeId, mutationId)
		table.insert(items, {
			key = `{mutationId}-{slimeId}`,
			name = if isDiscovered then slime.name else "???",
			image = slime.image,
			rarity = slime.rarity,
			rarityColor = Slimes.getRarityColor(slime.rarity),
			mutation = if mutationId == "normal" then nil else string.upper(mutation.name),
			mutationColor = if mutationId == "normal" then nil else mutation.color,
			locked = not isDiscovered,
		})
	end

	return items
end

type MutationButtonDefinition = {
	id: MutationId,
	label: string,
	color: Color3,
	darkColor: Color3,
}

local MUTATION_BUTTONS: { MutationButtonDefinition } = {
	{
		id = "normal",
		label = "NORMAL",
		color = Color3.fromRGB(210, 215, 222),
		darkColor = Color3.fromRGB(91, 97, 107),
	},
	{
		id = "fire",
		label = "FIRE",
		color = Color3.fromRGB(255, 105, 28),
		darkColor = Color3.fromRGB(135, 43, 15),
	},
	{
		id = "blackMatter",
		label = "BLACK MATTER",
		color = Color3.fromRGB(178, 63, 255),
		darkColor = Color3.fromRGB(67, 22, 100),
	},
}

local function MutationButton(props: {
	Id: MutationId,
	Label: string,
	Color: Color3,
	DarkColor: Color3,
	Selected: boolean,
	LayoutOrder: number,
	OnActivated: (MutationId) -> (),
})
	local backgroundColor = if props.Selected then props.Color else props.DarkColor

	return React.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0.29),
		Text = props.Label,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextWrapped = true,
		Font = Enum.Font.FredokaOne,
		ZIndex = 27,
		[React.Event.Activated] = function()
			if not props.Selected then
				UISounds.playSelect()
				props.OnActivated(props.Id)
			end
		end,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 9),
		}),
		Gradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, backgroundColor:Lerp(Color3.new(1, 1, 1), 0.18)),
				ColorSequenceKeypoint.new(1, backgroundColor:Lerp(Color3.new(0, 0, 0), 0.25)),
			}),
			Rotation = 90,
		}),
		Pattern = React.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Image = STUD_BACKGROUND_IMAGE,
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = 0.82,
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.fromScale(1, 1),
			TileSize = UDim2.fromOffset(26, 26),
			ZIndex = 26,
		}),
		Stroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = if props.Selected then Color3.new(1, 1, 1) else Color3.fromRGB(15, 16, 20),
			Thickness = if props.Selected then 4 else 3,
		}),
		TextConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = 27,
			MinTextSize = 10,
		}),
	})
end

local function IndexRoot(props: Props)
	local selectedMutation, setSelectedMutation = React.useState("normal" :: MutationId)
	local discoveredSlimes, setDiscoveredSlimes = React.useState(table.clone(PlayerData.discoveredSlimes()))
	local buttons = {}

	React.useEffect(function()
		return PlayerData.discoveredSlimes.Changed(function(nextDiscoveredSlimes)
			setDiscoveredSlimes(table.clone(nextDiscoveredSlimes))
		end)
	end, {})

	for layoutOrder, button in MUTATION_BUTTONS do
		buttons[`Mutation-{button.id}`] = React.createElement(MutationButton, {
			Id = button.id,
			Label = button.label,
			Color = button.color,
			DarkColor = button.darkColor,
			Selected = selectedMutation == button.id,
			LayoutOrder = layoutOrder,
			OnActivated = setSelectedMutation,
		})
	end

	buttons.Layout = React.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.045, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	buttons.SizeConstraint = React.createElement("UISizeConstraint", {
		MaxSize = Vector2.new(135, 230),
		MinSize = Vector2.new(90, 165),
	})

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.IsOpen,
		ZIndex = 20,
	}, {
		Window = React.createElement(InventoryWindow, {
			OnClose = props.OnClose,
			Title = "INDEX",
			Items = getIndexItems(selectedMutation, discoveredSlimes),
			SideContent = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(1, 8, 0.5, 0),
				Size = UDim2.fromScale(0.16, 0.34),
				ZIndex = 25,
			}, buttons),
		}),
	})
end

return IndexRoot
