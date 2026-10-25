--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)

local DISPLAY_SCALE = 0.8
local SURFACE_GAP = 0.05

local EggServer = {}
EggServer.__index = EggServer

export type EggServer = typeof(setmetatable({} :: {
	model: Model,
	driver: Part,
	prompt: ProximityPrompt,
	tween: Tween,
	completion: RBXScriptConnection?,
	triggerConnection: RBXScriptConnection?,
	claimed: boolean,
	destroyed: boolean,
}, EggServer))

local function pivotAboveMarker(marker: BasePart, bottomOffset: number): CFrame
	return marker.CFrame * CFrame.new(0, marker.Size.Y / 2 + bottomOffset + SURFACE_GAP, 0)
end

function EggServer.new(template: Model, parent: Folder, spawnA: BasePart, spawnB: BasePart, speed: number): EggServer
	local model = template:Clone()
	model:ScaleTo(DISPLAY_SCALE)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottomOffset = model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	local startCFrame = pivotAboveMarker(spawnA, bottomOffset)
	local endCFrame = pivotAboveMarker(spawnB, bottomOffset)
	model:PivotTo(startCFrame)

	local driver = Instance.new("Part")
	driver.Name = "ConveyorDriver"
	driver.Size = Vector3.new(0.2, 0.2, 0.2)
	driver.CFrame = model:GetPivot()
	driver.Transparency = 1
	driver.Anchored = true
	driver.CanCollide = false
	driver.CanTouch = false
	driver.CanQuery = false
	driver.CastShadow = false
	driver.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GetEggPrompt"
	local definition = Eggs.get(template.Name)
	prompt.ActionText = if definition and definition.price > 0 then "Buy Egg" else "Get Egg"
	prompt.ObjectText = if definition then definition.name else template.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = driver

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= driver then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = driver
			weld.Part1 = descendant
			weld.Parent = driver
			descendant.Anchored = false
		end
	end

	model.PrimaryPart = driver
	model:SetAttribute("EggId", template.Name)
	model:SetAttribute("CrabId", template:GetAttribute("CrabId"))
	model.Parent = parent

	local travelTime = (endCFrame.Position - startCFrame.Position).Magnitude / speed
	local tween = TweenService:Create(driver, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		CFrame = endCFrame,
	})
	return setmetatable({
		model = model,
		driver = driver,
		prompt = prompt,
		tween = tween,
		completion = nil :: RBXScriptConnection?,
		triggerConnection = nil :: RBXScriptConnection?,
		claimed = false,
		destroyed = false,
	}, EggServer) :: EggServer
end

function EggServer.start(self: EggServer, onFinished: () -> (), onTriggered: (Player) -> ())
	self.completion = self.tween.Completed:Connect(function(playbackState)
		if self.destroyed or playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		self:destroy()
		onFinished()
	end)
	self.triggerConnection = self.prompt.Triggered:Connect(onTriggered)
	self.tween:Play()
end

function EggServer.reserve(self: EggServer): boolean
	if self.destroyed or self.claimed then
		return false
	end
	self.claimed = true
	self.prompt.Enabled = false
	return true
end

function EggServer.release(self: EggServer)
	if self.destroyed or not self.claimed then
		return
	end
	self.claimed = false
	self.prompt.Enabled = true
end

function EggServer.destroy(self: EggServer)
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.completion then
		self.completion:Disconnect()
		self.completion = nil
	end
	if self.triggerConnection then
		self.triggerConnection:Disconnect()
		self.triggerConnection = nil
	end
	self.prompt.Enabled = false
	self.tween:Cancel()
	self.model:Destroy()
end

return EggServer
