-- ดึง Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Services
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- ==========================================
-- CONFIGURATION
-- ==========================================
local ITEM_NAME = "ที่ฉาบปูน"
local BUY_LOCATION = Vector3.new(422.701996, 25, -225.712997)
local RECENT_COOLDOWN = 3.5

-- 📦 ตั้งค่าระบบส่งพัสดุ
local deliveryActive = false
local PICKUP_LOCATION = Vector3.new(-298.8047790527344, 23.38964080810547, 36.00278854370117)
local DROP_LOCATION = Vector3.new(-621.3425903320312, 22.04998779296875, -280.3482666015625)
local PACKAGE_NAME = "CardBoardBox"

-- 🗑️ พิกัด MeshPart ที่ต้องการลบ
local TARGET_DELETE_POS = Vector3.new(-491.0236511230469, 24.406709671020508, -63.4103889465332)

-- Global Variables
local autoFarmActive = false
local espActive = false
local recentlyFarmed = {}
local cameraConnection = nil
local espConnections = {}
local renderConnections = {}

-- Aimbot Variables
local aimbotEnabled = false
local aimbotTargetPart = "Head"
local aimbotFovRadius = 200
local showFovCircle = true
local aimbotSmoothness = 0.5
local predictMovement = true

-- Aimbot State
local isRightClickHolding = false
local isMobileLocked = false
local mobileLockedTarget = nil

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.Color = Color3.fromRGB(120, 220, 235)
fovCircle.Filled = false
fovCircle.Transparency = 0.6
fovCircle.Visible = false

-- ==========================================
-- 1. Helper Function
-- ==========================================
local function isCharacterAlive(char)
    if not char or not char.Parent then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

-- 🗑️ ฟังก์ชันลบ MeshPart ในพิกัดที่กำหนด
local function deleteTargetMeshPart()
    local deletedCount = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("MeshPart") then
            local dist = (obj.Position - TARGET_DELETE_POS).Magnitude
            if dist <= 3.5 then -- ตรวจจับในรัศมีคลาดเคลื่อนไม่เกิน 3.5 Studs
                obj:Destroy()
                deletedCount = deletedCount + 1
            end
        end
    end
    if deletedCount > 0 then
        Fluent:Notify({Title = "Hi Hub", Content = "ทำการลบ MeshPart ตรงพิกัดเป้าหมายแล้ว (" .. deletedCount .. " ชิ้น)", Duration = 3})
    end
end

player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local function cleanupOnDeath()
    isMobileLocked = false
    mobileLockedTarget = nil
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
end

player.CharacterAdded:Connect(function(char)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if humanoid then humanoid.Died:Connect(cleanupOnDeath) end
end)

if player.Character and player.Character:FindFirstChild("Humanoid") then
    player.Character.Humanoid.Died:Connect(cleanupOnDeath)
end

-- ==========================================
-- 2. GUI Container
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HiHubCleanGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local MobileAimBtn = Instance.new("TextButton")
MobileAimBtn.Name = "AimButton"
MobileAimBtn.Size = UDim2.new(0, 65, 0, 65)
MobileAimBtn.Position = UDim2.new(0.8, 0, 0.4, 0)
MobileAimBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
MobileAimBtn.BackgroundTransparency = 0.15
MobileAimBtn.Text = "🎯 LOCK"
MobileAimBtn.TextColor3 = Color3.fromRGB(150, 220, 240)
MobileAimBtn.TextSize = 13
MobileAimBtn.Font = Enum.Font.GothamBold
MobileAimBtn.Visible = false
MobileAimBtn.Parent = ScreenGui

local UICornerAim = Instance.new("UICorner")
UICornerAim.CornerRadius = UDim.new(1, 0)
UICornerAim.Parent = MobileAimBtn

local UIStrokeAim = Instance.new("UIStroke")
UIStrokeAim.Color = Color3.fromRGB(100, 180, 210)
UIStrokeAim.Thickness = 1.5
UIStrokeAim.Transparency = 0.3
UIStrokeAim.Parent = MobileAimBtn

