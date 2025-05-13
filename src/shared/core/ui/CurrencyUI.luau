local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- CRITICAL FIX: Use the correct path to Constants
-- This was using an incorrect path that could cause circular dependencies
local Constants = require(script.Parent.Parent.Constants)

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
    local screenGui = playerGui:FindFirstChild("Economy")
    if not screenGui then
        screenGui = playerGui:WaitForChild("Economy", 5)
    end
    if not screenGui then
        warn("Economy ScreenGui not found after waiting! Creating fallback CurrencyUI ScreenGui.")
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CurrencyUI"
        screenGui.Parent = playerGui
    end
    
    -- Create main frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(1, -220, 0, 20)
    frame.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Create coin icon
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 30, 0, 30)
    coinIcon.Position = UDim2.new(0, 10, 0.5, -15)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = "rbxassetid://101567167458494" -- TODO: Add coin icon
    coinIcon.Parent = frame
    
    -- Create balance label
    local balanceLabel = Instance.new("TextLabel")
    balanceLabel.Name = "BalanceLabel"
    balanceLabel.Size = UDim2.new(0, 100, 1, 0)
    balanceLabel.Position = UDim2.new(0, 50, 0, 0)
    balanceLabel.BackgroundTransparency = 1
    balanceLabel.TextColor3 = Constants.UI_COLORS.TEXT
    balanceLabel.TextSize = 18
    balanceLabel.Font = Enum.Font.GothamBold
    balanceLabel.Text = "0"
    balanceLabel.Parent = frame
    
    -- Create purchase button
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0, 30, 0, 30)
    purchaseButton.Position = UDim2.new(1, -40, 0.5, -15)
    purchaseButton.BackgroundColor3 = Constants.UI_COLORS.PRIMARY
    purchaseButton.Text = "+"
    purchaseButton.TextColor3 = Constants.UI_COLORS.TEXT
    purchaseButton.TextSize = 20
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.Parent = frame
    
    self.ui = screenGui
end

-- Set up event handlers
function CurrencyUI:SetupEventHandlers()
    -- Handle balance updates
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if remotes and remotes:FindFirstChild("UpdateBalance") then
        remotes.UpdateBalance.OnClientEvent:Connect(function(balance)
            self:UpdateBalance(balance)
        end)
    else
        warn("CurrencyUI: UpdateBalance remote event not found")
    end
    
    -- Handle purchase button click
    self.ui.MainFrame.PurchaseButton.MouseButton1Click:Connect(function()
        self:ShowPurchaseMenu()
    end)
end

-- Update balance display
function CurrencyUI:UpdateBalance(balance)
    self.ui.MainFrame.BalanceLabel.Text = tostring(balance)
end

-- Show purchase menu
function CurrencyUI:ShowPurchaseMenu()
    -- Since we're not using lazy loading, we need to be careful about circular refs
    -- So instead of requiring the PurchaseDialog module, we'll just create a simple menu here
    local menu = Instance.new("Frame")
    menu.Name = "PurchaseMenu"
    menu.Size = UDim2.new(0, 300, 0, 200)
    menu.Position = UDim2.new(0.5, -150, 0.5, -100)
    menu.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    menu.BorderSizePixel = 0
    menu.Parent = self.ui
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Constants.UI_COLORS.TEXT
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Text = "Purchase Currency"
    title.Parent = menu
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundTransparency = 1
    closeButton.TextColor3 = Constants.UI_COLORS.TEXT
    closeButton.TextSize = 20
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.Parent = menu
    
    closeButton.MouseButton1Click:Connect(function()
        menu:Destroy()
    end)
end

return CurrencyUI
