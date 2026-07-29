local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

local ROLL_DURATION = 5
local REVEAL_DURATION = 1.25
local FAST_INTERVAL = 0.08
local SLOW_INTERVAL = 0.55
local WINNER_ROTATION_SPEED = math.rad(25)
local ROLL_TICK_SOUND_ID = "rbxassetid://77492142951486"
local REVEAL_SOUND_ID = "rbxassetid://105950779441479"
local SOUND_MAX_DISTANCE = 70

local RollHandle = {}
RollHandle.__index = RollHandle

export type RollHandle = typeof(setmetatable(
	{} :: {
		active: boolean,
		cancelled: boolean,
		currentModel: Model?,
		tickSound: Sound?,
		revealSound: Sound?,
	},
	RollHandle
))

local function getSpawnPivot(spawner: BasePart, slimeModel: Model): CFrame
	local modelPivot = slimeModel:GetPivot()
	local boundingBoxCFrame, boundingBoxSize = slimeModel:GetBoundingBox()
	local boundingBoxToPivot = boundingBoxCFrame:ToObjectSpace(modelPivot)

	local surfaceOffset = spawner.Size.X / 2 + boundingBoxSize.Y / 2
	local position = spawner.Position + spawner.CFrame.RightVector * surfaceOffset
	local targetBoundingBox = CFrame.new(position) * boundingBoxCFrame.Rotation

	return targetBoundingBox * boundingBoxToPivot
end

local function createTextLabel(parent: Instance, name: string, layoutOrder: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.LayoutOrder = layoutOrder
	label.Size = UDim2.new(1, 0, 0, 34)
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = parent

	return label
end

local function createBillboard(rootPart: BasePart, slimeModel: Model): (BillboardGui, TextLabel, TextLabel, TextLabel)
	local boundingBoxCFrame, boundingBoxSize = slimeModel:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position + boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2)

	local attachment = Instance.new("Attachment")
	attachment.Name = "RollVFXAttachment"
	attachment.Position = rootPart.CFrame:PointToObjectSpace(topPosition)
	attachment.Parent = rootPart

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RollVFXBillboard"
	billboard.Adornee = attachment
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.Size = UDim2.fromOffset(190, 230)
	billboard.Parent = rootPart

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.AnchorPoint = Vector2.new(0.5, 1)
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.new(0.5, 0, 0.5, -12)
	stats.Size = UDim2.fromOffset(190, 110)
	stats.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = stats

	local nameLabel = createTextLabel(stats, "SlimeName", 1, Color3.new(1, 1, 1))
	local oddsLabel = createTextLabel(stats, "Odds", 2, Color3.fromRGB(65, 255, 55))
	local rarityLabel = createTextLabel(stats, "Rarity", 3, Color3.new(1, 1, 1))

	return billboard, nameLabel, oddsLabel, rarityLabel
end