local ToggleMenuBtn = Instance.new("TextButton")
ToggleMenuBtn.Name = "ToggleMenuButton"
ToggleMenuBtn.Size = UDim2.new(0, 95, 0, 36)
ToggleMenuBtn.Position = UDim2.new(0.02, 0, 0.15, 0)
ToggleMenuBtn.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
ToggleMenuBtn.BackgroundTransparency = 0.1
ToggleMenuBtn.Text = "✨ Hi Hub"
ToggleMenuBtn.TextColor3 = Color3.fromRGB(200, 230, 245)
ToggleMenuBtn.TextSize = 13
ToggleMenuBtn.Font = Enum.Font.GothamBold
ToggleMenuBtn.Parent = ScreenGui

local UICornerMenu = Instance.new("UICorner")
UICornerMenu.CornerRadius = UDim.new(0, 10)
UICornerMenu.Parent = ToggleMenuBtn

local UIStrokeMenu = Instance.new("UIStroke")
UIStrokeMenu.Color = Color3.fromRGB(70, 85, 105)
UIStrokeMenu.Thickness = 1.2
UIStrokeMenu.Transparency = 0.2
UIStrokeMenu.Parent = ToggleMenuBtn

-- Dragging System
local draggingAim, draggingMenu = false, false
local dragStartAim, startPosAim
local dragStartMenu, startPosMenu
local hasDragged = false

MobileAimBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingAim = true; hasDragged = false; dragStartAim = input.Position; startPosAim = MobileAimBtn.Position
    end
end)
MobileAimBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then draggingAim = false end
end)
ToggleMenuBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingMenu = true; dragStartMenu = input.Position; startPosMenu = ToggleMenuBtn.Position
    end
end)
ToggleMenuBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then draggingMenu = false end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingAim and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStartAim
        if delta.Magnitude > 5 then hasDragged = true end
        MobileAimBtn.Position = UDim2.new(startPosAim.X.Scale, startPosAim.X.Offset + delta.X, startPosAim.Y.Scale, startPosAim.Y.Offset + delta.Y)
    elseif draggingMenu and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStartMenu
        ToggleMenuBtn.Position = UDim2.new(startPosMenu.X.Scale, startPosMenu.X.Offset + delta.X, startPosMenu.Y.Scale, startPosMenu.Y.Offset + delta.Y)
    end
end)

-- ==========================================
-- 3. MoveTo + Hold Shift System
-- ==========================================
local function faceTarget(targetPosition)
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local rootPart = character.HumanoidRootPart
        local lookAtPos = Vector3.new(targetPosition.X, rootPart.Position.Y, targetPosition.Z)
        rootPart.CFrame = CFrame.new(rootPart.Position, lookAtPos)
    end
end

local function pressEKey()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.35)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function interactPrompt(target)
    if not target then pressEKey() return end
    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and fireproximityprompt then
        fireproximityprompt(prompt)
    else
        pressEKey()
    end
end

