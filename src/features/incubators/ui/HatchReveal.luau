local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local uiAssets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create
local HatchReveal = {}

local REVEAL_SECONDS = 3
local DISMISS_READY_SECONDS = 0.5
local CRAB_ROTATION_SECONDS = 3.5
local STARTING_ROTATION_MULTIPLIER = 10
local SPIN_DECAY_SECONDS = 0.6
local BURST_ROTATION_SECONDS = 5
local START_VISUAL_SCALE = 0.42
local CAMERA_REFERENCE_WEIGHT_GRAMS = 25
local CAMERA_PADDING = 1.85
local MIN_CAMERA_PADDING = 1.06
local EGG_ZOOM_SECONDS = 0.6
local EGG_SHAKE_SECONDS = 1.2
local SHAKE_SOUND_DELAY_SECONDS = 0.515
local FLASH_IN_SECONDS = 0.16
local FLASH_HOLD_SECONDS = 0.1
local FLASH_OUT_SECONDS = 0.2
local COUNT_SOUND_LENGTH_SECONDS = 5
local REVEAL_SOUND_SECONDS = 1
local REVEAL_SOUND_LENGTH_SECONDS = 2

local function textStroke(parent: TextLabel, thickness: number)
    local stroke = create "UIStroke" {
        Color = Color3.new(0, 0, 0),
        Thickness = thickness,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
    }
    stroke.Parent = parent
end

