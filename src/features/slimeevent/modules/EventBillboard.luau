local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Source.Features.Slimeevent.SlimeEventConfig)

local EventBillboard = {}
local Handle = {}
Handle.__index = Handle

export type Handle = typeof(setmetatable({} :: {
	anchor: Attachment,
	gui: BillboardGui,
	label: TextLabel,
}, Handle))

local function formatTime(seconds: number): string
	local wholeSeconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(wholeSeconds / 60), wholeSeconds % 60)
end

function Handle.setCountdown(self: Handle, seconds: number)
	self.label.Text = "EVENT WILL START IN" .. utf8.char(10) .. formatTime(seconds)
	self.label.TextColor3 = Color3.fromRGB(255, 239, 92)
	self.gui:SetAttribute("State", "countdown")
end

function Handle.setInProgress(self: Handle)
	self.label.Text = "EVENT" .. utf8.char(10) .. "IN PROGRESS"
	self.label.TextColor3 = Color3.fromRGB(110, 255, 138)
	self.gui:SetAttribute("State", "inProgress")
end

function Handle.destroy(self: Handle)
	self.anchor:Destroy()
end

function EventBillboard.new(adornee: BasePart): Handle
	local existing = adornee:FindFirstChild("SlimeEventBillboard")
	if existing then existing:Destroy() end
	local existingAnchor = adornee:FindFirstChild("SlimeEventBillboardAnchor")
	if existingAnchor then existingAnchor:Destroy() end

	local anchor = Instance.new("Attachment")
	anchor.Name = "SlimeEventBillboardAnchor"
	anchor.Position = adornee.CFrame:PointToObjectSpace(adornee.Position + Vector3.new(0, Config.EventBillboardHeight, 0))
	anchor.Parent = adornee

	local gui = Instance.new("BillboardGui")
	gui.Name = "SlimeEventBillboard"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = Config.EventBillboardMaxDistance
	gui.Size = UDim2.fromOffset(Config.EventBillboardSize.X, Config.EventBillboardSize.Y)
	gui.Parent = anchor

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(20, 24, 31)
	background.BackgroundTransparency = 0.12
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = background

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = background

	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Position = UDim2.fromOffset(10, 6)
	label.Size = UDim2.new(1, -20, 1, -12)
	label.Text = ""
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = background

	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Thickness = 3
	textStroke.LineJoinMode = Enum.LineJoinMode.Round
	textStroke.Parent = label

	return setmetatable({ anchor = anchor, gui = gui, label = label }, Handle)
end

return EventBillboard