local function walkToWithPathfinding(targetPosition, activeFlagCheck)
    local character = player.Character
    if not isCharacterAlive(character) then return false end

    local humanoid = character.Humanoid
    local rootPart = character.HumanoidRootPart

    local path = PathfindingService:CreatePath({
        AgentRadius = 3.5,
        AgentHeight = 6.0,
        AgentCanJump = true,
        WaypointSpacing = 4.0
    })

    local success = pcall(function() path:ComputeAsync(rootPart.Position, targetPosition) end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()

        -- 🔥 ใช้ MoveTowards สำหรับการเดินทางโดยตรง
        local moveConnection = nil
        local function startMoving(direction)
            if moveConnection then moveConnection:Disconnect() end
            moveConnection = RunService.Heartbeat:Connect(function()
                if humanoid and isCharacterAlive(character) then
                    humanoid:Move(direction, false)
                end
            end)
        end

        local stopSprint = function()
            if moveConnection then
                moveConnection:Disconnect()
                moveConnection = nil
            end
            if humanoid then humanoid:Move(Vector3.new(0, 0, 0), false) end
        end

        for _, waypoint in ipairs(waypoints) do
            if not activeFlagCheck() or not isCharacterAlive(character) then 
                stopSprint()
                return false 
            end

            if waypoint.Action == Enum.PathWaypointAction.Jump then 
                humanoid.Jump = true 
            end

            local directionToWaypoint = (waypoint.Position - rootPart.Position).Unit
            startMoving(directionToWaypoint)
            humanoid:MoveTo(waypoint.Position)
            local lastPos = rootPart.Position
            local stuckTimer = 0
            local reached = false

            local connection = humanoid.MoveToFinished:Connect(function() reached = true end)
            local startTime = tick()

            while not reached and activeFlagCheck() and isCharacterAlive(character) do
                task.wait(0.05)
                if not rootPart then break end

                if (rootPart.Position - targetPosition).Magnitude <= 4.5 then
                    if connection.Connected then connection:Disconnect() end
                    stopSprint()
                    return true
                end

                if (rootPart.Position - lastPos).Magnitude < 0.15 then
                    stuckTimer = stuckTimer + 0.05
                else
                    stuckTimer = 0
                    lastPos = rootPart.Position
                end

                if stuckTimer > 0.6 then
                    humanoid.Jump = true
                    stuckTimer = 0
                end

                if tick() - startTime > 3.5 then
                    if connection.Connected then connection:Disconnect() end
                    break
                end
            end

            if connection.Connected then connection:Disconnect() end
            if rootPart and (rootPart.Position - targetPosition).Magnitude <= 4.5 then 
                stopSprint()
                return true 
            end
        end

        stopSprint()
    end

    return rootPart and (rootPart.Position - targetPosition).Magnitude <= 4.5
end

-- ==========================================
-- 4. ระบบฟาร์มพัสดุ (Infinite Loop Delivery)
-- ==========================================
local function getPackageTool()
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and (item.Name == PACKAGE_NAME or item.Name:find(PACKAGE_NAME)) then
                return item
            end
        end
    end
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name == PACKAGE_NAME or item.Name:find(PACKAGE_NAME)) then
                return item
            end
        end
    end
    return nil
end

local function equipPackage()
    local tool = getPackageTool()
    local character = player.Character
    if tool and character then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if humanoid and tool.Parent ~= character then
            humanoid:EquipTool(tool)
            task.wait(0.15)
        end
        return true
    end
    return false
end

local function startDeliveryJob()
    deleteTargetMeshPart() -- ลบ MeshPart ตรงพิกัดเป้าหมายเมื่อเปิดใช้งาน

    while deliveryActive do
        if not isCharacterAlive(player.Character) then
            task.wait(1)
            continue
        end

        local currentPackage = getPackageTool()

        if currentPackage then
            equipPackage()
            
            local reachedDrop = walkToWithPathfinding(DROP_LOCATION, function() return deliveryActive end)
            if reachedDrop and deliveryActive then
                faceTarget(DROP_LOCATION)
                task.wait(0.15)
                pressEKey()
                task.wait(0.8)
            end
        else
            local reachedPickUp = walkToWithPathfinding(PICKUP_LOCATION, function() return deliveryActive end)
            if reachedPickUp and deliveryActive then
                faceTarget(PICKUP_LOCATION)
                task.wait(0.15)
                pressEKey()
                task.wait(0.8)

                equipPackage()

                local reachedDrop = walkToWithPathfinding(DROP_LOCATION, function() return deliveryActive end)
                if reachedDrop and deliveryActive then
                    faceTarget(DROP_LOCATION)
                    task.wait(0.15)
                    pressEKey()
                    task.wait(0.8)
                end
            end
        end

        task.wait(0.1)
    end
end

-- ==========================================
-- 5. Aimbot System & ESP System
-- ==========================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then isRightClickHolding = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then isRightClickHolding = false end
end)

local function getClosestTargetInFOV()
    local closestTarget = nil
    local shortestDist = aimbotFovRadius
    local centerPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and isCharacterAlive(targetPlayer.Character) then
            local char = targetPlayer.Character
            local targetPart = char:FindFirstChild(aimbotTargetPart)

            if targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - centerPos).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closestTarget = targetPart
                    end
                end
            end
        end
    end
    return closestTarget
end

local function resetMobileAimBtn()
    isMobileLocked = false
    mobileLockedTarget = nil
    MobileAimBtn.Text = "🎯 LOCK"
    MobileAimBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
    MobileAimBtn.TextColor3 = Color3.fromRGB(150, 220, 240)
    UIStrokeAim.Color = Color3.fromRGB(100, 180, 210)
end

