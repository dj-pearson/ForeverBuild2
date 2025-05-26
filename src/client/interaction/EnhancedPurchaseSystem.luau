-- EnhancedPurchaseSystem.luau
-- Enhanced purchase system with E-key support and insufficient funds handling

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import currency manager
local CurrencyManager
local currencySuccess = pcall(function()
    -- Try to find your existing currency manager
    CurrencyManager = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("CurrencyManager"))
end)

if not currencySuccess then
    warn("EnhancedPurchaseSystem: Could not load CurrencyManager")
end

local EnhancedPurchaseSystem = {}
EnhancedPurchaseSystem.__index = EnhancedPurchaseSystem

function EnhancedPurchaseSystem.new()
    local self = setmetatable({}, EnhancedPurchaseSystem)
    
    -- Purchase state tracking
    self.currentPurchasePrompt = nil
    self.currentItemData = nil
    self.isPromptVisible = false
    self.lastPromptUpdate = 0
    
    -- UI elements
    self.purchasePrompt = nil
    self.getMoreCoinsGui = nil
    
    -- Configuration
    self.config = {
        eKeyEnabled = true,
        showInsufficientFundsPopup = true,
        autoHidePromptDelay = 3, -- seconds
        currencyCheckInterval = 0.5 -- seconds
    }
    
    -- Robux products for "Get More Coins" (configure these with your actual product IDs)
    self.robuxProducts = {
        {coins = 1000, robux = 99, productId = 123456, name = "1,000 Coins"},
        {coins = 5000, robux = 299, productId = 123457, name = "5,000 Coins"}, 
        {coins = 15000, robux = 799, productId = 123458, name = "15,000 Coins"},
        {coins = 50000, robux = 1999, productId = 123459, name = "50,000 Coins"}
    }
    
    self:Initialize()
    return self
end

function EnhancedPurchaseSystem:Initialize()
    self:CreatePurchasePromptUI()
    self:CreateGetMoreCoinsUI()
    self:SetupInputHandling()
    self:StartCurrencyMonitoring()
    
    print("✅ Enhanced Purchase System initialized")
end

-- Create the floating purchase prompt UI
function EnhancedPurchaseSystem:CreatePurchasePromptUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EnhancedPurchasePrompt"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main prompt frame
    local promptFrame = Instance.new("Frame")
    promptFrame.Name = "PromptFrame"
    promptFrame.Size = UDim2.new(0, 300, 0, 100)
    promptFrame.Position = UDim2.new(0.5, -150, 0.15, 0) -- Top center
    promptFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    promptFrame.BackgroundTransparency = 0.3
    promptFrame.BorderSizePixel = 0
    promptFrame.Visible = false
    promptFrame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = promptFrame
    
    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0.3, 0.8, 1)
    stroke.Thickness = 2
    stroke.Parent = promptFrame
    
    -- Item name label
    local itemNameLabel = Instance.new("TextLabel")
    itemNameLabel.Name = "ItemName"
    itemNameLabel.Size = UDim2.new(1, -20, 0, 30)
    itemNameLabel.Position = UDim2.new(0, 10, 0, 10)
    itemNameLabel.BackgroundTransparency = 1
    itemNameLabel.Text = "Item Name"
    itemNameLabel.TextColor3 = Color3.new(1, 1, 1)
    itemNameLabel.TextScaled = true
    itemNameLabel.Font = Enum.Font.GothamBold
    itemNameLabel.Parent = promptFrame
    
    -- Price label
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "Price"
    priceLabel.Size = UDim2.new(0.5, -10, 0, 25)
    priceLabel.Position = UDim2.new(0, 10, 0, 45)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = "💰 0 Coins"
    priceLabel.TextColor3 = Color3.new(1, 1, 0.5)
    priceLabel.TextScaled = true
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.Parent = promptFrame
    
    -- E key prompt
    local eKeyLabel = Instance.new("TextLabel")
    eKeyLabel.Name = "EKeyPrompt"
    eKeyLabel.Size = UDim2.new(0.5, -10, 0, 25)
    eKeyLabel.Position = UDim2.new(0.5, 0, 0, 45)
    eKeyLabel.BackgroundTransparency = 1
    eKeyLabel.Text = "[E] Purchase"
    eKeyLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
    eKeyLabel.TextScaled = true
    eKeyLabel.Font = Enum.Font.GothamBold
    eKeyLabel.Parent = promptFrame
    
    -- Current cash label
    local cashLabel = Instance.new("TextLabel")
    cashLabel.Name = "CurrentCash"
    cashLabel.Size = UDim2.new(1, -20, 0, 20)
    cashLabel.Position = UDim2.new(0, 10, 0, 75)
    cashLabel.BackgroundTransparency = 1
    cashLabel.Text = "You have: 💰 0 Coins"
    cashLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    cashLabel.TextScaled = true
    cashLabel.Font = Enum.Font.Gotham
    cashLabel.Parent = promptFrame
    
    self.purchasePrompt = promptFrame
