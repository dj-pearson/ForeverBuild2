local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- Safe require function to prevent errors
local function safeRequire(module)
    local success, result = pcall(function()
        return require(module)
    end)
    
    if success then
        return result
    else
        warn("Failed to require module:", module, "Error:", result)
        return nil
    end
end

-- Get Constants safely
local SharedModule = safeRequire(ReplicatedStorage.shared)
local Constants = SharedModule and SharedModule.Constants or {
    CURRENCY = {
        STARTING_COINS = 100,
        PRODUCTS = {} -- Default empty products array
    }
}

-- Debug: Print product information
if Constants and Constants.CURRENCY and Constants.CURRENCY.PRODUCTS then
    print("CurrencyUI: Found", #Constants.CURRENCY.PRODUCTS, "products")
    for i, product in ipairs(Constants.CURRENCY.PRODUCTS) do
        print("Product", i, ":", product.name, "AssetId:", product.assetId)
    end
else
    warn("CurrencyUI: No products found in Constants")
end

-- This module is now the primary CurrencyUI implementation
-- It replaces both the client and shared versions
local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

-- COMPATIBILITY: Add aliases for method names used in the shared version
CurrencyUI.SetupEventHandlers = function(self) self:SetupEventHandling() end

-- Initialize a new CurrencyUI
function CurrencyUI.new()
    local self = setmetatable({}, CurrencyUI)
    self.player = Players.LocalPlayer
    self.ui = nil
    self.balance = 0
    return self
end

-- Initialize the CurrencyUI
function CurrencyUI:Initialize()
    -- Create UI
    self:CreateUI()
    
    -- Set up event handling
    self:SetupEventHandling()
    
    -- Initial balance update
    self:UpdateBalance(Constants.CURRENCY.STARTING_COINS or 0)
end

-- Create UI
function CurrencyUI:CreateUI()
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CurrencyUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = self.player:WaitForChild("PlayerGui")
    
    -- Create main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 220, 0, 56)
    mainFrame.Position = UDim2.new(1, -240, 0, 24) -- Top right, 24px from top/right
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
    coinIcon.Image = "rbxassetid://101567167458494" -- TODO: Replace with actual coin icon
    coinIcon.Parent = mainFrame
    
    -- Create balance label
    local balanceLabel = Instance.new("TextLabel")
    balanceLabel.Name = "BalanceLabel"
    balanceLabel.Size = UDim2.new(0, 100, 1, 0)
    balanceLabel.Position = UDim2.new(0, 56, 0, 0)
    balanceLabel.BackgroundTransparency = 1
    balanceLabel.TextColor3 = Color3.fromRGB(255, 223, 70)
    balanceLabel.TextSize = 28
    balanceLabel.Font = Enum.Font.GothamBold
    balanceLabel.Text = "0"
    balanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    balanceLabel.Parent = mainFrame
    
    -- Create purchase button
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0, 40, 0, 40)
    purchaseButton.Position = UDim2.new(1, -48, 0.5, -20)
    purchaseButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    purchaseButton.Text = "+"
    purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseButton.TextSize = 24
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.Parent = mainFrame
    
    local purchaseCorner = Instance.new("UICorner")
    purchaseCorner.CornerRadius = UDim.new(0, 10)
    purchaseCorner.Parent = purchaseButton
    
    -- Store UI reference
    self.ui = screenGui
end

-- Set up event handling
function CurrencyUI:SetupEventHandling()
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
    
    -- Handle purchase button click if UI was created
    if self.ui and self.ui:FindFirstChild("MainFrame") and 
       self.ui.MainFrame:FindFirstChild("PurchaseButton") then
        self.ui.MainFrame.PurchaseButton.MouseButton1Click:Connect(function()
            self:ShowPurchaseMenu()
        end)
    end
end

-- Update balance display
function CurrencyUI:UpdateBalance(balance)
    self.ui.MainFrame.BalanceLabel.Text = tostring(balance)
