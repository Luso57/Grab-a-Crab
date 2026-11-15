--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlotExtraSlots = require(ReplicatedStorage.Source.Features.Plots.Modules.PlotExtraSlots)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local create = Vide.create

type Card = { instanceId: string, imageId: number, rarity: Rarities.Rarity, rate: string, isBoost: boolean }
local TankCrabBillboard = {}

local cardImages: { [Rarities.Rarity]: { big: number, small: number } } = {
	Common = { big = assets.CommonBigCard, small = assets.CommonSmallCard },
	Uncommon = { big = assets.UncommonBigCard, small = assets.UncommonSmallCard },
	Rare = { big = assets.RareBigCard, small = assets.RareSmallCard },
	Epic = { big = assets.EpicBigCard, small = assets.EpicSmallCard },
	Legendary = { big = assets.LegendaryBigCard, small = assets.LegendarySmallCard },
	Mythic = { big = assets.MythicBigCard, small = assets.MythicSmallCard },
}

local function cardPosition(index: number, count: number): UDim2
	if count == 1 then
		return UDim2.fromScale(0.5, 0.34)
	elseif count == 2 then
		return UDim2.fromScale(if index == 1 then 0.25 else 0.75, 0.34)
	elseif count == 3 and index == 3 then
		return UDim2.fromScale(0.5, 0.59)
	end
	return UDim2.fromScale(if index % 2 == 1 then 0.25 else 0.75, if index <= 2 then 0.205 else 0.59)
end

