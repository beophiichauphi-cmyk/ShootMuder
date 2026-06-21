-- [[ MM2 2026 V4 - HYPER SENSE & ANTI-ZIGZAG ACCURACY ]] --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local localplayer = Players.LocalPlayer

local shootOffset = 2.2 -- Tối ưu hóa tiêu chuẩn chống lách/giật cục
local isDragLocked = false 

-- =======================================================
-- [[ OPTIMIZATION: ẨN COIN GIẢM LAG ]] --
-- =======================================================
local function cleanCoins()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("TouchTransmitter") and (v.Parent.Name == "Coin" or v.Parent.Name == "CoinContainer" or v.Parent:FindFirstChild("Coin")) then
            v.Parent:Destroy()
        elseif v.Name == "Coin" or v.Name == "CupidCoin" or v.Name == "Snowflake" then
            v:Destroy()
        end
    end
end
task.spawn(function()
    while task.wait(3) do pcall(cleanCoins) end
end)

-- =======================================================
-- [[ THUẬT TOÁN CHỐNG LÁCH ZIG-ZAG & SPAM JUMP ]] --
-- =======================================================
local function findTarget(roleNeeded)
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localplayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hum = p.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local hrp = p.Character.HumanoidRootPart
                local dist = (hrp.Position - localplayer.Character.HumanoidRootPart.Position).Magnitude
                
                if roleNeeded == "Murderer" and (p.Character:FindFirstChild("Knife") or p.Backpack:FindFirstChild("Knife")) then
                    return p
                elseif roleNeeded == "Closest" and dist < shortestDistance then
                    shortestDistance = dist
                    closestPlayer = p
                end
            end
        end
    end
    return closestPlayer or findTarget("Closest")
end

local function getAntiZigZagPredictedPos(target, offset)
    if not target or not target.Character then return nil end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character:FindFirstChild("Humanoid")
    if not hrp or not hum then return nil end

    -- Lấy hướng di chuyển thực tế từ phím bấm/joystick của đối thủ thay vì vận tốc quán tính vật lý
    local moveDir = hum.MoveDirection
    local velocity = hrp.AssemblyLinearVelocity
    
    -- Nếu đối thủ đổi hướng liên tục (Lách), giảm bớt tầm bù quán tính để tránh đạn bay quá đà
    local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    if moveDir.Magnitude == 0 then
        flatVelocity = Vector3.new(0, 0, 0) -- Đứng yên hoặc lách đổi hướng đột ngột thì khóa chặt ngắm thẳng vào người
    end

    -- Khóa cứng trục đứng Y chống nhảy nhót lung tung
    local targetY = hrp.Position.Y
    if hum.FloorMaterial == Enum.Material.Air then
        targetY = hrp.Position.Y - 1 -- Ép tâm ngắm thấp xuống chân nếu đối phương nhảy cao
    end

    -- Thuật toán nội suy chặn đầu thông minh chống Zig-zag
    local predictedPos = hrp.Position + (flatVelocity * (offset / 18)) + (moveDir * offset)
    predictedPos = Vector3.new(predictedPos.X, targetY, predictedPos.Z)

    -- Đồng bộ Ping cực nhạy
    local ping = localplayer:GetNetworkPing() * 1000
    if ping > 0 then
        predictedPos = predictedPos + (flatVelocity * (ping / 1000))
    end
    
    return predictedPos
end

-- =======================================================
-- [[ THỰC THI SIÊU TỐC: INSTANT FORCE EQUIP & SHOOT ]] --
-- =======================================================
local function executeAction()
    local char = localplayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    -- BẮN SÚNG (SHERIFF / HERO)
    if char:FindFirstChild("Gun") or localplayer.Backpack:FindFirstChild("Gun") then
        local murderer = findTarget("Murderer")
        if not murderer then return end
        
        -- Ép súng ra tay tức thì bỏ qua delay hoạt ảnh
        local gun = char:FindFirstChild("Gun")
        if not gun then 
            local backpackGun = localplayer.Backpack:FindFirstChild("Gun")
            if backpackGun then
                backpackGun.Parent = char
                gun = backpackGun
            end
        end

        if gun and gun:FindFirstChild("Shoot") then
            local predictedPos = getAntiZigZagPredictedPos(murderer, shootOffset)
            local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("HumanoidRootPart")
            if predictedPos and rightHand then
                gun.Shoot:FireServer(CFrame.new(rightHand.Position), CFrame.new(predictedPos))
            end
        end

    -- NÉM DAO (MURDERER THROW)
    elseif char:FindFirstChild("Knife") or localplayer.Backpack:FindFirstChild("Knife") then
        local target = findTarget("Closest")
        if not target then return end
        
        -- Ép dao ra tay tức thì
        local knife = char:FindFirstChild("Knife")
        if not knife then
            local backpackKnife = localplayer.Backpack:FindFirstChild("Knife")
            if backpackKnife then
                backpackKnife.Parent = char
                knife = backpackKnife
            end
        end

        if knife then
            local throwRemote = knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeThrown")
            if throwRemote then
                local predictedPos = getAntiZigZagPredictedPos(target, shootOffset + 0.2)
                local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("HumanoidRootPart")
                if predictedPos and rightHand then
                    throwRemote:FireServer(CFrame.new(rightHand.Position), CFrame.new(predictedPos))
                end
            end
        end
    end
