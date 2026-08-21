local TutorialGuide = {}

local ARROW_TEXTURE = "rbxassetid://106474260367950"

local function targetAttachment(target: Instance): (Attachment?, boolean)
	if target:IsA("Attachment") then return target, false end
	if not target:IsA("BasePart") then return nil, false end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialTargetAttachment"
	attachment.Parent = target
	return attachment, true
end

function TutorialGuide.create(root: Attachment, target: Instance): () -> ()
	local targetAttach, ownsAttachment = targetAttachment(target)
	if not targetAttach then return function() end end

	local beam = Instance.new("Beam")
	beam.Name = "TutorialGuideBeam"
	beam.Attachment0 = root
	beam.Attachment1 = targetAttach
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Texture = ARROW_TEXTURE
	beam.TextureLength = 4.5
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureSpeed = 2.4
	beam.Transparency = NumberSequence.new(0)
	beam.Width0 = 2.25
	beam.Width1 = 2.25
	beam.Parent = workspace

	local cleaned = false
	return function()
		if cleaned then return end
		cleaned = true
		beam:Destroy()
		if ownsAttachment and targetAttach.Parent then targetAttach:Destroy() end
	end
end

return TutorialGuide
