--[[
    CurrencyUI Module - ForeverBuild2
    
    NOTE: This is the original CurrencyUI implementation.
    Previously we tried to forward to the client implementation but that caused path issues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- CRITICAL FIX: Use the correct path to Constants
local Constants = require(script.Parent.Parent.Constants)

-- Import the client version was causing errors - restore original functionality
local success, ClientCurrencyUI = true, nil -- Just to keep the existing code structure

if not success then
    warn("Failed to require client CurrencyUI module:", ClientCurrencyUI)
    
    -- Create a minimal fallback implementation
    local FallbackCurrencyUI = {}
    FallbackCurrencyUI.__index = FallbackCurrencyUI
    
    -- Initialize a new CurrencyUI
    function FallbackCurrencyUI.new()
        warn("Using fallback CurrencyUI implementation")
        local self = setmetatable({}, FallbackCurrencyUI)
        return self
    end
    
    -- Initialize the CurrencyUI with minimal functionality
    function FallbackCurrencyUI:Initialize()
        warn("Fallback CurrencyUI:Initialize called")
    end
    
    -- Create UI (stub)
    function FallbackCurrencyUI:CreateUI()
        warn("Fallback CurrencyUI:CreateUI called")
    end
    
    -- Set up event handlers (stub)
    function FallbackCurrencyUI:SetupEventHandlers()
        warn("Fallback CurrencyUI:SetupEventHandlers called")
    end
    
    -- Update balance (stub)
    function FallbackCurrencyUI:UpdateBalance()
        warn("Fallback CurrencyUI:UpdateBalance called")
    end
    
    -- We're not going to use the fallback
    -- Instead restore the original implementation
end

-- Original implementation from here:
local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

-- Initialize a new CurrencyUI
function CurrencyUI.new()
    local self = setmetatable({}, CurrencyUI)
    self.ui = nil
    return self
end

-- Initialize the CurrencyUI
function CurrencyUI:Initialize()
    -- Create UI
    self:CreateUI()
    
    -- Set up event handlers
    self:SetupEventHandlers()
    
    -- Initial balance update
    self:UpdateBalance(Constants.CURRENCY.STARTING_COINS)
end

-- Create UI
function CurrencyUI:CreateUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("CurrencyUI")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CurrencyUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end
    
    -- Create main frame at top center
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(0.5, -100, 0, 20) -- Top center
    frame.BackgroundColor3 = Constants.UI_COLORS and Constants.UI_COLORS.SECONDARY or Color3.fromRGB(40,40,40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Add coin icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "CoinIcon"
    icon.Size = UDim2.new(0, 32, 0, 32)
    icon.Position = UDim2.new(0, 10, 0.5, -16)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://6034973115" -- Coin icon
    icon.Parent = frame
    
    -- Add balance text
    local balance = Instance.new("TextLabel")
    balance.Name = "Balance"
    balance.Size = UDim2.new(0, 100, 0, 30)
    balance.Position = UDim2.new(0, 52, 0.5, -15)
    balance.BackgroundTransparency = 1
    balance.Font = Enum.Font.GothamBold
    balance.TextSize = 18
    balance.TextColor3 = Color3.fromRGB(255, 255, 255)
    balance.TextXAlignment = Enum.TextXAlignment.Left
    balance.Text = "0"
    balance.Parent = frame
    
    -- Add purchase button
    local purchaseBtn = Instance.new("TextButton")
    purchaseBtn.Name = "PurchaseButton"
    purchaseBtn.Size = UDim2.new(0, 40, 0, 30)
    purchaseBtn.Position = UDim2.new(1, -50, 0.5, -15)
    purchaseBtn.BackgroundColor3 = Constants.UI_COLORS and Constants.UI_COLORS.PRIMARY or Color3.fromRGB(0, 170, 255)
    purchaseBtn.BorderSizePixel = 0
    purchaseBtn.Font = Enum.Font.GothamBold
    purchaseBtn.TextSize = 18
    purchaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseBtn.Text = "+"
    purchaseBtn.Parent = frame
    
    -- Add rounded corners to button
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = purchaseBtn
    
    -- Add click handler
    purchaseBtn.MouseButton1Click:Connect(function()
        self:ShowPurchaseMenu()
    end)
    
    -- Store UI reference
    self.ui = screenGui
    
    return screenGui
end

-- Set up event handlers
function CurrencyUI:SetupEventHandlers()
    -- Wait for RemoteEvents to be created
    local success, remotes = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
    end)
    
    if success and remotes and remotes:FindFirstChild("UpdateBalance") then
        remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
            self:UpdateBalance(newBalance)
        end)
    else
        warn("CurrencyUI: Could not find UpdateBalance remote event")
        -- Try again later
        task.delay(5, function()
            if ReplicatedStorage:FindFirstChild("Remotes") and 
               ReplicatedStorage.Remotes:FindFirstChild("UpdateBalance") then
                ReplicatedStorage.Remotes.UpdateBalance.OnClientEvent:Connect(function(balance)
                    self:UpdateBalance(balance)
                end)
            end
        end)
    end
end

-- Update balance display
function CurrencyUI:UpdateBalance(balance)
    if not self.ui then return end
    
    local mainFrame = self.ui:FindFirstChild("MainFrame")
    if not mainFrame then return end
    
    local balanceLabel = mainFrame:FindFirstChild("Balance")
    if not balanceLabel then return end
    
    balanceLabel.Text = tostring(balance)
end

-- Show purchase menu
function CurrencyUI:ShowPurchaseMenu()
    -- Create a simple purchase dialog
    -- This is a stub - the full functionality is in client/Currency/CurrencyUI.luau
    local dialog = Instance.new("Frame")
    dialog.Name = "PurchaseDialog"
    dialog.Size = UDim2.new(0, 300, 0, 200)
    dialog.Position = UDim2.new(0.5, -150, 0.5, -100)
    dialog.BackgroundColor3 = Constants.UI_COLORS and Constants.UI_COLORS.SECONDARY or Color3.fromRGB(40, 40, 40)
    dialog.BorderSizePixel = 0
    dialog.Visible = true
    dialog.Parent = self.ui
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = dialog
    
    -- Add title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 24
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Purchase Currency"
    title.Parent = dialog
    
    -- Add close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "X"
    closeBtn.Parent = dialog
    
    -- Add rounded corners to close button
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 4)
    closeBtnCorner.Parent = closeBtn
    
    -- Add close button handler
    closeBtn.MouseButton1Click:Connect(function()
        dialog:Destroy()
    end)
    
    -- Add placeholder text for purchase options
    local placeholder = Instance.new("TextLabel")
    placeholder.Name = "Placeholder"
    placeholder.Size = UDim2.new(1, -40, 0, 100)
    placeholder.Position = UDim2.new(0, 20, 0, 60)
    placeholder.BackgroundTransparency = 1
    placeholder.Font = Enum.Font.Gotham
    placeholder.TextSize = 16
    placeholder.TextColor3 = Color3.fromRGB(200, 200, 200)
    placeholder.TextWrapped = true
    placeholder.Text = "Purchase options would appear here. For the complete purchase menu, see client/Currency/CurrencyUI.luau."
    placeholder.Parent = dialog
end

return CurrencyUI