MobileAimBtn.MouseButton1Click:Connect(function()
    if not hasDragged then
        if isMobileLocked then
            resetMobileAimBtn()
        else
            local target = getClosestTargetInFOV()
            if target then
                isMobileLocked = true; mobileLockedTarget = target
                MobileAimBtn.Text = "🔒 LOCKED"
                MobileAimBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
                MobileAimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                UIStrokeAim.Color = Color3.fromRGB(255, 100, 100)
            else
                Fluent:Notify({Title = "Hi Hub", Content = "ไม่พบเป้าหมาย", Duration = 1.5})
            end
        end
    end
end)

local function onAimbotRenderStep(dt)
    if not aimbotEnabled or not isCharacterAlive(player.Character) then return end
    local finalTargetPart = nil

    if isRightClickHolding then
        finalTargetPart = getClosestTargetInFOV()
    elseif isMobileLocked and mobileLockedTarget then
        if isCharacterAlive(mobileLockedTarget.Parent) and mobileLockedTarget:IsDescendantOf(Workspace) then
            finalTargetPart = mobileLockedTarget
        else
            resetMobileAimBtn()
        end
    end

    if finalTargetPart then
        pcall(function()
            local targetPos = finalTargetPart.Position
            if predictMovement and finalTargetPart.AssemblyLinearVelocity then
                local velocity = finalTargetPart.AssemblyLinearVelocity
                local distance = (camera.CFrame.Position - targetPos).Magnitude
                targetPos = targetPos + (velocity * (distance / 1000))
            end
            local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPos)
            local lerpAlpha = math.clamp(aimbotSmoothness * dt * 60, 0.1, 1)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, lerpAlpha)
        end)
    end
end

RunService:UnbindFromRenderStep("AntiShakeAimbotProcess")
RunService:BindToRenderStep("AntiShakeAimbotProcess", Enum.RenderPriority.Camera.Value + 1, onAimbotRenderStep)

renderConnections["FOVLoop"] = RunService.RenderStepped:Connect(function()
    local viewportSize = camera.ViewportSize
    fovCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    fovCircle.Radius = aimbotFovRadius
    fovCircle.Visible = aimbotEnabled and showFovCircle
    MobileAimBtn.Visible = aimbotEnabled
end)

-- ESP
local function removeESP(targetPlayer)
    if not targetPlayer.Character then return end
    local highlight = targetPlayer.Character:FindFirstChild("ESPHighlight")
    if highlight then highlight:Destroy() end
    local head = targetPlayer.Character:FindFirstChild("Head")
    if head then
        local gui = head:FindFirstChild("ESPNameGui")
        if gui then gui:Destroy() end
    end
end

local function applyESP(targetPlayer)
    if targetPlayer == player then return end

    local function setupCharacter(char)
        if not char then return end
        local head = char:WaitForChild("Head", 5)
        local humanoid = char:WaitForChild("Humanoid", 5)
        if not head or not humanoid then return end

        removeESP(targetPlayer)
        if not espActive then return end

        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.FillColor = Color3.fromRGB(100, 180, 210)
        highlight.FillTransparency = 0.6
        highlight.OutlineColor = Color3.fromRGB(240, 245, 250)
        highlight.OutlineTransparency = 0.2
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = char
        highlight.Parent = char

        local bgui = Instance.new("BillboardGui")
        bgui.Name = "ESPNameGui"
        bgui.Adornee = head
        bgui.Size = UDim2.new(0, 200, 0, 50)
        bgui.StudsOffset = Vector3.new(0, 3, 0)
        bgui.AlwaysOnTop = true

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(235, 242, 250)
        textLabel.TextStrokeTransparency = 0.2
        textLabel.TextStrokeColor3 = Color3.fromRGB(20, 20, 25)
        textLabel.Font = Enum.Font.GothamMedium
        textLabel.TextSize = 13
        textLabel.Text = targetPlayer.Name
        textLabel.Parent = bgui
        bgui.Parent = head

        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not espActive or not isCharacterAlive(char) or not head:IsDescendantOf(Workspace) then
                if bgui then bgui:Destroy() end
                if highlight then highlight:Destroy() end
                if connection then connection:Disconnect() end
                return
            end

            local myChar = player.Character
            if isCharacterAlive(myChar) then
                local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                local targetRoot = char:FindFirstChild("HumanoidRootPart")
                if myRoot and targetRoot then
                    local dist = math.floor((myRoot.Position - targetRoot.Position).Magnitude)
                    textLabel.Text = string.format("%s | [%d m]", targetPlayer.Name, dist)
                else
                    textLabel.Text = targetPlayer.Name
                end
            end
        end)
    end

    if targetPlayer.Character then setupCharacter(targetPlayer.Character) end
    espConnections[targetPlayer.Name.."_Added"] = targetPlayer.CharacterAdded:Connect(setupCharacter)
    espConnections[targetPlayer.Name.."_Removing"] = targetPlayer.CharacterRemoving:Connect(function() removeESP(targetPlayer) end)