function HatchReveal.mount(playerGui: PlayerGui, setPromptsLocked: (boolean) -> (), onDismiss: (string) -> ()): (string, number, string?, CFrame?, number?, Vector3?, string?) -> ()
    local shakeSound = Instance.new("Sound")
    shakeSound.Name = "HatchShakeSound"
    shakeSound.SoundId = "rbxassetid://" .. uiAssets.HatchShakeSound
    shakeSound.Looped = true
    shakeSound.Volume = 1
    shakeSound.Parent = playerGui

    local countSound = Instance.new("Sound")
    countSound.Name = "HatchCountSound"
    countSound.SoundId = "rbxassetid://" .. uiAssets.HatchCountSound
    countSound.PlaybackSpeed = COUNT_SOUND_LENGTH_SECONDS / REVEAL_SECONDS
    countSound.Volume = 4
    countSound.Parent = playerGui

    local revealSound = Instance.new("Sound")
    revealSound.Name = "HatchRevealSound"
    revealSound.SoundId = "rbxassetid://" .. uiAssets.HatchRevealSound
    revealSound.PlaybackSpeed = REVEAL_SOUND_LENGTH_SECONDS / REVEAL_SOUND_SECONDS
    revealSound.Volume = 1
    revealSound.Parent = playerGui

    local completeSound = Instance.new("Sound")
    completeSound.Name = "HatchCompleteSound"
    completeSound.SoundId = "rbxassetid://" .. uiAssets.HatchCompleteSound
    completeSound.Volume = 1
    completeSound.Parent = playerGui

    local visible = Vide.source(false)
    local revealVisible = Vide.source(false)
    local flashVisible = Vide.source(false)
    local flashTransparency = Vide.source(1)
    local crabName = Vide.source("")
    local gramText = Vide.source("0.00g")
    local incomeText = Vide.source("")
    local clickHintVisible = Vide.source(false)
    local viewport: ViewportFrame = nil :: any
    local burstImage: ImageLabel = nil :: any
    local readyToDismiss = false
    local dismiss = function() end

    Vide.mount(function()
    burstImage = create "ImageLabel" {
        Name = "HatchBurst",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.72, 0.72),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxassetid://" .. uiAssets.HatchBurst,
        ScaleType = Enum.ScaleType.Fit,
        Rotation = 0,
        ZIndex = 2,
    }
    local burstAspect = create "UIAspectRatioConstraint" {
        AspectRatio = 1,
        DominantAxis = Enum.DominantAxis.Width,
    }
    burstAspect.Parent = burstImage
    local burstSize = create "UISizeConstraint" {
        MaxSize = Vector2.new(560, 560),
    }
    burstSize.Parent = burstImage

    viewport = create "ViewportFrame" {
        Name = "CrabViewport",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.94, 0.78),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(210, 230, 220),
        LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-1, -1, -1),
        ZIndex = 3,
    }

    local nameLabel = create "TextLabel" {
        Name = "CrabName",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.16),
        Size = UDim2.fromScale(0.9, 0.095),
        BackgroundTransparency = 1,
        Text = crabName,
        TextColor3 = Color3.new(1, 1, 1),
        TextScaled = true,
        Font = Enum.Font.BuilderSansExtraBold,
        ZIndex = 4,
    }
    textStroke(nameLabel, 3)

    local gramsLabel = create "TextLabel" {
        Name = "Weight",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.26),
        Size = UDim2.fromScale(0.55, 0.09),
        BackgroundTransparency = 1,
        Text = gramText,
        TextColor3 = Color3.new(1, 1, 1),
        TextScaled = true,
        Font = Enum.Font.BuilderSansExtraBold,
        ZIndex = 4,
    }
    textStroke(gramsLabel, 3)

    local incomeRow = create "Frame" {
        Name = "IncomeRow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.83),
        Size = UDim2.fromOffset(0, 94),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 4,
    }
    local incomeLayout = create "UIListLayout" {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }
    incomeLayout.Parent = incomeRow
    local coinIcon = create "ImageLabel" {
        Name = "CoinIcon",
        LayoutOrder = 1,
        Size = UDim2.fromOffset(82, 82),
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. uiAssets.SandDollar,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 4,
    }
    coinIcon.Parent = incomeRow
    local incomeLabel = create "TextLabel" {
        Name = "Income",
        LayoutOrder = 2,
        Size = UDim2.fromOffset(0, 94),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = incomeText,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 70,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.BuilderSansExtraBold,
        ZIndex = 4,
    }
    textStroke(incomeLabel, 4)
    incomeLabel.Parent = incomeRow

    local dismissButton = create "TextButton" {
        Name = "Dismiss",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
        Activated = function()
            dismiss()
        end,
    }
    local clickHint = create "TextLabel" {
        Name = "ContinueHint",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.94),
        Size = UDim2.fromScale(0.7, 0.045),
        BackgroundTransparency = 1,
        Text = "Click anywhere to continue",
        TextColor3 = Color3.new(1, 1, 1),
        TextScaled = true,
        Font = Enum.Font.BuilderSansBold,
        Visible = clickHintVisible,
        ZIndex = 6,
    }
    textStroke(clickHint, 2)

    local dimBackground = create "Frame" {
        Name = "DimBackground",
        Visible = revealVisible,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        ZIndex = 1,
    }
    burstImage.Parent = dimBackground
    viewport.Parent = dimBackground
    nameLabel.Parent = dimBackground
    gramsLabel.Parent = dimBackground
    incomeRow.Parent = dimBackground
    dismissButton.Parent = dimBackground
    clickHint.Parent = dimBackground

    local whiteFlash = create "Frame" {
        Name = "WhiteFlash",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = flashTransparency,
        BorderSizePixel = 0,
        Visible = flashVisible,
        ZIndex = 10,
    }
    local screen = create "ScreenGui" {
        Name = "HatchReveal",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
        Enabled = visible,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }
    dimBackground.Parent = screen
    whiteFlash.Parent = screen
    return screen
    end, playerGui)

    local runNumber = 0
    local activeInstanceId: string? = nil
    local connection: RBXScriptConnection? = nil
    local introConnection: RBXScriptConnection? = nil
    local world: WorldModel? = nil
    local camera: Camera? = nil
    local introEgg: Model? = nil
    local introCamera: Camera? = nil
    local previousCameraType: Enum.CameraType? = nil
    local previousCameraCFrame: CFrame? = nil
    local previousFieldOfView: number? = nil

    local function restoreIntro()
        local activeCamera = introCamera
        if activeCamera and activeCamera.Parent and Workspace.CurrentCamera == activeCamera then
            if previousCameraCFrame then
                activeCamera.CFrame = previousCameraCFrame
            end
            if previousFieldOfView then
                activeCamera.FieldOfView = previousFieldOfView
            end
            if previousCameraType then
                activeCamera.CameraType = previousCameraType
            end
        end
        introCamera = nil
        previousCameraType = nil
        previousCameraCFrame = nil
        previousFieldOfView = nil
        if introEgg then
            introEgg:Destroy()
            introEgg = nil
        end
    end

    local function cancel()
        runNumber += 1
        local instanceId = activeInstanceId
        activeInstanceId = nil
        shakeSound:Stop()
        countSound:Stop()
        revealSound:Stop()
        completeSound:Stop()
        readyToDismiss = false
        clickHintVisible(false)
        burstImage.Rotation = 0
        if introConnection then
            introConnection:Disconnect()
            introConnection = nil
        end
        if connection then
            connection:Disconnect()
            connection = nil
        end
        restoreIntro()
        if world then
            world:Destroy()
            world = nil
        end
        if camera then
            camera:Destroy()
            camera = nil
            viewport.CurrentCamera = nil
        end
        flashTransparency(1)
        flashVisible(false)
        revealVisible(false)
        visible(false)
        setPromptsLocked(false)
        if instanceId then
            onDismiss(instanceId)
        end
    end

    dismiss = function()
        if readyToDismiss then
            cancel()
        end
    end

    Players.LocalPlayer.CharacterRemoving:Connect(cancel)

    local function startCrabReveal(crabId: string, weightGrams: number)
        local definition = Crabs.get(crabId)
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local models = if assets then assets:FindFirstChild("Crabs") else nil
        local template = if definition and models then models:FindFirstChild(definition.modelName) else nil
        if not definition or not template or not template:IsA("Model") then
            cancel()
            return
        end

        local model = template:Clone()
        local initialHeight = model:GetExtentsSize().Y
        if initialHeight <= 0 then
            model:Destroy()
            cancel()
            return
        end
        local normalizedScale = model:GetScale() * 2 / initialHeight
        for _, descendant in model:GetDescendants() do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
            elseif descendant:IsA("Script") or descendant:IsA("LocalScript")
                or descendant:IsA("ProximityPrompt") or descendant:IsA("Sound") then
                descendant:Destroy()
            end
        end

        world = Instance.new("WorldModel")
        world.Name = "HatchCrabWorld"
        world.Parent = viewport
        model.Parent = world
        local currentCamera = Instance.new("Camera")
        currentCamera.FieldOfView = 35
        currentCamera.Parent = viewport
        camera = currentCamera
        viewport.CurrentCamera = currentCamera

        local finalWeight = CrabWeights.normalize(weightGrams)
        local finalIncome = CrabWeights.income(definition.incomePerSecond, finalWeight)
        local finalScale = normalizedScale * CrabWeights.scale(finalWeight)
        model:ScaleTo(finalScale)
        local _, finalSize = model:GetBoundingBox()
        local referenceRatio = CrabWeights.scale(CAMERA_REFERENCE_WEIGHT_GRAMS) / CrabWeights.scale(finalWeight)
        local heavyCrabPadding = math.max(MIN_CAMERA_PADDING, 1.35 - 0.1 * math.log(finalWeight / 10) / math.log(10))
        local framingFactor = math.max(referenceRatio, heavyCrabPadding / CAMERA_PADDING)
        local framingSize = finalSize * framingFactor
        model:ScaleTo(finalScale * START_VISUAL_SCALE)

        crabName(definition.name)
        gramText("0.00g")
        incomeText("0/s")
        revealVisible(true)
        visible(true)
        countSound.TimePosition = 0
        countSound:Play()

        local steadyRotationRate = 2 * math.pi / CRAB_ROTATION_SECONDS
        local startingRotationRate = steadyRotationRate * STARTING_ROTATION_MULTIPLIER
        local thisRun = runNumber
        local elapsed = 0
        local revealComplete = false
        connection = RunService.RenderStepped:Connect(function(dt)
            if thisRun ~= runNumber then
                return
            end
            elapsed += dt
            local angle = -(steadyRotationRate * elapsed
                + (startingRotationRate - steadyRotationRate) * SPIN_DECAY_SECONDS
                    * (1 - math.exp(-elapsed / SPIN_DECAY_SECONDS)))
            local growProgress = math.clamp(elapsed / REVEAL_SECONDS, 0, 1)
            local growth = 1 - (1 - growProgress) ^ 3
            if not revealComplete then
                local displayedWeight = finalWeight * growth
                gramText(string.format("%.2fg", displayedWeight))
                local visualScale = START_VISUAL_SCALE + (1 - START_VISUAL_SCALE) * growth
                model:ScaleTo(finalScale * visualScale)
                local animatedIncome = finalIncome * growth
                incomeText(CompactNumber.format(animatedIncome, 2) .. "/s")
                local box = model:GetBoundingBox()
                model:PivotTo(CFrame.new(-box.Position) * model:GetPivot())
            end
            burstImage.Rotation = (-elapsed / BURST_ROTATION_SECONDS * 360) % 360
            local viewportSize = viewport.AbsoluteSize
            local aspectRatio = if viewportSize.Y > 0 then math.max(0.1, viewportSize.X / viewportSize.Y) else 1
            local horizontalSpan = math.sqrt(framingSize.X ^ 2 + framingSize.Z ^ 2)
            local fitSize = math.max(framingSize.Y, horizontalSpan / aspectRatio)
            local cameraDistance = math.max(5, fitSize / (2 * math.tan(math.rad(currentCamera.FieldOfView / 2))) * CAMERA_PADDING)
            local cameraPosition = Vector3.new(math.sin(angle) * cameraDistance, framingSize.Y * 0.1, math.cos(angle) * cameraDistance)
            currentCamera.CFrame = CFrame.lookAt(cameraPosition, Vector3.zero)
            if elapsed >= DISMISS_READY_SECONDS and not readyToDismiss then
                readyToDismiss = true
                clickHintVisible(true)
            end
            if elapsed >= REVEAL_SECONDS and not revealComplete then
                countSound:Stop()
                gramText(string.format("%.2fg", finalWeight))
                incomeText(CompactNumber.format(finalIncome, 2) .. "/s")
                revealComplete = true
                completeSound.TimePosition = 0
                completeSound:Play()
            end
        end)
    end

    return function(crabId: string, weightGrams: number, eggId: string?, eggPivot: CFrame?, eggScale: number?, viewDirection: Vector3?, instanceId: string?)
        cancel()
        activeInstanceId = instanceId
        setPromptsLocked(true)
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local eggs = if assets then assets:FindFirstChild("Eggs") else nil
        local eggTemplate = if eggId and eggs then eggs:FindFirstChild(eggId) else nil
        local sceneCamera = Workspace.CurrentCamera
        if not eggTemplate or not eggTemplate:IsA("Model") or not eggPivot
            or not eggScale or eggScale <= 0 or not sceneCamera then
            startCrabReveal(crabId, weightGrams)
            return
        end

        local preview = eggTemplate:Clone()
        for _, descendant in preview:GetDescendants() do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
            elseif descendant:IsA("Script") or descendant:IsA("LocalScript")
                or descendant:IsA("ProximityPrompt") or descendant:IsA("Sound") then
                descendant:Destroy()
            end
        end
        preview.Name = "HatchPreviewEgg"
        preview:ScaleTo(eggScale)
        preview:PivotTo(eggPivot)
        preview.Parent = Workspace
        introEgg = preview

        local boxCFrame = preview:GetBoundingBox()
        local eggCenter = boxCFrame.Position
        local padSide = if viewDirection and viewDirection.Magnitude > 0.01 then viewDirection else eggPivot.LookVector
        local horizontal = Vector3.new(padSide.X, 0, padSide.Z)
        if horizontal.Magnitude < 0.01 then
            horizontal = Vector3.new(0, 0, -1)
        end
        local startPosition = eggCenter + horizontal.Unit * 8 + Vector3.new(0, 2.5, 0)
        local closePosition = eggCenter + horizontal.Unit * 3.8 + Vector3.new(0, 0.8, 0)
        local startCFrame = CFrame.lookAt(startPosition, eggCenter)
        local closeCFrame = CFrame.lookAt(closePosition, eggCenter)
        introCamera = sceneCamera
        previousCameraType = sceneCamera.CameraType
        previousCameraCFrame = sceneCamera.CFrame
        previousFieldOfView = sceneCamera.FieldOfView
        sceneCamera.CameraType = Enum.CameraType.Scriptable
        sceneCamera.CFrame = startCFrame

        flashTransparency(1)
        flashVisible(true)
        visible(true)
        local thisRun = runNumber
        local elapsed = 0
        local startedReveal = false
        local startedShakeSound = false
        local startedRevealSound = false
        local shakeEnd = EGG_ZOOM_SECONDS + EGG_SHAKE_SECONDS
        local flashPeak = shakeEnd + FLASH_IN_SECONDS
        local fadeStart = flashPeak + FLASH_HOLD_SECONDS
        local finishTime = fadeStart + FLASH_OUT_SECONDS

        introConnection = RunService.RenderStepped:Connect(function(dt)
            if thisRun ~= runNumber then
                return
            end
            elapsed += dt
            if not startedShakeSound and elapsed >= SHAKE_SOUND_DELAY_SECONDS and elapsed < shakeEnd then
                startedShakeSound = true
                shakeSound.TimePosition = 0
                shakeSound:Play()
            end
            if elapsed < EGG_ZOOM_SECONDS then
                local fraction = math.clamp(elapsed / EGG_ZOOM_SECONDS, 0, 1)
                local eased = (2 ^ (5 * fraction) - 1) / 31
                sceneCamera.CFrame = startCFrame:Lerp(closeCFrame, eased)
            elseif elapsed < flashPeak then
                sceneCamera.CFrame = closeCFrame
            end
            if elapsed < shakeEnd then
                local tilt: number
                if elapsed < EGG_ZOOM_SECONDS then
                    local beatDuration = EGG_ZOOM_SECONDS / 2
                    local beatIndex = math.floor(elapsed / beatDuration)
                    local beatProgress = (elapsed % beatDuration) / beatDuration
                    local activeProgress = math.clamp(beatProgress / 0.7, 0, 1)
                    local direction = if beatIndex == 0 then -1 else 1
                    tilt = direction * math.rad(7) * math.sin(math.pi * activeProgress)
                else
                    local progress = math.clamp((elapsed - EGG_ZOOM_SECONDS) / EGG_SHAKE_SECONDS, 0, 1)
                    local cycles = 8 * (4 ^ progress - 1) / 3
                    tilt = math.rad(5 + 11 * progress) * math.sin(2 * math.pi * cycles)
                end
                preview:PivotTo(
                    CFrame.new(eggPivot.Position)
                    * CFrame.fromAxisAngle(closeCFrame.LookVector, tilt)
                    * eggPivot.Rotation
                )
            end

            if elapsed >= shakeEnd and not startedReveal then
                shakeSound:Stop()
                if not startedRevealSound then
                    startedRevealSound = true
                    revealSound.TimePosition = 0
                    revealSound:Play()
                    task.delay(REVEAL_SOUND_SECONDS, function()
                        if thisRun == runNumber then
                            revealSound:Stop()
                        end
                    end)
                end
                preview:PivotTo(eggPivot)
                flashTransparency(1 - math.clamp((elapsed - shakeEnd) / FLASH_IN_SECONDS, 0, 1))
            end
            if elapsed >= flashPeak and not startedReveal then
                startedReveal = true
                flashTransparency(0)
                restoreIntro()
                startCrabReveal(crabId, weightGrams)
                if thisRun ~= runNumber then
                    return
                end
            end
            if startedReveal and elapsed >= fadeStart then
                flashTransparency(math.clamp((elapsed - fadeStart) / FLASH_OUT_SECONDS, 0, 1))
            end
            if elapsed >= finishTime then
                flashVisible(false)
                if introConnection then
                    introConnection:Disconnect()
                    introConnection = nil
                end
            end
        end)
    end
end

return HatchReveal