end

-- =======================================================
-- [[ GIAO DIỆN GUI VUÔNG MỜ 0.5 - VIỀN TRẮNG MỜ 0.5 ]] --
-- =======================================================
if CoreGui:FindFirstChild("CompactAimUI") then CoreGui.CompactAimUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CompactAimUI"
ScreenGui.Parent = CoreGui

-- Nút ngắm chính mờ 0.5
local MainButton = Instance.new("TextButton")
MainButton.Name = "MainButton"
MainButton.Parent = ScreenGui
MainButton.Size = UDim2.new(0, 65, 0, 65)
MainButton.Position = UDim2.new(0.5, -32, 0.4, 0)
MainButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainButton.BackgroundTransparency = 0.5
MainButton.Text = ""

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainButton

-- Viền màu trắng mờ 0.5 toàn diện
local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 2.5
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Transparency = 0.5
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UIStroke.Parent = MainButton

-- Crosshair súng (mờ 0.5)
local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Name = "Crosshair"
CrosshairFrame.Size = UDim2.new(1, 0, 1, 0)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Parent = MainButton

local function createLines()
    CrosshairFrame:ClearAllChildren()
    for i = 1, 4 do
        local line = Instance.new("Frame")
        line.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        line.BackgroundTransparency = 0.5 
        line.BorderSizePixel = 0
        line.Parent = CrosshairFrame
        if i == 1 then line.Size = UDim2.new(0, 2, 0, 12); line.Position = UDim2.new(0.5, -1, 0, 4)
        elseif i == 2 then line.Size = UDim2.new(0, 2, 0, 12); line.Position = UDim2.new(0.5, -1, 1, -16)
        elseif i == 3 then line.Size = UDim2.new(0, 12, 0, 2); line.Position = UDim2.new(0, 4, 0.5, -1)
        elseif i == 4 then line.Size = UDim2.new(0, 12, 0, 2); line.Position = UDim2.new(1, -16, 0.5, -1) end
    end
    local CenterDot = Instance.new("Frame")
    CenterDot.Size = UDim2.new(0, 4, 0, 4)
    CenterDot.Position = UDim2.new(0.5, -2, 0.5, -2)
    CenterDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    CenterDot.BackgroundTransparency = 0.5
    CenterDot.BorderSizePixel = 0
    CenterDot.Parent = CrosshairFrame
end
createLines()

-- Ảnh đại diện dao găm cho Murderer (mờ 0.5)
local KnifeIcon = Instance.new("ImageLabel")
KnifeIcon.Name = "KnifeIcon"
KnifeIcon.Size = UDim2.new(0.7, 0, 0.7, 0)
KnifeIcon.Position = UDim2.new(0.15, 0, 0.15, 0)
KnifeIcon.BackgroundTransparency = 1
KnifeIcon.ImageTransparency = 0.5 
KnifeIcon.Image = "rbxassetid://7137398850"
KnifeIcon.Visible = false
KnifeIcon.Parent = MainButton

task.spawn(function()
    local rot = 0
    while task.wait(0.02) do
        if CrosshairFrame.Visible then rot = (rot + 4) % 360 CrosshairFrame.Rotation = rot end
    end
end)

-- Nút mở bảng Cài đặt mờ 0.5
local SettingsButton = Instance.new("TextButton")
SettingsButton.Name = "SettingsButton"
SettingsButton.Parent = ScreenGui
SettingsButton.Size = UDim2.new(0, 25, 0, 25)
SettingsButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SettingsButton.BackgroundTransparency = 0.5
SettingsButton.Text = "⚙"
SettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SettingsButton.TextSize = 14

local SettCorner = Instance.new("UICorner")
SettCorner.CornerRadius = UDim.new(0, 6)
SettCorner.Parent = SettingsButton