end

local function toggleESP(state)
    espActive = state
    if state then
        for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
        espConnections["PlayerAdded"] = Players.PlayerAdded:Connect(function(p) applyESP(p) end)
    else
        for key, conn in pairs(espConnections) do
            if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
        end
        espConnections = {}
        for _, p in ipairs(Players:GetPlayers()) do removeESP(p) end
    end
end

-- ==========================================
-- 6. Auto Farm (ฉาบปูน) - Rayfield Version
-- ==========================================
local function setHighAngleCamera(enabled)
    if enabled then
        camera.CameraType = Enum.CameraType.Scriptable
        
        if cameraConnection then cameraConnection:Disconnect() end
        
        cameraConnection = RunService.RenderStepped:Connect(function()
            if autoFarmActive and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local rootPos = player.Character.HumanoidRootPart.Position
                local cameraOffset = Vector3.new(0, 15, 10)
                camera.CFrame = CFrame.new(rootPos + cameraOffset, rootPos)
            end
        end)
    else
        if cameraConnection then
            cameraConnection:Disconnect()
            cameraConnection = nil
        end
        camera.CameraType = Enum.CameraType.Custom
    end
end

local function setSprinting(enabled)
    VirtualInputManager:SendKeyEvent(enabled, Enum.KeyCode.LeftShift, false, game)
end

local function getToolItem()
    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")
    
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and (item.Name == ITEM_NAME or item.Name:find(ITEM_NAME)) then
                return item
            end
        end
    end
    
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name == ITEM_NAME or item.Name:find(ITEM_NAME)) then
                return item
            end
        end
    end
    
    return nil
end

local function equipItem()
    local tool = getToolItem()
    local character = player.Character
    
    if tool and character then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if humanoid and tool.Parent ~= character then
            humanoid:EquipTool(tool)
            task.wait(0.2)
        end
        return true
    end
    return false
end

local function getDetourPosition(startPos, targetPos, detourDistance)
    detourDistance = detourDistance or math.random(8, 15)
    
    local midPoint = (startPos + targetPos) / 2
    local randomDirection = math.random(1, 2) == 1 and 1 or -1
    
    local directionVector = (targetPos - startPos).Unit
    local perpendicularVector = Vector3.new(-directionVector.Z, 0, directionVector.X) * randomDirection
    
    return midPoint + (perpendicularVector * detourDistance)
end

local function walkToWithPathfindingSimple(targetPosition)
    local character = player.Character
    if not character or not character:FindFirstChild("Humanoid") or not character:FindFirstChild("HumanoidRootPart") then 
        return false 
    end

    local humanoid = character.Humanoid
    local rootPart = character.HumanoidRootPart

    setSprinting(true)

    local path = PathfindingService:CreatePath({
        AgentRadius = 4,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 5
    })

    local success, _ = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPosition)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()

        for _, waypoint in ipairs(waypoints) do
            if not autoFarmActive then 
                setSprinting(false)
                return false 
            end

            setSprinting(true)

            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end

            humanoid:MoveTo(waypoint.Position)

            local reached = false
            local connection
            connection = humanoid.MoveToFinished:Connect(function()
                reached = true
            end)

            local timeout = 0
            while not reached and timeout < 2 do
                if not autoFarmActive then 
                    connection:Disconnect()
                    setSprinting(false)
                    return false 
                end
                task.wait(0.1)
                timeout = timeout + 0.1
            end
            connection:Disconnect()

            if (rootPart.Position - targetPosition).Magnitude <= 6 then
                return true
            end
        end
    else
        setSprinting(true)
        humanoid:MoveTo(targetPosition)
        task.wait(1)
    end

    return (rootPart.Position - targetPosition).Magnitude <= 6
