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

-- Get SharedModule and Constants with multiple fallback options
print("CurrencyUI: Starting module loading...")

-- Define multiple paths to try for Constants
local paths = {
    -- 1. Load through shared module (preferred)
    function()
        print("CurrencyUI: Attempting to load SharedModule...")
        local sharedModule = safeRequire(ReplicatedStorage:WaitForChild("shared", 5))
        if sharedModule and sharedModule.Constants then
            print("CurrencyUI: Successfully loaded Constants from SharedModule")
            return sharedModule.Constants
        end
        return nil
    end,
    
    -- 2. Direct path to Constants via shared
    function() 
        print("CurrencyUI: Attempting direct require via shared/core/Constants...")
        local shared = ReplicatedStorage:FindFirstChild("shared")
        if shared then
            local core = shared:FindFirstChild("core")
            if core then
                local constants = core:FindFirstChild("Constants")
                if constants then
                    return safeRequire(constants)
                end
            end
        end
        return nil
    end,
    
    -- 3. Direct path to Constants via core
    function()
        print("CurrencyUI: Attempting direct require via ReplicatedStorage/core/Constants...")
        local core = ReplicatedStorage:FindFirstChild("core")
        if core then
            local constants = core:FindFirstChild("Constants")
            if constants then
                return safeRequire(constants)
            end
        end
        return nil
    end,
    
    -- 4. Find Constants anywhere in ReplicatedStorage
    function()
        print("CurrencyUI: Searching for Constants anywhere in ReplicatedStorage...")
        local function findConstants(parent)
            for _, child in pairs(parent:GetChildren()) do
                if child.Name == "Constants" and child:IsA("ModuleScript") then
                    print("CurrencyUI: Found Constants at", child:GetFullName())
                    return safeRequire(child)
                end
                
                if #child:GetChildren() > 0 then
                    local result = findConstants(child)
                    if result then return result end
                end
            end
            return nil
        end
        
        return findConstants(ReplicatedStorage)
    end
}

-- Try each path until we find Constants
local Constants
for i, pathFunc in ipairs(paths) do
    print("CurrencyUI: Trying path option", i)
    Constants = pathFunc()
    if Constants then
        print("CurrencyUI: Successfully loaded Constants using path option", i)
        break
    end
end

