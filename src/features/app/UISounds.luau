local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local SELECT_SOUND_ID = "rbxassetid://127366656618533"
local SHOP_OPEN_SOUND_ID = "rbxassetid://127488139302452"
local SOUND_LIFETIME = 5

local UISounds = {}

function UISounds.playSelect()
	local sound = Instance.new("Sound")
	sound.Name = "UISelect"
	sound.SoundId = SELECT_SOUND_ID
	sound.Volume = 0.7
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, SOUND_LIFETIME)
end

function UISounds.playShopOpen()
	local sound = Instance.new("Sound")
	sound.Name = "UIShopOpen"
	sound.SoundId = SHOP_OPEN_SOUND_ID
	sound.Volume = 0.7
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, SOUND_LIFETIME)
end

return UISounds