end

local function goBuyItem()
    Fluent:Notify({Title = "Auto Buy", Content = "ไม่พบ '" .. ITEM_NAME .. "' กำลังวิ่งไปซื้อ...", Duration = 3})
    
    local reached = walkToWithPathfindingSimple(BUY_LOCATION)
    
    if reached and autoFarmActive then
        faceTarget(BUY_LOCATION)
        task.wait(0.2)
        pressEKey()
        task.wait(1.5)
        
        if getToolItem() then
            Fluent:Notify({Title = "Auto Buy Complete", Content = "ซื้อเรียบร้อย! พร้อมฟาร์มต่อ", Duration = 3})
            return true
        end
    end
    return false
end

local function startAutoFarm()
    setHighAngleCamera(true)

    while autoFarmActive do
        setSprinting(true)

        if not getToolItem() then
            local bought = goBuyItem()
            if not bought then
                task.wait(2)
                continue
            end
        end

        equipItem()

        local foundTarget = false
        local currentTime = tick()
        
        for item, lastTime in pairs(recentlyFarmed) do
            if currentTime - lastTime >= 6 then
                recentlyFarmed[item] = nil
            end
        end

        for _, item in ipairs(Workspace:GetDescendants()) do
            if not autoFarmActive then break end
            
            if item.Name == "brickFarm" then
                if recentlyFarmed[item] then
                    continue
                end

                local onCooldown = item:GetAttribute("OnCooldown")
                
                if onCooldown == false or onCooldown == nil then
                    local targetPos = nil
                    if item:IsA("Model") and item.PrimaryPart then
                        targetPos = item.PrimaryPart.Position
                    elseif item:IsA("BasePart") then
                        targetPos = item.Position
                    elseif item:FindFirstChildWhichIsA("BasePart") then
                        targetPos = item:FindFirstChildWhichIsA("BasePart").Position
                    end
                    
                    if targetPos then
                        foundTarget = true
                        equipItem()
                        
                        local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            local currentPos = rootPart.Position
                            local distance = (currentPos - targetPos).Magnitude
                            
                            if distance > 18 then
                                local detourPos = getDetourPosition(currentPos, targetPos, math.random(8, 14))
                                walkToWithPathfindingSimple(detourPos)
                                task.wait(math.random(1, 3) / 10)
                            end
                        end
                        
                        local reached = walkToWithPathfindingSimple(targetPos)
                        
                        if reached and autoFarmActive then
                            faceTarget(targetPos)
                            task.wait(0.1)
                            
                            local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt and fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                pressEKey()
                            end
                            
                            recentlyFarmed[item] = tick()
                            
                            task.wait(0.4)
                            break
                        end
                    end
                end
            end
        end
        
        if not foundTarget then
            task.wait(0.8)
        end
        
        task.wait(0.05)
    end
    
    setSprinting(false)
    setHighAngleCamera(false)
end

