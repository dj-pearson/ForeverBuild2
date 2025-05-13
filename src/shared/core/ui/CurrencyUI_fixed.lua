local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

-- CRITICAL FIX: Use the correct path to Constants
local Constants = require(script.Parent.Parent.Constants)

local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

-- Initialize a new CurrencyUI
function CurrencyUI.new()
    local self = setmetatable({}, CurrencyUI)
    self.ui = nil
    self.balance = 0
    return self
end

-- Initialize the CurrencyUI
function CurrencyUI:Initialize()
    -- Only create UI on client
    if not RunService:IsClient() then
        return
    end
    
    -- Create UI
    self:CreateUI()
    
    -- Set up event handlers
    self:SetupEventHandlers()
    
    -- Initial balance update
    self:UpdateBalance(Constants.CURRENCY and Constants.CURRENCY.STARTING_COINS or 0)
end

-- Create UI
function CurrencyUI:CreateUI()
    -- Only create UI on client
    if not RunService:IsClient() then
        return
    end
    
    -- Check if player exists
    local player = Players.LocalPlayer
    if not player then
        warn("CurrencyUI: LocalPlayer not found")
        return
    end
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CurrencyUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Create main frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(1, -220, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Create coin icon
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 30, 0, 30)
    coinIcon.Position = UDim2.new(0, 10, 0.5, -15)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = "rbxassetid://5371546645" -- Placeholder coin icon
    coinIcon.Parent = frame
    
    -- Create balance label
    local balanceLabel = Instance.new("TextLabel")
    balanceLabel.Name = "BalanceLabel"
    balanceLabel.Size = UDim2.new(0, 100, 1, 0)
    balanceLabel.Position = UDim2.new(0, 50, 0, 0)
    balanceLabel.BackgroundTransparency = 1
    balanceLabel.TextColor3 = Color3.new(1, 1, 1)
    balanceLabel.TextSize = 18
    balanceLabel.Font = Enum.Font.GothamBold
    balanceLabel.Text = "0"
    balanceLabel.Parent = frame
    
    -- Create purchase button
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0, 30, 0, 30)
    purchaseButton.Position = UDim2.new(1, -40, 0.5, -15)
    purchaseButton.BackgroundColor3 = Color3.fromRGB(59, 165, 93)
    purchaseButton.Text = "+"
    purchaseButton.TextColor3 = Color3.new(1, 1, 1)
    purchaseButton.TextSize = 20
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.Parent = frame
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = purchaseButton
    
    self.ui = screenGui
end

-- Set up event handlers
function CurrencyUI:SetupEventHandlers()
    -- Only setup events on client
    if not RunService:IsClient() then
        return
    end
    
    -- Wait for a maximum of 5 seconds for Remotes folder
    local success, remotes = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
    end)
    
    if success and remotes and remotes:FindFirstChild("UpdateBalance") then
        remotes.UpdateBalance.OnClientEvent:Connect(function(balance)
            self:UpdateBalance(balance)
        end)
    else
        warn("CurrencyUI: UpdateBalance remote event not found or timed out")
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
    
    -- Only setup button if UI was created
    if self.ui and self.ui:FindFirstChild("MainFrame") and 
       self.ui.MainFrame:FindFirstChild("PurchaseButton") then
        self.ui.MainFrame.PurchaseButton.MouseButton1Click:Connect(function()
            self:ShowPurchaseMenu()
        end)
    end
end

-- Update balance display
function CurrencyUI:UpdateBalance(balance)
    if type(balance) ~= "number" then
        warn("CurrencyUI: Invalid balance value:", balance)
        return
    end
    
    self.balance = balance
    
    -- Update UI if it exists
    if self.ui and self.ui:FindFirstChild("MainFrame") and 
       self.ui.MainFrame:FindFirstChild("BalanceLabel") then
        self.ui.MainFrame.BalanceLabel.Text = tostring(balance)
    end
end

-- Show purchase menu
function CurrencyUI:ShowPurchaseMenu()
    -- Implementation for purchase menu would go here
    print("CurrencyUI: Purchase menu clicked - functionality not implemented")
end

return CurrencyUI