-- Verify the loaded Constants
if Constants then
    if Constants.CURRENCY then
        print("CurrencyUI: Constants.CURRENCY found")
        
        if Constants.CURRENCY.PRODUCTS then
            print("CurrencyUI: Found", #Constants.CURRENCY.PRODUCTS, "products in Constants.CURRENCY.PRODUCTS")
        else
            warn("CurrencyUI: Constants.CURRENCY.PRODUCTS is missing")
        end
    else
        warn("CurrencyUI: Constants.CURRENCY is missing")
    end
else
    warn("CurrencyUI: All paths to load Constants failed")
end

-- Set default values if Constants couldn't be loaded
if not Constants then
    warn("CurrencyUI: Using default Constants")
    Constants = {
        CURRENCY = {
            STARTING_COINS = 100,
            PRODUCTS = {
                -- Create fallback product definitions
                {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, assetId = 0, description = "Get started with a handy pack of 1,000 coins!"},
                {id = "coins_5000", name = "5,500 Coins", coins = 5000, robux = 350, bonusCoins = 500, assetId = 0, description = "Great value! Grab 5,000 coins and get an extra 500 on us!"},
                {id = "coins_10000", name = "11,500 Coins", coins = 10000, robux = 650, bonusCoins = 1500, assetId = 0, description = "Supercharge your game with 10,000 coins, plus a 1,500 coin bonus!"}
            }
        }
    }
    
    warn("CurrencyUI: Created fallback product definitions")
end

-- Debug: Print product information specifically
if Constants and Constants.CURRENCY then
    if Constants.CURRENCY.PRODUCTS then
        print("CurrencyUI: Found Constants.CURRENCY.PRODUCTS with " .. #Constants.CURRENCY.PRODUCTS .. " products")
        for i, product in ipairs(Constants.CURRENCY.PRODUCTS) do
            print("Product " .. i .. ":")
            for key, value in pairs(product) do
                print("  " .. key .. " = " .. tostring(value))
            end
        end
    else
        warn("CurrencyUI: Constants.CURRENCY exists but PRODUCTS is nil or not a table")
    end
else
    warn("CurrencyUI: No CURRENCY table found in Constants")
end

-- This module is now the primary CurrencyUI implementation
-- It replaces both the client and shared versions
local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

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
    coinIcon.Image = "rbxassetid://6034973115" -- Standard coin icon
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
    
    -- Create a background overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "PurchaseMenu"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 9
    overlay.Parent = self.ui
    
    -- Create purchase menu
    local purchaseMenu = Instance.new("Frame")
    purchaseMenu.Name = "MenuContent"
    purchaseMenu.Size = UDim2.new(0, 300, 0, 400)
    purchaseMenu.Position = UDim2.new(0.5, -150, 0.5, -200)
    purchaseMenu.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    purchaseMenu.BorderSizePixel = 0
    purchaseMenu.ZIndex = 10
    purchaseMenu.Parent = overlay
    
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
        overlay:Destroy()
    end)
    
    -- Also close when clicking outside the menu
    local UserInputService = game:GetService("UserInputService")
    
    -- Use a pcall in case there's an error with getting mouse position
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            pcall(function()
                local mousePos = UserInputService:GetMouseLocation()
                local menuPos = purchaseMenu.AbsolutePosition
                local menuSize = purchaseMenu.AbsoluteSize
                
                -- Check if click is outside the menu
                if mousePos.X < menuPos.X or mousePos.X > menuPos.X + menuSize.X or
                   mousePos.Y < menuPos.Y or mousePos.Y > menuPos.Y + menuSize.Y then
                    overlay:Destroy()
                end
            end)
        end
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
    
            -- Verify Constants and add products
    print("ShowPurchaseMenu: Creating purchase options...")
    
    -- First verify Constants
    if self:VerifyConstants() then
        -- Constants is valid, add products
        local products = Constants.CURRENCY.PRODUCTS
        print("ShowPurchaseMenu: Adding " .. #products .. " products to menu")
        
        for i, product in ipairs(products) do
            print("Creating UI for product " .. i .. ": " .. product.name)
            local option = self:CreatePurchaseOption(product)
            option.Position = UDim2.new(0, 0, 0, yOffset)
            option.Parent = scrollFrame
            yOffset = yOffset + 90 -- Spacing between product items
        end
        
        -- Update the canvas size to fit all products
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
    else
        -- Constants verification failed, use hardcoded products as fallback
        print("ShowPurchaseMenu: Using fallback products")
        
        -- Create fallback products
        local fallbackProducts = {
            {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, description = "Get started with a handy pack of 1,000 coins!"},
            {id = "coins_5000", name = "5,500 Coins", coins = 5000, robux = 350, bonusCoins = 500, description = "Great value! Grab 5,000 coins and get an extra 500 on us!"},
            {id = "coins_10000", name = "11,500 Coins", coins = 10000, robux = 650, bonusCoins = 1500, description = "Supercharge your game with 10,000 coins, plus a 1,500 coin bonus!"}
        }
        
        -- Display notice message
        local notice = Instance.new("TextLabel")
        notice.Size = UDim2.new(1, -20, 0, 30)
        notice.Position = UDim2.new(0, 10, 0, 0)
        notice.BackgroundTransparency = 1
        notice.TextColor3 = Color3.fromRGB(255, 200, 0)
        notice.TextSize = 14
        notice.Font = Enum.Font.GothamBold
        notice.Text = "Using example products - AssetIds not configured"
        notice.TextWrapped = true
        notice.Parent = scrollFrame
        
        -- Add fallback products
        yOffset = 40 -- Start below the notice
        
        for i, product in ipairs(fallbackProducts) do
            local option = self:CreatePurchaseOption(product)
            option.Position = UDim2.new(0, 0, 0, yOffset)
            option.Parent = scrollFrame
            yOffset = yOffset + 90 -- Spacing between product items
        end
        
        -- Update the canvas size to fit all products
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
    end
    
    -- Make purchaseMenu visible
    purchaseMenu.Visible = true
end

-- Create a single purchase option
function CurrencyUI:CreatePurchaseOption(product)
    print("CreatePurchaseOption: Starting to create product UI")
    
    if not product then
        warn("CreatePurchaseOption: Product is nil")
        return Instance.new("Frame")
    end
    
    -- Extract product details with defaults
    local id = product.id or "unknown_product"
    local name = product.name or "Unknown Product"
    local description = product.description or "No description available"
    local robux = product.robux or 0
    local assetId = product.assetId or 0
    local bonusCoins = product.bonusCoins or 0
    local coins = product.coins or 0
    
    print("Creating option for: " .. name .. " (" .. id .. "), AssetId: " .. tostring(assetId))
    
    -- Create the option frame
    local optionFrame = Instance.new("Frame")
    optionFrame.Name = id
    optionFrame.Size = UDim2.new(1, -20, 0, 80)
    optionFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    optionFrame.BorderSizePixel = 0
    optionFrame.ZIndex = 12

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = optionFrame
    
    -- Add a subtle outline
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(80, 80, 80)
    stroke.Parent = optionFrame

    -- Create coin icon
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 40, 0, 40)
    coinIcon.Position = UDim2.new(0, 10, 0.5, -20)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = "rbxassetid://6034973115" -- Standard coin icon
    coinIcon.ZIndex = 13
    coinIcon.Parent = optionFrame

    -- Amount of coins label
    local coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "CoinsAmount"
    coinsLabel.Size = UDim2.new(0, 100, 0, 20)
    coinsLabel.Position = UDim2.new(0, 60, 0, 5)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.TextColor3 = Color3.fromRGB(255, 223, 70) -- Gold color for coins
    coinsLabel.TextSize = 18
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.Text = tostring(coins) .. " Coins"
    coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
    coinsLabel.ZIndex = 13
    coinsLabel.Parent = optionFrame

    -- Product name/description
    local productDescription = Instance.new("TextLabel")
    productDescription.Name = "ProductDescription"
    productDescription.Size = UDim2.new(1, -170, 0, 40)
    productDescription.Position = UDim2.new(0, 60, 0, 30)
    productDescription.BackgroundTransparency = 1
    productDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
    productDescription.TextSize = 14
    productDescription.Font = Enum.Font.Gotham
    productDescription.Text = description
    productDescription.TextWrapped = true
    productDescription.TextXAlignment = Enum.TextXAlignment.Left
    productDescription.TextYAlignment = Enum.TextYAlignment.Top
    productDescription.ZIndex = 13
    productDescription.Parent = optionFrame
    
    -- Robux price
    local robuxLabel = Instance.new("TextLabel")
    robuxLabel.Name = "RobuxLabel"
    robuxLabel.Size = UDim2.new(0, 80, 0, 20)
    robuxLabel.Position = UDim2.new(1, -90, 0, 10)
    robuxLabel.BackgroundTransparency = 1
    robuxLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green for Robux
    robuxLabel.TextSize = 16
    robuxLabel.Font = Enum.Font.GothamBold
    robuxLabel.Text = "R$ " .. robux
    robuxLabel.TextXAlignment = Enum.TextXAlignment.Right
    robuxLabel.ZIndex = 13
    robuxLabel.Parent = optionFrame

    -- Bonus coins if applicable
    if bonusCoins > 0 then
        local bonusLabel = Instance.new("TextLabel")
        bonusLabel.Name = "BonusLabel"
        bonusLabel.Size = UDim2.new(0, 80, 0, 20)
        bonusLabel.Position = UDim2.new(1, -90, 0, 30)
        bonusLabel.BackgroundTransparency = 1
        bonusLabel.TextColor3 = Color3.fromRGB(255, 223, 0) -- Gold for bonus
        bonusLabel.TextSize = 14
        bonusLabel.Font = Enum.Font.Gotham
        bonusLabel.Text = "+" .. bonusCoins .. " Bonus!"
        bonusLabel.TextXAlignment = Enum.TextXAlignment.Right
        bonusLabel.ZIndex = 13
        bonusLabel.Parent = optionFrame
    end

    -- Buy button
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0, 80, 0, 30)
    purchaseButton.Position = UDim2.new(1, -90, 1, -40)
    purchaseButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseButton.TextSize = 16
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.Text = "Buy"
    purchaseButton.ZIndex = 13
    purchaseButton.Parent = optionFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = purchaseButton

    -- Buy button hover effect
    purchaseButton.MouseEnter:Connect(function()
        purchaseButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    end)
    
    purchaseButton.MouseLeave:Connect(function()
        purchaseButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    end)

    -- Purchase functionality
    purchaseButton.MouseButton1Click:Connect(function()
        if assetId and assetId > 0 then
            pcall(function()
                MarketplaceService:PromptProductPurchase(self.player, assetId)
            end)
        else
            warn("Invalid assetId for product:", name, "ID:", assetId)
            
            -- Show error feedback on button
            purchaseButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            purchaseButton.Text = "Error"
            
            -- Reset after 2 seconds
            task.delay(2, function()
                purchaseButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
                purchaseButton.Text = "Buy"
            end)
        end
    end)

    return optionFrame