end

-- Create the "Get More Coins" UI
function EnhancedPurchaseSystem:CreateGetMoreCoinsUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GetMoreCoinsGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Visible = false
    overlay.Parent = screenGui
    
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = overlay
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = mainFrame
    
    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 0.8, 0)
    stroke.Thickness = 3
    stroke.Parent = mainFrame
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -20, 0, 50)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "💰 Get More Coins"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = mainFrame
    
    -- Insufficient funds message
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Name = "Message"
    messageLabel.Size = UDim2.new(1, -20, 0, 40)
    messageLabel.Position = UDim2.new(0, 10, 0, 60)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = "You need more coins for this purchase!"
    messageLabel.TextColor3 = Color3.new(1, 0.5, 0.5)
    messageLabel.TextScaled = true
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.Parent = mainFrame
    
    -- Scroll frame for products
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ProductScroll"
    scrollFrame.Size = UDim2.new(1, -20, 0, 300)
    scrollFrame.Position = UDim2.new(0, 10, 0, 110)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = mainFrame
    
    -- Layout for products
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = scrollFrame
    
    -- Create product buttons
    for i, product in ipairs(self.robuxProducts) do
        self:CreateProductButton(scrollFrame, product, i)
    end
    
    -- Update canvas size
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end)
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 100, 0, 40)
    closeButton.Position = UDim2.new(0.5, -50, 0, 430)
    closeButton.BackgroundColor3 = Color3.new(0.8, 0.3, 0.3)
    closeButton.Text = "Close"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = mainFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:HideGetMoreCoinsGui()
    end)
    
    self.getMoreCoinsGui = overlay
end

function EnhancedPurchaseSystem:CreateProductButton(parent, product, index)
    local button = Instance.new("TextButton")
    button.Name = "Product" .. index
    button.Size = UDim2.new(1, -16, 0, 60)
    button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    button.BorderSizePixel = 0
    button.Text = ""
    button.LayoutOrder = index
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0.4, 0.4, 0.4)
    stroke.Thickness = 1
    stroke.Parent = button
    
    -- Product info label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(0.7, 0, 1, 0)
    infoLabel.Position = UDim2.new(0, 10, 0, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = string.format("💰 %s Coins\n%s", 
        self:FormatNumber(product.coins), product.name)
    infoLabel.TextColor3 = Color3.new(1, 1, 1)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = button
    
    -- Price label
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(0.3, -10, 1, 0)
    priceLabel.Position = UDim2.new(0.7, 0, 0, 0)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = string.format("R$ %d", product.robux)
    priceLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
    priceLabel.TextScaled = true
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.Parent = button
    
    -- Button interaction
    button.MouseButton1Click:Connect(function()
        self:PurchaseRobuxProduct(product)
    end)
    
    button.MouseEnter:Connect(function()
        stroke.Color = Color3.new(0.3, 1, 0.3)
        stroke.Thickness = 2
    end)
    
    button.MouseLeave:Connect(function()
        stroke.Color = Color3.new(0.4, 0.4, 0.4)
        stroke.Thickness = 1
    end)
end

-- Setup input handling for E key
function EnhancedPurchaseSystem:SetupInputHandling()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E and self.config.eKeyEnabled then
            if self.isPromptVisible and self.currentItemData then
                self:AttemptPurchase()
            end
        end
    end)
