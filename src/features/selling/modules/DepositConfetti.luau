local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local CONFETTI_TEMPLATE = ReplicatedStorage.Assets.Misc.Confetti
local DEPOSIT_CHIME_SOUND_ID = "rbxassetid://4612374209"
local EMIT_COUNT = 30
local EFFECT_LIFETIME = 1
local HEIGHT_OFFSET = 2.5

local DepositConfetti = {}

function DepositConfetti.playSound()
	local sound = Instance.new("Sound")
	sound.Name = "DepositChime"
	sound.SoundId = DEPOSIT_CHIME_SOUND_ID
	sound.Volume = 0.8
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
end

function DepositConfetti.play(plotModel: Model)
	local slimeDeposit = plotModel:FindFirstChild("SlimeDeposit")
	if not slimeDeposit or not slimeDeposit:IsA("Model") then
		return
	end

	DepositConfetti.playSound()

	local boundingBoxCFrame, boundingBoxSize = slimeDeposit:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position
		+ boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2 + HEIGHT_OFFSET)

	local effect = CONFETTI_TEMPLATE:Clone()
	effect.Name = "DepositConfetti"
	effect.CFrame = CFrame.new(topPosition) * CONFETTI_TEMPLATE.CFrame.Rotation
	effect.Parent = workspace

	for _, descendant in effect:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant:Emit(EMIT_COUNT)
		end
	end

	Debris:AddItem(effect, EFFECT_LIFETIME)
end

return DepositConfetti
