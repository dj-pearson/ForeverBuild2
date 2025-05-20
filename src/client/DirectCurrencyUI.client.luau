-- DirectCurrencyUI.client.luau
-- This is a standalone script to create a currency UI that doesn't rely on modules
-- Set this to false to disable this UI if the other one works
local ENABLE_THIS_UI = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- If this UI is disabled, exit early
if not ENABLE_THIS_UI then
    print("DirectCurrencyUI: Disabled via ENABLE_THIS_UI flag")
    return
end

-- Wait for the player to be available
local player = Players.LocalPlayer
if not player then
    player = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end

local function createDirectCurrencyUI()
    print("DirectCurrencyUI: Creating standalone currency UI...")
    
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Check if any CurrencyUI already exists from another source
    if playerGui:FindFirstChild("CurrencyUI") then
        print("DirectCurrencyUI: CurrencyUI already exists from another source, not creating duplicate")
        return nil
    end
    
    -- Check if DirectCurrencyUI already exists
    local existingUI = playerGui:FindFirstChild("DirectCurrencyUI")
    if existingUI then
        print("DirectCurrencyUI: UI already exists, removing it")
        existingUI:Destroy()
    end
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DirectCurrencyUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 220, 0, 56)
    mainFrame.Position = UDim2.new(1, -240, 0, 90) -- Top right, 90px from top (below other UI)
    mainFrame.BackgroundTransparency = 0
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = mainFrame

    -- Add outline
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(255, 223, 70)
    stroke.Parent = mainFrame

    -- Create coin icon
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 40, 0, 40)
    coinIcon.Position = UDim2.new(0, 8, 0.5, -20)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = "rbxassetid://6034973115" -- Standard coin icon
    coinIcon.Parent = mainFrame
    
    -- Create title label
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(0, 100, 0, 20)
    titleLabel.Position = UDim2.new(0, 56, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    titleLabel.TextSize = 12
    titleLabel.Font = Enum.Font.Gotham
    titleLabel.Text = "COINS"
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = mainFrame
    
    -- Create balance label
    local balanceLabel = Instance.new("TextLabel")
    balanceLabel.Name = "BalanceLabel"
    balanceLabel.Size = UDim2.new(0, 100, 0, 30)
    balanceLabel.Position = UDim2.new(0, 56, 0, 20)
    balanceLabel.BackgroundTransparency = 1
    balanceLabel.TextColor3 = Color3.fromRGB(255, 223, 70)
    balanceLabel.TextSize = 28
    balanceLabel.Font = Enum.Font.GothamBold
    balanceLabel.Text = "100"
    balanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    balanceLabel.Parent = mainFrame
    
    -- Connect to UpdateBalance event
    local function setupUpdateBalanceEvent()
        -- Wait for Remotes folder
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then
            print("DirectCurrencyUI: Remotes folder not found, waiting...")
            remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
            if not remotes then
                print("DirectCurrencyUI: Remotes folder still not found after waiting, will retry")
                task.delay(5, setupUpdateBalanceEvent)
                return
            end
        end
        
        -- Wait for UpdateBalance event
        local updateBalanceEvent = remotes:FindFirstChild("UpdateBalance")
        if not updateBalanceEvent then
            print("DirectCurrencyUI: UpdateBalance event not found, creating it...")
            updateBalanceEvent = Instance.new("RemoteEvent")
            updateBalanceEvent.Name = "UpdateBalance"
            updateBalanceEvent.Parent = remotes
        end
        
        -- Connect to the event
        print("DirectCurrencyUI: Found UpdateBalance event, connecting...")
        updateBalanceEvent.OnClientEvent:Connect(function(balance)
            print("DirectCurrencyUI: Received balance update: " .. tostring(balance))
            balanceLabel.Text = tostring(balance)
        end)
        print("DirectCurrencyUI: Successfully connected to UpdateBalance event")
    end
    
    setupUpdateBalanceEvent()
    print("DirectCurrencyUI: Standalone UI created successfully")
    
    return screenGui
end

-- Small delay to ensure we don't conflict with other initialization
task.delay(3, function()
    -- Check if any CurrencyUI already exists
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("CurrencyUI") then
        print("DirectCurrencyUI: Found existing CurrencyUI, not creating duplicate")
        return
    end
    
    createDirectCurrencyUI()
end) 