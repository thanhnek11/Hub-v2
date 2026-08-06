-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

-- Cleanup script cũ nếu re-run
if _G.AutoEatHubCleanup then
    pcall(_G.AutoEatHubCleanup)
end

local Connections = {}
local Config = {
    AutoEat = false,
    AutoSell = false,
    AntiAFK = false
}
local ScriptRunning = true

local GrabRemotesCache = {}
local EatRemotesCache = {}
local lastRemotesRefresh = 0

-- Lọc và lấy danh sách Remote Events
local function RefreshRemotes()
    GrabRemotesCache = {}
    EatRemotesCache = {}
    lastRemotesRefresh = tick()
    
    local function checkRemote(v)
        if v:IsA("RemoteEvent") then
            local n = string.lower(v.Name)
            if string.find(n, "grab") then
                table.insert(GrabRemotesCache, v)
            elseif string.find(n, "eat") or string.find(n, "bite") or string.find(n, "consume") then
                table.insert(EatRemotesCache, v)
            end
        end
    end

    pcall(function()
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do checkRemote(v) end
        local char = LocalPlayer.Character
        if char then
            for _, v in pairs(char:GetDescendants()) do checkRemote(v) end
        end
    end)
end

-- Tính toán Size hiện tại & Max Size
local MaxSizeGrowthFunction = nil
pcall(function()
    MaxSizeGrowthFunction = require(ReplicatedStorage:WaitForChild("ItemInfo")).Upgrades.MaxSize.growthFunction
end)

local function ApplySizeGrowth(value)
    if MaxSizeGrowthFunction then
        local success, result = pcall(MaxSizeGrowthFunction, value)
        if success and type(result) == "number" then return result end
    end
    return value
end

local function GetSizeData()
    local currentSize = 0
    local maxSize = math.huge 
    
    local character = LocalPlayer.Character
    if character then
        local sizeVal = character:FindFirstChild("Size")
        if sizeVal and (sizeVal:IsA("IntValue") or sizeVal:IsA("NumberValue")) then
            currentSize = ApplySizeGrowth(sizeVal.Value)
        end
    end
    
    local upgradesFolder = LocalPlayer:FindFirstChild("Upgrades") or LocalPlayer:FindFirstChild("upgrades") or LocalPlayer:FindFirstChild("Upgrade")
    if upgradesFolder then
        local maxVal = upgradesFolder:FindFirstChild("MaxSize")
        if maxVal and (maxVal:IsA("IntValue") or maxVal:IsA("NumberValue")) then
            maxSize = ApplySizeGrowth(maxVal.Value)
        end
    end
    
    return currentSize, maxSize
end

local function CanSellNow()
    local cSize, mSize = GetSizeData()
    return cSize > 0 and mSize > 0 and cSize >= mSize and mSize ~= math.huge
end

-- Bán hàng (Fire Remote Sell)
local function FireSellRemotes(forceSell)
    if not ScriptRunning then return end
    if not forceSell and (not Config.AutoSell or not CanSellNow()) then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local eventsFolder = character:FindFirstChild("Events")
    if eventsFolder then
        local sellRemote = eventsFolder:FindFirstChild("Sell")
        if sellRemote and sellRemote:IsA("RemoteEvent") then
            pcall(function() sellRemote:FireServer() end)
        end
    end
end

-- Vòng lặp Anti-AFK
table.insert(Connections, LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK and ScriptRunning then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

task.spawn(function()
    while ScriptRunning do
        task.wait(60)
        if Config.AntiAFK then
            pcall(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    hum.Jump = true
                end
            end)
        end
    end
end)

-- Vòng lặp Auto Eat (Heartbeat)
table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not ScriptRunning or not Config.AutoEat then return end
    
    if #GrabRemotesCache == 0 or #EatRemotesCache == 0 or (tick() - lastRemotesRefresh) > 5 then
        RefreshRemotes()
    end
    
    for _, remote in ipairs(GrabRemotesCache) do
        if remote and remote.Parent then pcall(function() remote:FireServer() end) end
    end
    
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    
    for _, remote in ipairs(EatRemotesCache) do
        if remote and remote.Parent then 
            pcall(function() 
                remote:FireServer() 
                if tool then remote:FireServer(tool) end
            end) 
        end
    end
end))

-- Vòng lặp Auto Sell
task.spawn(function()
    while ScriptRunning do
        task.wait(0.4)
        if Config.AutoSell and CanSellNow() then
            FireSellRemotes(false)
            task.wait(1)
        end
    end
end)

-- ===================================================================
-- TẠO GIAO DIỆN (GUI)
-- ===================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ETW_AntiAFK_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Khung chính
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 250, 0, 235)
MainFrame.Position = UDim2.new(0.5, -125, 0.4, -115)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Thanh Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(200, 80, 20)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Text = "EAT THE WORLD HUB"
Title.Size = UDim2.new(1, -65, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Nút Thu nhỏ (-)
local MinBtn = Instance.new("TextButton")
MinBtn.Text = "-"
MinBtn.Size = UDim2.new(0, 22, 0, 22)
MinBtn.Position = UDim2.new(1, -50, 0.5, -11)
MinBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

-- Nút Đóng (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -25, 0.5, -11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

-- Container chứa các tính năng
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, 0, 1, -30)
Container.Position = UDim2.new(0, 0, 0, 30)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

-- Helper tạo Nút Toggle
local function CreateToggle(text, yPos, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.9, 0, 0, 35)
    Btn.Position = UDim2.new(0.05, 0, 0, yPos)
    Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    Btn.Text = text .. ": OFF"
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.Parent = Container
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    
    local state = false
    table.insert(Connections, Btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            Btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            Btn.Text = text .. ": ON"
        else
            Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
            Btn.Text = text .. ": OFF"
        end
        callback(state)
    end))
end

-- Tạo các Nút Chức Năng
CreateToggle("AUTO EAT", 10, function(val)
    Config.AutoEat = val
end)

CreateToggle("AUTO SELL", 50, function(val)
    Config.AutoSell = val
end)

CreateToggle("ANTI AFK", 90, function(val)
    Config.AntiAFK = val
end)

-- Nút Sell Now
local SellNowBtn = Instance.new("TextButton")
SellNowBtn.Size = UDim2.new(0.9, 0, 0, 35)
SellNowBtn.Position = UDim2.new(0.05, 0, 0, 130)
SellNowBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 30)
SellNowBtn.Text = "SELL NOW"
SellNowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SellNowBtn.Font = Enum.Font.GothamBold
SellNowBtn.TextSize = 12
SellNowBtn.Parent = Container
Instance.new("UICorner", SellNowBtn).CornerRadius = UDim.new(0, 6)

table.insert(Connections, SellNowBtn.MouseButton1Click:Connect(function()
    FireSellRemotes(true)
end))

-- Kéo thả Menu
local dragging, dragStart, startPos
table.insert(Connections, Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

-- Nút (-) Thu nhỏ / Mở rộng
local isMinimized = false
table.insert(Connections, MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 250, 0, 30)
        Container.Visible = false
        MinBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 250, 0, 235)
        Container.Visible = true
        MinBtn.Text = "-"
    end
end))

-- Nút (X) Đóng script
local function Cleanup()
    ScriptRunning = false
    Config.AutoEat = false
    Config.AutoSell = false
    Config.AntiAFK = false
    for _, conn in pairs(Connections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    pcall(function() ScreenGui:Destroy() end)
    _G.AutoEatHubCleanup = nil
end

_G.AutoEatHubCleanup = Cleanup
table.insert(Connections, CloseBtn.MouseButton1Click:Connect(Cleanup))

-- Phím tắt RightShift
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end))