end

-- Start monitoring currency updates
function EnhancedPurchaseSystem:StartCurrencyMonitoring()
    spawn(function()
        while true do
            if self.isPromptVisible then
                self:UpdateCurrencyDisplay()
            end
            wait(self.config.currencyCheckInterval)
        end
    end)
end

-- Main function to show purchase prompt
function EnhancedPurchaseSystem:ShowPurchasePrompt(itemData)
    if not itemData then return end
    
    self.currentItemData = itemData
    self.isPromptVisible = true
    self.lastPromptUpdate = tick()
    
    -- Update UI elements
    local promptFrame = self.purchasePrompt
    if promptFrame then
        promptFrame.ItemName.Text = itemData.name or itemData.Name or "Unknown Item"
        
        -- Format price
        local price = itemData.price or itemData.Price or {INGAME = 0}
        local coinPrice = 0
        
        if typeof(price) == "number" then
            coinPrice = price
        elseif typeof(price) == "table" then
            coinPrice = price.INGAME or price.ingame or price.Ingame or 0
        end
        
        promptFrame.Price.Text = string.format("💰 %s Coins", self:FormatNumber(coinPrice))
        
        self:UpdateCurrencyDisplay()
        
        -- Show with animation
        promptFrame.Visible = true
        promptFrame.Size = UDim2.new(0, 0, 0, 0)
        promptFrame.Position = UDim2.new(0.5, 0, 0.15, 0)
        
        local showTween = TweenService:Create(promptFrame, 
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, 300, 0, 100),
                Position = UDim2.new(0.5, -150, 0.15, 0)
            }
        )
        showTween:Play()
    end
end

function EnhancedPurchaseSystem:HidePurchasePrompt()
    if not self.isPromptVisible then return end
    
    self.isPromptVisible = false
    self.currentItemData = nil
    
    local promptFrame = self.purchasePrompt
    if promptFrame then
        local hideTween = TweenService:Create(promptFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {
                Size = UDim2.new(0, 0, 0, 0),
                Position = UDim2.new(0.5, 0, 0.15, 0)
            }
        )
        
        hideTween:Play()
        hideTween.Completed:Connect(function()
            promptFrame.Visible = false
        end)
    end
end

function EnhancedPurchaseSystem:UpdateCurrencyDisplay()
    if not self.purchasePrompt then return end
    
    local currentCoins = self:GetPlayerCoins()
    self.purchasePrompt.CurrentCash.Text = string.format("You have: 💰 %s Coins", self:FormatNumber(currentCoins))
    
    -- Update E key prompt color based on affordability
    local itemPrice = self:GetItemPrice(self.currentItemData)
    local eKeyLabel = self.purchasePrompt.EKeyPrompt
    
    if currentCoins >= itemPrice then
        eKeyLabel.TextColor3 = Color3.new(0.3, 1, 0.3) -- Green - can afford
        eKeyLabel.Text = "[E] Purchase"
    else
        eKeyLabel.TextColor3 = Color3.new(1, 0.5, 0.5) -- Red - cannot afford
        eKeyLabel.Text = "[E] Need More Coins"
    end
end

-- Attempt to purchase the current item
function EnhancedPurchaseSystem:AttemptPurchase()
    if not self.currentItemData then return end
    
    local currentCoins = self:GetPlayerCoins()
    local itemPrice = self:GetItemPrice(self.currentItemData)
    
    if currentCoins >= itemPrice then
        -- Player can afford it - proceed with purchase
        self:ProcessPurchase()
    else
        -- Insufficient funds - show get more coins menu
        self:ShowInsufficientFundsPopup(itemPrice, currentCoins)
    end
end