local function makeCard(index: number, cards: () -> { Card }, boostPercent: () -> number): (ImageLabel, UIScale)
	local card = create "ImageLabel" {
		Name = "CrabCard" .. index,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = function()
			local info = cards()[index]
			return if info then "rbxassetid://" .. cardImages[info.rarity].big else ""
		end,
		ScaleType = Enum.ScaleType.Stretch,
		Visible = function()
			return cards()[index] ~= nil
		end,
		Position = function()
			return cardPosition(index, #cards())
		end,
		Size = function()
			return UDim2.fromScale(0.48, if #cards() >= 3 then 0.32 else 0.48)
		end,
	}
	local tile = create "ImageLabel" {
		Name = "RarityTile",
		Position = UDim2.fromScale(0.075, 0.13),
		Size = UDim2.fromScale(0.22, 0.74),
		BackgroundTransparency = 1,
		Image = function()
			local info = cards()[index]
			return if info then "rbxassetid://" .. cardImages[info.rarity].small else ""
		end,
		ScaleType = Enum.ScaleType.Stretch,
		ClipsDescendants = true,
	}
	tile.Parent = card
	local portrait = create "ImageLabel" {
		Name = "CrabImage",
		Position = UDim2.fromScale(0.03, 0.03),
		Size = UDim2.fromScale(0.94, 0.94),
		BackgroundTransparency = 1,
		Image = function()
			local info = cards()[index]
			return if info then "rbxassetid://" .. info.imageId else ""
		end,
		ScaleType = Enum.ScaleType.Fit,
	}
	portrait.Parent = tile
	local coin = create "ImageLabel" {
		Name = "CoinIcon",
		Visible = function()
			local info = cards()[index]
			return info ~= nil and not info.isBoost
		end,
		Position = UDim2.fromScale(0.30, 0.08),
		Size = UDim2.fromScale(0.23, 0.84),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.SandDollar,
		ScaleType = Enum.ScaleType.Fit,
	}
	coin.Parent = card
	local rate = create "TextLabel" {
		Name = "IncomePerSecond",
		Position = UDim2.fromScale(0.53, 0.16),
		Size = UDim2.fromScale(0.44, 0.68),
		BackgroundTransparency = 1,
		Text = function()
			local info = cards()[index]
			return if info then info.rate else ""
		end,
		TextColor3 = function()
			return if boostPercent() > 0 then Color3.fromRGB(80, 235, 88) else Color3.new(1, 1, 1)
		end,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.45,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.BuilderSansExtraBold,
	}
	rate.Parent = card
	local rateScale = create "UIScale" { Scale = 1 }
	rateScale.Parent = rate
	local rateStroke = create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 1.5,
	}
	rateStroke.Parent = rate
	local rateLimit = create "UITextSizeConstraint" { MaxTextSize = 36 }
	rateLimit.Parent = rate
	return card, rateScale
end

function TankCrabBillboard.attach(model: Model): () -> ()
	local cards = Vide.source({} :: { Card })
	local boostPercent = Vide.source(0)
	local capacity = Vide.source(0)
	local driver = Vide.source(model.PrimaryPart)
	local topOffset = Vide.source(0)
	local floorOccluded = Vide.source(false)
	local floorRaycast = RaycastParams.new()
	floorRaycast.FilterType = Enum.RaycastFilterType.Include
	floorRaycast.IgnoreWater = true
	local nextOcclusionCheck = 0
	local connections: { RBXScriptConnection } = {}
	local folderConnections: { RBXScriptConnection } = {}
	local anchorConnections: { [BasePart]: { RBXScriptConnection } } = {}
	local folder: Folder? = nil
	local destroyed = false
	local pulseScales: { [number]: UIScale } = {}
	local pulseTweens: { [number]: Tween } = {}

	local function refreshPulse()
		for index, scale in pulseScales do
			local shouldPulse = boostPercent() > 0 and cards()[index] ~= nil
			local tween = pulseTweens[index]
			if shouldPulse and not tween then
				tween = TweenService:Create(scale, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					Scale = 1.05,
				})
				pulseTweens[index] = tween
				tween:Play()
			elseif not shouldPulse and tween then
				tween:Cancel()
				pulseTweens[index] = nil
				scale.Scale = 1
			end
		end
	end

	local function updateGeometry()
		local primary = model.PrimaryPart
		driver(primary)
		if primary then
			local box, size = model:GetBoundingBox()
			topOffset(box.Position.Y + size.Y / 2 - primary.Position.Y + 0.35)
		end
	end

	local function updateFloorOcclusion()
		local now = os.clock()
		if now < nextOcclusionCheck then
			return
		end
		nextOcclusionCheck = now + 0.1

		local camera = Workspace.CurrentCamera
		local primary = model.PrimaryPart
		local placedFolder = model.Parent
		local plot = if placedFolder then placedFolder.Parent else nil
		if not camera or not primary or not plot or not plot:IsA("Model") then
			floorOccluded(false)
			return
		end

		local decks: { Instance } = {}
		for _, floorName in PlotExtraSlots.floorNames do
			local floor = plot:FindFirstChild(floorName)
			local deck = if floor then floor:FindFirstChild("Deck") else nil
			local mainDeck = if deck then deck:FindFirstChild("MainDeck") else nil
			if mainDeck and mainDeck:IsA("BasePart") then
				table.insert(decks, mainDeck)
			end
		end
		if #decks == 0 then
			floorOccluded(false)
			return
		end

		floorRaycast.FilterDescendantsInstances = decks
		local target = primary.Position + Vector3.new(0, topOffset(), 0)
		local cameraPosition = camera.CFrame.Position
		floorOccluded(Workspace:Raycast(cameraPosition, target - cameraPosition, floorRaycast) ~= nil)
	end

	local function refresh()
		local value = model:GetAttribute("TankCapacity")
		capacity(if typeof(value) == "number" then value else 0)
		local rawBoost = model:GetAttribute("TankIncomeBoostPercent")
		local boost = if typeof(rawBoost) == "number" then rawBoost else 0
		boostPercent(boost)
		local nextCards: { Card } = {}
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") and child.Name == "ContainedCrabAnchor" then
					local crabId = child:GetAttribute("CrabId")
					local definition = if typeof(crabId) == "string" then Crabs.get(crabId) else nil
					if definition then
						local instanceId = child:GetAttribute("ItemInstanceId")
						table.insert(nextCards, {
							instanceId = if typeof(instanceId) == "string" then instanceId else child.Name,
							imageId = definition.imageId,
							rarity = definition.rarity,
							rate = if definition.tankIncomeMultiplier then string.format("x%g BOOST", definition.tankIncomeMultiplier)
								else CompactNumber.formatIncomeRate(CrabWeights.income(definition.incomePerSecond, child:GetAttribute("WeightGrams")) * (1 + boost / 100)) .. "/s",
							isBoost = definition.tankIncomeMultiplier ~= nil,
						})
					end
				end
			end
		end
		table.sort(nextCards, function(a, b)
			return a.instanceId < b.instanceId
		end)
		cards(nextCards)
		refreshPulse()
	end

	local function disconnectFolder()
		for _, connection in folderConnections do
			connection:Disconnect()
		end
		table.clear(folderConnections)
		for _, anchorList in anchorConnections do
			for _, connection in anchorList do
				connection:Disconnect()
			end
		end
		table.clear(anchorConnections)
		folder = nil
	end

	local function watchAnchor(child: Instance)
		if not child:IsA("BasePart") or child.Name ~= "ContainedCrabAnchor" or anchorConnections[child] then
			return
		end
		anchorConnections[child] = {
			child:GetAttributeChangedSignal("CrabId"):Connect(refresh),
			child:GetAttributeChangedSignal("ItemInstanceId"):Connect(refresh),
			child:GetAttributeChangedSignal("WeightGrams"):Connect(refresh),
		}
	end

	local function bindFolder(candidate: Instance?)
		if folder == candidate then
			return
		end
		disconnectFolder()
		if candidate and candidate:IsA("Folder") and candidate.Name == "ContainedCrabs" then
			folder = candidate
			for _, child in candidate:GetChildren() do
				watchAnchor(child)
			end
			table.insert(folderConnections, candidate.ChildAdded:Connect(function(child)
				watchAnchor(child)
				refresh()
			end))
			table.insert(folderConnections, candidate.ChildRemoved:Connect(function(child)
				local anchorList = if child:IsA("BasePart") then anchorConnections[child] else nil
				if anchorList then
					for _, connection in anchorList do
						connection:Disconnect()
					end
					anchorConnections[child] = nil
				end
				refresh()
			end))
		end
		refresh()
	end

	local billboard: BillboardGui? = nil
	local unmount = Vide.mount(function()
		local gui = create "BillboardGui" {
			Name = "TankCrabBillboard",
			Adornee = driver,
			Enabled = function()
				return capacity() > 0 and driver() ~= nil and not floorOccluded()
			end,
			Size = function()
				local count = #cards()
				return UDim2.fromScale(8.5, if count == 0 then 1 else if count >= 3 then 3.9 else 2.6)
			end,
			SizeOffset = Vector2.new(0, 0.5),
			StudsOffsetWorldSpace = function()
				return Vector3.new(0, topOffset(), 0)
			end,
			MaxDistance = 50,
			AlwaysOnTop = true,
			LightInfluence = 0,
		}
		for index = 1, 4 do
			local card, scale = makeCard(index, cards, boostPercent)
			pulseScales[index] = scale
			card.Parent = gui
		end
		local countLabel = create "TextLabel" {
			Name = "OccupiedCount",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.fromScale(0.5, if #cards() == 0 then 0.5 else if #cards() >= 3 then 0.91 else 0.84)
			end,
			Size = function()
				return UDim2.fromScale(0.4, if #cards() == 0 then 0.75 else 0.20)
			end,
			BackgroundTransparency = 1,
			Text = function()
				return tostring(#cards()) .. "/" .. tostring(capacity())
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
		}
		countLabel.Parent = gui
		local countLimit = create "UITextSizeConstraint" { MaxTextSize = 40 }
		countLimit.Parent = countLabel
		billboard = gui
		return gui
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))

	table.insert(connections, model:GetAttributeChangedSignal("TankCapacity"):Connect(refresh))
	table.insert(connections, model:GetAttributeChangedSignal("TankIncomeBoostPercent"):Connect(refresh))
	table.insert(connections, model:GetPropertyChangedSignal("PrimaryPart"):Connect(updateGeometry))
	table.insert(connections, RunService.RenderStepped:Connect(updateFloorOcclusion))
	table.insert(connections, model.ChildAdded:Connect(function(child)
		if child.Name == "ContainedCrabs" then
			bindFolder(child)
		end
	end))
	table.insert(connections, model.ChildRemoved:Connect(function(child)
		if child == folder then
			bindFolder(model:FindFirstChild("ContainedCrabs"))
		end
	end))
	updateGeometry()
	updateFloorOcclusion()
	bindFolder(model:FindFirstChild("ContainedCrabs"))

	return function()
		if destroyed then
			return
		end
		destroyed = true
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, tween in pulseTweens do
			tween:Cancel()
		end
		table.clear(pulseTweens)
		disconnectFolder()
		unmount()
		if billboard then
			billboard:Destroy()
		end
	end
end

return TankCrabBillboard