end

-- Helper function to check if Constants is properly loaded
function CurrencyUI:VerifyConstants()
    if not Constants then
        warn("VerifyConstants: Constants is nil")
        return false
    end
    
    if not Constants.CURRENCY then
        warn("VerifyConstants: Constants.CURRENCY is nil")
        return false
    end
    
    if not Constants.CURRENCY.PRODUCTS then
        warn("VerifyConstants: Constants.CURRENCY.PRODUCTS is nil")
        return false
    end
    
    if type(Constants.CURRENCY.PRODUCTS) ~= "table" then
        warn("VerifyConstants: Constants.CURRENCY.PRODUCTS is not a table")
        return false
    end
    
    if #Constants.CURRENCY.PRODUCTS == 0 then
        warn("VerifyConstants: Constants.CURRENCY.PRODUCTS is empty")
        return false
    end
    
    print("VerifyConstants: Constants is valid with " .. #Constants.CURRENCY.PRODUCTS .. " products")
    return true
end

-- Helper function to ensure valid icon ID is used
function CurrencyUI:GetValidIconId(id)
    if type(id) ~= "string" or not id:match("^rbxassetid://") then
        -- Default coin icon if ID is invalid
        return "rbxassetid://6034973115"
    end
    return id
end

-- COMPATIBILITY: Add aliases for method names used in the shared version
-- This ensures this implementation works with code expecting the shared version's API
CurrencyUI.SetupEventHandlers = CurrencyUI.SetupEventHandling

return CurrencyUI