function EnhancedPurchaseSystem:ProcessPurchase()
    -- Hide the prompt
    self:HidePurchasePrompt()
    
    -- Fire the purchase to your existing purchase system
    local purchaseEvent = ReplicatedStorage:FindFirstChild("PurchaseItem")
    if purchaseEvent then
        purchaseEvent:FireServer(self.currentItemData)
        print("✅ Purchase initiated for:", self.currentItemData.name or self.currentItemData.Name)
    else
        warn("⚠️ Purchase event not found - integrate with your existing purchase system")
    end
end

function EnhancedPurchaseSystem:ShowInsufficientFundsPopup(needed, current)
    if not self.config.showInsufficientFundsPopup then return end
    
    local shortfall = needed - current
    
    -- Update message
    if self.getMoreCoinsGui then
        local mainFrame = self.getMoreCoinsGui.MainFrame
        mainFrame.Message.Text = string.format(
            "You need %s more coins!\nRequired: %s | You have: %s",
            self:FormatNumber(shortfall),
            self:FormatNumber(needed),
            self:FormatNumber(current)
        )
        
        -- Show with animation
        self.getMoreCoinsGui.Visible = true
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        local showTween = TweenService:Create(mainFrame,
            TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, 400, 0, 500),
                Position = UDim2.new(0.5, -200, 0.5, -250)
            }
        )
        showTween:Play()
    end
end

function EnhancedPurchaseSystem:HideGetMoreCoinsGui()
    if self.getMoreCoinsGui then
        local mainFrame = self.getMoreCoinsGui.MainFrame
        
        local hideTween = TweenService:Create(mainFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {
                Size = UDim2.new(0, 0, 0, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0)
            }
        )
        
        hideTween:Play()
        hideTween.Completed:Connect(function()
            self.getMoreCoinsGui.Visible = false
        end)
    end
end

-- Purchase Robux products
function EnhancedPurchaseSystem:PurchaseRobuxProduct(product)
    print("🛒 Attempting to purchase:", product.name)
    
    local success, result = pcall(function()
        MarketplaceService:PromptProductPurchase(player, product.productId)
    end)
    
    if not success then
        warn("❌ Failed to prompt product purchase:", result)
    end
    
    self:HideGetMoreCoinsGui()
end

-- Utility functions
function EnhancedPurchaseSystem:GetPlayerCoins()
    -- Try to get from your currency manager
    if CurrencyManager and typeof(CurrencyManager.GetCoins) == "function" then
        return CurrencyManager:GetCoins() or 0
    end
    
    -- Fallback - try to find currency in leaderstats or other common locations
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local coins = leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money")
        if coins then
            return coins.Value or 0
        end
    end
    
    -- Another fallback - check player data
    local playerData = player:FindFirstChild("Data")
    if playerData then
        local coins = playerData:FindFirstChild("Coins")
        if coins then
            return coins.Value or 0
        end
    end
    
    return 0
end

function EnhancedPurchaseSystem:GetItemPrice(itemData)
    if not itemData then return 0 end
    
    local price = itemData.price or itemData.Price or itemData.cost or itemData.Cost
    
    if typeof(price) == "number" then
        return price
    elseif typeof(price) == "table" then
        return price.INGAME or price.ingame or price.Ingame or 0
    end
    
    return 0
end

function EnhancedPurchaseSystem:FormatNumber(number)
    local formatted = tostring(number)
    local k = 3
    while k <= #formatted do
        formatted = formatted:sub(1, #formatted - k) .. "," .. formatted:sub(#formatted - k + 1)
        k = k + 4
    end
    return formatted
end

-- Public API functions
function EnhancedPurchaseSystem:EnableEKeyPurchases(enabled)
    self.config.eKeyEnabled = enabled
end

function EnhancedPurchaseSystem:SetInsufficientFundsPopup(enabled)
    self.config.showInsufficientFundsPopup = enabled
end

-- Integration function for your existing systems
function EnhancedPurchaseSystem:OnItemProximity(itemData)
    -- Call this when a player gets close to an item
    self:ShowPurchasePrompt(itemData)
end

function EnhancedPurchaseSystem:OnItemProximityExit()
    -- Call this when a player moves away from an item
    self:HidePurchasePrompt()
end

return EnhancedPurchaseSystem 