-- ==========================================
-- 7. UI Window Main
-- ==========================================
local Window = Fluent:CreateWindow({
    Title = "Hi Hub",
    SubTitle = "Delete Target MeshPart Added",
    TabWidth = 150,
    Size = UDim2.fromOffset(560, 400),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

ToggleMenuBtn.MouseButton1Click:Connect(function() Window:Minimize() end)

local Tabs = {
    Main = Window:AddTab({ Title = "Auto Jobs", Icon = "rbxassetid://10734950309" }),
    Aimbot = Window:AddTab({ Title = "Aimbot Lock", Icon = "rbxassetid://10734952042" }),
    Visuals = Window:AddTab({ Title = "Visuals (ESP)", Icon = "rbxassetid://10723423881" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "rbxassetid://10734950020" })
}

-- แท็บงาน Auto Jobs
Tabs.Main:AddSection("ระบบฟาร์มงานส่งพัสดุ (CardBoardBox)")
local DeliveryToggle = Tabs.Main:AddToggle("DeliveryToggle", { Title = "เริ่มงานส่งพัสดุอัตโนมัติ (วนลูป)", Default = false })
DeliveryToggle:OnChanged(function(Value)
    deliveryActive = Value
    if deliveryActive then
        autoFarmActive = false
        task.spawn(startDeliveryJob)
    end
end)

Tabs.Main:AddSection("ระบบฟาร์มงานฉาบปูน")
local FarmToggle = Tabs.Main:AddToggle("AutoFarmToggle", { Title = "เริ่มฟาร์มงานฉาบปูน", Default = false })
FarmToggle:OnChanged(function(Value)
    autoFarmActive = Value
    if autoFarmActive then
        deliveryActive = false
        recentlyFarmed = {}
        task.spawn(startAutoFarm)
    else
        setSprinting(false)
        setHighAngleCamera(false)
    end
end)

-- แท็บ Aimbot
Tabs.Aimbot:AddSection("ตั้งค่า Aimbot")
local AimToggle = Tabs.Aimbot:AddToggle("AimToggle", { Title = "เปิดใช้งาน Aimbot", Default = false })
AimToggle:OnChanged(function(Value) aimbotEnabled = Value end)

local PredictToggle = Tabs.Aimbot:AddToggle("PredictToggle", { Title = "ระบบคำนวณยิงดักหน้า", Default = true })
PredictToggle:OnChanged(function(Value) predictMovement = Value end)

local PartDropdown = Tabs.Aimbot:AddDropdown("PartDropdown", { Title = "จุดล็อกเป้าหมาย", Values = {"Head (หัว)", "HumanoidRootPart (ลำตัว)"}, Default = "Head (หัว)" })
PartDropdown:OnChanged(function(Value) aimbotTargetPart = Value == "Head (หัว)" and "Head" or "HumanoidRootPart" end)

local FovCircleToggle = Tabs.Aimbot:AddToggle("FovCircleToggle", { Title = "แสดงวงกลม FOV", Default = true })
FovCircleToggle:OnChanged(function(Value) showFovCircle = Value end)

local FovSlider = Tabs.Aimbot:AddSlider("FovSlider", { Title = "ขนาด FOV", Min = 50, Max = 500, Default = 200, Rounding = 0 })
FovSlider:OnChanged(function(Value) aimbotFovRadius = Value end)

local SmoothSlider = Tabs.Aimbot:AddSlider("SmoothSlider", { Title = "ความเร็วในการหมุน", Min = 0.1, Max = 1, Default = 0.5, Rounding = 2 })
SmoothSlider:OnChanged(function(Value) aimbotSmoothness = Value end)

-- แท็บ Visuals
Tabs.Visuals:AddSection("ระบบมองทะลุ")
local EspToggle = Tabs.Visuals:AddToggle("EspToggle", { Title = "เปิด ESP ผู้เล่น", Default = false })
EspToggle:OnChanged(function(Value) toggleESP(Value) end)

-- แท็บ Settings
Tabs.Settings:AddSection("จัดระบบ UI")
local ThemeDropdown = Tabs.Settings:AddDropdown("ThemeDropdown", { Title = "เปลี่ยนโทนสี UI", Values = {"Dark", "Aqua", "Amethyst", "Light"}, Default = "Dark" })
ThemeDropdown:OnChanged(function(Value) Fluent:SetTheme(Value) end)

Tabs.Settings:AddButton({
    Title = "ปิดสคริปต์และลบ UI ทั้งหมด",
    Callback = function()
        autoFarmActive = false; deliveryActive = false; toggleESP(false); fovCircle:Remove()
        RunService:UnbindFromRenderStep("AntiShakeAimbotProcess")
        for _, conn in pairs(renderConnections) do conn:Disconnect() end
        if ScreenGui then ScreenGui:Destroy() end
        Fluent:Destroy()
    end
})

-- โค้ดส่วนสำหรับการลบ MeshPart ตามพิกัดที่กำหนด

local targetPosition = Vector3.new(-491.0236511230469, 24.406709671020508, -63.4103889465332)
local tolerance = 1 -- ระยะความคลาดเคลื่อนที่อนุญาต (หน่วยเป็น Studs)

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("MeshPart") then
        if (obj.Position - targetPosition).Magnitude <= tolerance then
            obj:Destroy()
            print("ลบ MeshPart สำเร็จที่พิกัด:", obj.Position)
        end
    end
end

Window:SelectTab(1)
Fluent:Notify({Title = "Hi Hub Ready", Content = "เพิ่มระบบลบ MeshPart ในพิกัดเป้าหมายเรียบร้อยครับ!", Duration = 5})