end

-- Show purchase menu
function CurrencyUI:ShowPurchaseMenu()
    -- Check if purchase menu already exists and remove it
    if self.ui:FindFirstChild("PurchaseMenu") then
        self.ui:FindFirstChild("PurchaseMenu"):Destroy()
    end

    print("ShowPurchaseMenu: Creating purchase menu")
    
    -- Create purchase menu
    local purchaseMenu = Instance.new("Frame")
    purchaseMenu.Name = "PurchaseMenu"
    purchaseMenu.Size = UDim2.new(0, 300, 0, 400)
    purchaseMenu.Position = UDim2.new(0.5, -150, 0.5, -200)
    purchaseMenu.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    purchaseMenu.BorderSizePixel = 0
    purchaseMenu.ZIndex = 10 -- Make sure it's on top
    purchaseMenu.Parent = self.ui
    
    -- Add UICorner to the purchase menu
    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 10)
    menuCorner.Parent = purchaseMenu
    
    -- Create title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 24
    title.ZIndex = 11
    title.Font = Enum.Font.GothamBold
    title.Text = "Purchase Currency"
    title.Parent = purchaseMenu
    
    -- Create close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeButton.BorderSizePixel = 0
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 20
    closeButton.ZIndex = 11
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.Parent = purchaseMenu
    
    -- Add corner to close button
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Hook close button
    closeButton.MouseButton1Click:Connect(function()
        purchaseMenu:Destroy()
    end)
    
    -- Create scroll frame to hold products
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ProductsFrame"
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
    scrollFrame.ZIndex = 11
    scrollFrame.Parent = purchaseMenu
    
    -- Create purchase options
    local yOffset = 10
    
    -- Debug: Check if products exist
    if Constants and Constants.CURRENCY and Constants.CURRENCY.PRODUCTS then
        print("ShowPurchaseMenu: Found", #Constants.CURRENCY.PRODUCTS, "products to display")
        
        for i, product in ipairs(Constants.CURRENCY.PRODUCTS) do
            print("Creating option for product:", product.name)
            local option = self:CreatePurchaseOption(product, yOffset)
            option.Position = UDim2.new(0, 0, 0, yOffset)
            option.Parent = scrollFrame
            yOffset = yOffset + 90 -- Increased spacing for more details
        end
        
        -- Update the canvas size to fit all products
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
    else
        -- No products found - display a message
        local noProducts = Instance.new("TextLabel")
        noProducts.Size = UDim2.new(1, -20, 0, 50)
        noProducts.Position = UDim2.new(0, 10, 0, 10)
        noProducts.BackgroundTransparency = 1
        noProducts.TextColor3 = Color3.fromRGB(255, 255, 255)
        noProducts.TextSize = 16
        noProducts.Font = Enum.Font.Gotham
        noProducts.Text = "No currency products available."
        noProducts.Parent = scrollFrame
        
        warn("ShowPurchaseMenu: No products found to display")
    end
    
    -- Make purchaseMenu visible
    purchaseMenu.Visible = true
end

-- Create a single purchase option
function CurrencyUI:CreatePurchaseOption(product, yOffset)
    -- Debug information
    print("CreatePurchaseOption:", product.name, "ID:", product.assetId)
    
    local optionFrame = Instance.new("Frame")
    optionFrame.Name = product.id
    optionFrame.Size = UDim2.new(1, -20, 0, 80) -- Adjusted to fill the scrollframe width
    optionFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    optionFrame.BorderSizePixel = 1
    optionFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
    optionFrame.ZIndex = 12

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = optionFrame

    local productName = Instance.new("TextLabel")
    productName.Name = "ProductName"
    productName.Size = UDim2.new(1, -100, 0, 30)
    productName.Position = UDim2.new(0, 10, 0, 5)
    productName.BackgroundTransparency = 1
    productName.TextColor3 = Color3.fromRGB(255, 255, 255)
    productName.TextSize = 18
    productName.Font = Enum.Font.GothamBold
    productName.Text = product.name
    productName.TextXAlignment = Enum.TextXAlignment.Left
    productName.ZIndex = 13
    productName.Parent = optionFrame

    local productDescription = Instance.new("TextLabel")
    productDescription.Name = "ProductDescription"
    productDescription.Size = UDim2.new(1, -100, 0, 40)
    productDescription.Position = UDim2.new(0, 10, 0, 30)
    productDescription.BackgroundTransparency = 1
    productDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
    productDescription.TextSize = 14
    productDescription.Font = Enum.Font.Gotham
    productDescription.Text = product.description
    productDescription.TextWrapped = true
    productDescription.TextXAlignment = Enum.TextXAlignment.Left
    productDescription.TextYAlignment = Enum.TextYAlignment.Top
    productDescription.ZIndex = 13
    productDescription.Parent = optionFrame
    
    local robuxLabel = Instance.new("TextLabel")
    robuxLabel.Name = "RobuxLabel"
    robuxLabel.Size = UDim2.new(0, 80, 0, 20)
    robuxLabel.Position = UDim2.new(1, -90, 0, 10) -- Positioned to the right
    robuxLabel.BackgroundTransparency = 1
    robuxLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green for Robux
    robuxLabel.TextSize = 16
    robuxLabel.Font = Enum.Font.GothamBold
    robuxLabel.Text = "R$ " .. product.robux
    robuxLabel.TextXAlignment = Enum.TextXAlignment.Right
    robuxLabel.ZIndex = 13
    robuxLabel.Parent = optionFrame

    if product.bonusCoins > 0 then
        local bonusLabel = Instance.new("TextLabel")
        bonusLabel.Name = "BonusLabel"
        bonusLabel.Size = UDim2.new(0, 80, 0, 20)
        bonusLabel.Position = UDim2.new(1, -90, 0, 30) -- Below Robux label
        bonusLabel.BackgroundTransparency = 1
        bonusLabel.TextColor3 = Color3.fromRGB(255, 223, 0) -- Gold for bonus
        bonusLabel.TextSize = 14
        bonusLabel.Font = Enum.Font.Gotham
        bonusLabel.Text = "+" .. product.bonusCoins .. " Bonus!"
        bonusLabel.TextXAlignment = Enum.TextXAlignment.Right
        bonusLabel.ZIndex = 13
        bonusLabel.Parent = optionFrame
    end

    local purchaseProductButton = Instance.new("TextButton")
    purchaseProductButton.Name = "PurchaseProductButton"
    purchaseProductButton.Size = UDim2.new(0, 80, 0, 30)
    purchaseProductButton.Position = UDim2.new(1, -90, 1, -40) -- Bottom right
    purchaseProductButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    purchaseProductButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseProductButton.TextSize = 16
    purchaseProductButton.Font = Enum.Font.GothamBold
    purchaseProductButton.Text = "Buy"
    purchaseProductButton.ZIndex = 13
    purchaseProductButton.Parent = optionFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = purchaseProductButton

    purchaseProductButton.MouseButton1Click:Connect(function()
        print("Attempting to purchase:", product.name, "ID:", product.assetId)
        -- Check if assetId is valid
        if product.assetId and product.assetId > 0 then
            local success, message = pcall(function()
                MarketplaceService:PromptProductPurchase(self.player, product.assetId)
            end)
            if not success then
                warn("Error prompting product purchase for " .. product.name .. ": " .. tostring(message))
            end
        else
            warn("Invalid assetId for product:", product.name, "ID:", product.assetId)
        end
    end)

    return optionFrame
end

-- COMPATIBILITY: Add aliases for method names used in the shared version
-- This ensures this implementation works with code expecting the shared version's API
CurrencyUI.SetupEventHandlers = function(self) self:SetupEventHandling() end

return CurrencyUI