local SettStroke = Instance.new("UIStroke")
SettStroke.Thickness = 1.5
SettStroke.Color = Color3.fromRGB(255, 255, 255)
SettStroke.Transparency = 0.5
SettStroke.Parent = SettingsButton

-- Bảng Panel cài đặt mờ 0.5
local SettPanel = Instance.new("Frame")
SettPanel.Name = "SettPanel"
SettPanel.Parent = ScreenGui
SettPanel.Size = UDim2.new(0, 150, 0, 100)
SettPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SettPanel.BackgroundTransparency = 0.5
SettPanel.Visible = false

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 8)
PanelCorner.Parent = SettPanel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Thickness = 1.5
PanelStroke.Color = Color3.fromRGB(255, 255, 255)
PanelStroke.Transparency = 0.5
PanelStroke.Parent = SettPanel

-- Nút khóa kéo thả mờ 0.5
local LockBtn = Instance.new("TextButton")
LockBtn.Size = UDim2.new(0, 130, 0, 30)
LockBtn.Position = UDim2.new(0, 10, 0, 10)
LockBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
LockBtn.BackgroundTransparency = 0.5
LockBtn.Text = "Lock Drag: OFF"
LockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LockBtn.Font = Enum.Font.SourceSansBold
LockBtn.Parent = SettPanel
Instance.new("UICorner", LockBtn).CornerRadius = UDim.new(0, 6)

LockBtn.MouseButton1Click:Connect(function()
    isDragLocked = not isDragLocked
    LockBtn.Text = isDragLocked and "Lock Drag: ON" or "Lock Drag: OFF"
    LockBtn.BackgroundColor3 = isDragLocked and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(180, 50, 50)
end)

-- Slider chỉnh Size mờ 0.5
local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(0, 130, 0, 20)
SliderLabel.Position = UDim2.new(0, 10, 0, 45)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = "Size GUI"
SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SliderLabel.TextTransparency = 0.5
SliderLabel.Font = Enum.Font.SourceSans
SliderLabel.Parent = SettPanel

local SliderBg = Instance.new("Frame")
SliderBg.Size = UDim2.new(0, 130, 0, 8)
SliderBg.Position = UDim2.new(0, 10, 0, 75)
SliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SliderBg.BackgroundTransparency = 0.5
SliderBg.Parent = SettPanel

local SliderMain = Instance.new("TextButton")
SliderMain.Size = UDim2.new(0, 15, 0, 15)
SliderMain.Position = UDim2.new(0.3, 0, -0.4, 0)
SliderMain.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderMain.BackgroundTransparency = 0.5
SliderMain.Text = ""
SliderMain.Parent = SliderBg
Instance.new("UICorner", SliderMain).CornerRadius = UDim.new(1, 0)

-- Kéo thả Slider thay đổi kích thước dễ dàng
local sliderDragging = false
SliderMain.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderDragging = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderDragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local relativeX = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
        SliderMain.Position = UDim2.new(relativeX, -7, -0.4, 0)
        
        local newSize = math.floor(45 + (relativeX * 65))
        MainButton.Size = UDim2.new(0, newSize, 0, newSize)
        createLines()
    end
end)

SettingsButton.MouseButton1Click:Connect(function()
    SettPanel.Visible = not SettPanel.Visible
end)

MainButton.MouseButton1Click:Connect(executeAction)

-- Theo dõi cập nhật trạng thái vũ khí liên tục
task.spawn(function()
    while task.wait(0.1) do
        local char = localplayer.Character
        if char then
            if char:FindFirstChild("Knife") or localplayer.Backpack:FindFirstChild("Knife") then
                CrosshairFrame.Visible = false KnifeIcon.Visible = true
            else
                CrosshairFrame.Visible = true KnifeIcon.Visible = false
            end
        end
        SettingsButton.Position = UDim2.new(MainButton.Position.X.Scale, MainButton.Position.X.Offset + MainButton.AbsoluteSize.X + 5, MainButton.Position.Y.Scale, MainButton.Position.Y.Offset)
        SettPanel.Position = UDim2.new(SettingsButton.Position.X.Scale, SettingsButton.Position.X.Offset, SettingsButton.Position.Y.Scale, SettingsButton.Position.Y.Offset + 30)
    end
end)

-- Kéo thả nút chính mượt mà trên Mobile (Có hỗ trợ Khóa)
local dragging, dragInput, dragStart, startPos
MainButton.InputBegan:Connect(function(input)
    if not isDragLocked and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        dragging = true; dragStart = input.Position; startPos = MainButton.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
MainButton.InputChanged:Connect(function(input) if not isDragLocked and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input) if not isDragLocked and input == dragInput and dragging then
    local delta = input.Position - dragStart
    MainButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end end)
