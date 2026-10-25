--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TankCrabAnimatorClient = require(script.Parent.TankCrabAnimatorClient)
local TankCrabBillboard = require(script.Parent.Parent.UI.TankCrabBillboard)
local MoneyPadDisplay = require(script.Parent.Parent.UI.MoneyPadDisplay)

local TankClient = {}
TankClient.__index = TankClient

export type TankClient = typeof(setmetatable({} :: {
	instanceId: string,
	model: Model,
	onOpen: (Model) -> (),
	onCollect: () -> (),
	animators: { [BasePart]: TankCrabAnimatorClient.TankCrabAnimatorClient },
	destroyBillboard: () -> (),
	destroyMoneyPadDisplay: () -> (),
	openPrompt: ProximityPrompt?,
	openConnection: RBXScriptConnection?,
	collectionConnection: RBXScriptConnection?,
	pulsePart: BasePart?,
	pulseTween: Tween?,
}, TankClient))

function TankClient.new(instanceId: string, model: Model, onOpen: (Model) -> (), onCollect: () -> ()): TankClient
	local self = setmetatable({
		instanceId = instanceId,
		model = model,
		onOpen = onOpen,
		onCollect = onCollect,
		animators = {} :: { [BasePart]: TankCrabAnimatorClient.TankCrabAnimatorClient },
		destroyBillboard = TankCrabBillboard.attach(model),
		destroyMoneyPadDisplay = MoneyPadDisplay.attach(model),
		openPrompt = nil :: ProximityPrompt?,
		openConnection = nil :: RBXScriptConnection?,
		collectionConnection = nil :: RBXScriptConnection?,
		pulsePart = nil :: BasePart?,
		pulseTween = nil :: Tween?,
	}, TankClient) :: TankClient
	local lastCollectionSerial = model:GetAttribute("MoneyPadCollectionSerial")
	self.collectionConnection = model:GetAttributeChangedSignal("MoneyPadCollectionSerial"):Connect(function()
		local serial = model:GetAttribute("MoneyPadCollectionSerial")
		if typeof(serial) == "number" and typeof(lastCollectionSerial) == "number" and serial > lastCollectionSerial then
			self:playMoneyPadPulse()
			self.onCollect()
		end
		lastCollectionSerial = serial
	end)
	return self
end

function TankClient.clearMoneyPadPulse(self: TankClient)
	if self.pulseTween then
		self.pulseTween:Cancel()
		self.pulseTween = nil
	end
	if self.pulsePart then
		self.pulsePart:Destroy()
		self.pulsePart = nil
	end
end

function TankClient.playMoneyPadPulse(self: TankClient)
	self:clearMoneyPadPulse()
	local pad = self.model:FindFirstChild("MoneyPad")
	local green = if pad then pad:FindFirstChild("GreenInnerCircle") else nil
	local blue = if pad then pad:FindFirstChild("BlueOuterCircle") else nil
	if not green or not green:IsA("BasePart") or not blue or not blue:IsA("BasePart") then
		return
	end

	local pulse = green:Clone()
	pulse.Name = "MoneyPadPulse"
	pulse:ClearAllChildren()
	pulse.Anchored = true
	pulse.CanCollide = false
	pulse.CanTouch = false
	pulse.CanQuery = false
	pulse.CastShadow = false
	pulse.CFrame = green.CFrame + Vector3.new(0, 0.015, 0)
	pulse.Parent = pad
	self.pulsePart = pulse

	local expandedSize = Vector3.new(green.Size.X, math.max(green.Size.Y, blue.Size.Y - 0.04), math.max(green.Size.Z, blue.Size.Z - 0.04))
	local expand = TweenService:Create(pulse, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = expandedSize })
	self.pulseTween = expand
	expand.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed or self.pulsePart ~= pulse then
			return
		end
		local shrink = TweenService:Create(pulse, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = green.Size })
		self.pulseTween = shrink
		shrink.Completed:Once(function()
			if self.pulsePart == pulse then
				self:clearMoneyPadPulse()
			end
		end)
		shrink:Play()
	end)
	expand:Play()
end

function TankClient.syncCrabs(self: TankClient)
	local folder = self.model:FindFirstChild("ContainedCrabs")
	local floor = self.model:FindFirstChild("InsideFloor", true)
	if not folder or not floor or not floor:IsA("BasePart") then
		return
	end

	local present: { [BasePart]: boolean } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child.Name == "ContainedCrabAnchor" then
			present[child] = true
			if not self.animators[child] then
				local animator = TankCrabAnimatorClient.new(child, floor, self.model)
				if animator then
					self.animators[child] = animator
				end
			end
		end
	end

	for anchor, animator in self.animators do
		if not present[anchor] then
			animator:destroy()
			self.animators[anchor] = nil
		end
	end
end

function TankClient.update(self: TankClient, hasCrabEquipped: boolean, isPlacingDecoration: boolean)
	self:syncCrabs()
	local floor = self.model:FindFirstChild("InsideFloor", true)
	if not floor or not floor:IsA("BasePart") then
		return
	end
	if not self.openPrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenTankPrompt"
		prompt.ActionText = "Open"
		prompt.ObjectText = "Tank"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = floor
		self.openPrompt = prompt
		self.openConnection = prompt.Triggered:Connect(function(player)
			if player == Players.LocalPlayer and prompt.Enabled then
				self.onOpen(self.model)
			end
		end)
	end

	local placedFolder = self.model.Parent
	local plotModel = if placedFolder then placedFolder.Parent else nil
	local isOwner = placedFolder ~= nil and placedFolder.Name == "PlacedItems"
		and plotModel ~= nil and plotModel:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
	local capacity = self.model:GetAttribute("TankCapacity")
	local count = self.model:GetAttribute("ContainedCrabCount")
	local isFull = typeof(capacity) == "number" and typeof(count) == "number" and count >= capacity
	self.openPrompt.Enabled = isOwner and not isPlacingDecoration and (not hasCrabEquipped or isFull)

	local placePrompt = self.model:FindFirstChild("PlaceCrabPrompt", true)
	if placePrompt and placePrompt:IsA("ProximityPrompt") then
		placePrompt.Enabled = isOwner and hasCrabEquipped and not isPlacingDecoration
			and typeof(capacity) == "number" and typeof(count) == "number" and count < capacity
	end
end

function TankClient.step(self: TankClient, dt: number, cameraPosition: Vector3)
	for _, animator in self.animators do
		animator:step(dt, cameraPosition)
	end
end

function TankClient.correctContainment(self: TankClient, cameraPosition: Vector3)
	for _, animator in self.animators do
		animator:correctContainment(cameraPosition)
	end
end

function TankClient.destroy(self: TankClient)
	if self.collectionConnection then
		self.collectionConnection:Disconnect()
		self.collectionConnection = nil
	end
	self:clearMoneyPadPulse()
	self.destroyBillboard()
	self.destroyMoneyPadDisplay()
	if self.openConnection then
		self.openConnection:Disconnect()
		self.openConnection = nil
	end
	if self.openPrompt then
		self.openPrompt:Destroy()
		self.openPrompt = nil
	end
	local placePrompt = self.model:FindFirstChild("PlaceCrabPrompt", true)
	if placePrompt and placePrompt:IsA("ProximityPrompt") then
		placePrompt.Enabled = false
	end
	for anchor, animator in self.animators do
		animator:destroy()
		self.animators[anchor] = nil
	end
end

return TankClient