local function applyMysteryAppearance(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = Color3.new(0, 0, 0)
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0

			if descendant.Transparency < 1 then
				descendant.Transparency = 0
			end

			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		elseif descendant:IsA("SpecialMesh") then
			descendant.TextureId = ""
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") or descendant:IsA("SurfaceAppearance") then
			descendant:Destroy()
		elseif
			descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
			or descendant:IsA("Smoke")
			or descendant:IsA("Fire")
			or descendant:IsA("Sparkles")
			or descendant:IsA("Light")
		then
			descendant.Enabled = false
		end
	end
end

local function createRollSound(
	parent: BasePart,
	name: string,
	soundId: string,
	volume: number
): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = SOUND_MAX_DISTANCE
	sound.Parent = parent

	return sound
end

local function destroyRollSounds(handle: RollHandle)
	if handle.tickSound then
		handle.tickSound:Destroy()
		handle.tickSound = nil
	end

	if handle.revealSound then
		handle.revealSound:Destroy()
		handle.revealSound = nil
	end
end

local function createDisplay(spawner: BasePart, slimeId: string)
	local model = Slimes.getSlimeModel(slimeId)
	local rootPart = model:FindFirstChildWhichIsA("BasePart", true)
	assert(rootPart, `Slime model has no BaseParts: {slimeId}`)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	model:PivotTo(getSpawnPivot(spawner, model))
	model.Parent = spawner.Parent

	local silhouette = Instance.new("Highlight")
	silhouette.Name = "MysterySilhouette"
	silhouette.DepthMode = Enum.HighlightDepthMode.Occluded
	silhouette.FillColor = Color3.new(0, 0, 0)
	silhouette.FillTransparency = 1
	silhouette.OutlineColor = Color3.new(1, 1, 1)
	silhouette.OutlineTransparency = 0
	silhouette.Parent = model

	local billboard, nameLabel, oddsLabel, rarityLabel = createBillboard(rootPart, model)

	return {
		model = model,
		silhouette = silhouette,
		billboard = billboard,
		nameLabel = nameLabel,
		oddsLabel = oddsLabel,
		rarityLabel = rarityLabel,
	}
end

local function showMystery(display, slimeId: string)
	display.nameLabel.Text = "???"
	display.oddsLabel.Text = `1 in {Slimes.getSlimeOneInOdds(slimeId)}`
	display.rarityLabel.Text = "???"
end

local function revealWinner(display, winnerId: string)
	local slimeInfo = Slimes.getSlimeInfo(winnerId)

	display.silhouette.FillTransparency = 1
	display.nameLabel.Text = slimeInfo.name
	display.oddsLabel.Text = `1 in {Slimes.getSlimeOneInOdds(winnerId)}`
	display.rarityLabel.Text = slimeInfo.rarity
end

function RollHandle.cancel(self: RollHandle)
	if not self.active then
		return
	end

	self.cancelled = true
	self.active = false

	if self.currentModel then
		self.currentModel:Destroy()
		self.currentModel = nil
	end

	destroyRollSounds(self)
end

function RollHandle.isActive(self: RollHandle): boolean
	return self.active
end

local SlimeRollVFX = {}

function SlimeRollVFX.play(
	spawner: BasePart,
	winnerId: string,
	animationSeed: number,
	onFinished: ((finalRotation: number) -> ())?
): RollHandle
	Slimes.getSlimeInfo(winnerId)
	assert(#Slimes.slimeIds > 0, "Cannot play slime roll VFX because the slime catalog is empty")

	local handle = setmetatable({
		active = true,
		cancelled = false,
		currentModel = nil,
		tickSound = createRollSound(spawner, "RollTick", ROLL_TICK_SOUND_ID, 0.55),
		revealSound = createRollSound(spawner, "RevealChime", REVEAL_SOUND_ID, 0.7),
	}, RollHandle)

	task.spawn(function()
		local completed = false
		local finalRotation = 0

		local success, errorMessage = xpcall(function()
			local random = Random.new(animationSeed)
			local catalogIndex = random:NextInteger(1, #Slimes.slimeIds)
			local startedAt = os.clock()

			while not handle.cancelled do
				local elapsed = os.clock() - startedAt
				if elapsed >= ROLL_DURATION then
					break
				end

				if handle.currentModel then
					handle.currentModel:Destroy()
					handle.currentModel = nil
				end

				local previewId = Slimes.slimeIds[catalogIndex]
				local display = createDisplay(spawner, previewId)
				handle.currentModel = display.model
				applyMysteryAppearance(display.model)
				showMystery(display, previewId)

				local progress = math.clamp(elapsed / ROLL_DURATION, 0, 1)
				if handle.tickSound then
					handle.tickSound.PlaybackSpeed = 1.08 - 0.2 * progress
					handle.tickSound.TimePosition = 0
					handle.tickSound:Play()
				end

				catalogIndex = catalogIndex % #Slimes.slimeIds + 1

				local easedProgress = progress ^ 3
				local interval = FAST_INTERVAL + (SLOW_INTERVAL - FAST_INTERVAL) * easedProgress
				local remainingTime = ROLL_DURATION - (os.clock() - startedAt)

				task.wait(math.max(0, math.min(interval, remainingTime)))
			end

			if handle.cancelled then
				return
			end

			if handle.currentModel then
				handle.currentModel:Destroy()
				handle.currentModel = nil
			end

			local winnerDisplay = createDisplay(spawner, winnerId)
			handle.currentModel = winnerDisplay.model
			showMystery(winnerDisplay, winnerId)
			revealWinner(winnerDisplay, winnerId)

			if handle.revealSound then
				handle.revealSound:Play()
			end

			local winnerBasePivot = winnerDisplay.model:GetPivot()
			local revealStartedAt = os.clock()

			while not handle.cancelled do
				local revealElapsed = os.clock() - revealStartedAt
				if revealElapsed >= REVEAL_DURATION then
					break
				end

				finalRotation = revealElapsed * WINNER_ROTATION_SPEED
				winnerDisplay.model:PivotTo(winnerBasePivot * CFrame.Angles(0, finalRotation, 0))
				task.wait()
			end

			if not handle.cancelled then
				finalRotation = REVEAL_DURATION * WINNER_ROTATION_SPEED
				winnerDisplay.model:PivotTo(winnerBasePivot * CFrame.Angles(0, finalRotation, 0))
				completed = true
			end
		end, debug.traceback)

		if handle.currentModel then
			handle.currentModel:Destroy()
			handle.currentModel = nil
		end

		destroyRollSounds(handle)
		handle.active = false

		if not success then
			warn(`Slime roll VFX failed:\n{errorMessage}`)
			return
		end

		if completed and onFinished then
			task.spawn(onFinished, finalRotation)
		end
	end)

	return handle
end

return SlimeRollVFX
