-- CurrencyManager.luau
-- Unified currency system that consolidates all currency functionality
-- Replaces multiple conflicting currency modules

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Safe SharedModule loading with comprehensive fallbacks
local SharedModule
local Constants
local LazyLoadModules

local function loadSharedModule()
    local success, result = pcall(function()
        return require(ReplicatedStorage:WaitForChild("shared", 5))
    end)
    
    if success and result then
        SharedModule = result
        Constants = result.Constants or {}
        LazyLoadModules = result.LazyLoadModules or {
            register = function() end,
            require = function() return nil end
        }
        print("[CurrencyManager] Successfully loaded SharedModule")
        return true
    else
        warn("[CurrencyManager] Failed to load SharedModule:", result)
        return false
    end
end

-- Initialize with fallbacks
if not loadSharedModule() then
    print("[CurrencyManager] Creating fallback systems")
    Constants = {
        CURRENCY = {
            STARTING_COINS = 200,
            DEFAULT_CURRENCY = "Coins",
            PRODUCTS = {
                {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, assetId = 0, description = "Get started with a handy pack of 1,000 coins!"},
                {id = "coins_5000", name = "5,500 Coins", coins = 5000, robux = 350, bonusCoins = 500, assetId = 0, description = "Great value! Grab 5,000 coins and get an extra 500 on us!"},
                {id = "coins_10000", name = "11,500 Coins", coins = 10000, robux = 650, bonusCoins = 1500, assetId = 0, description = "Supercharge your game with 10,000 coins, plus a 1,500 coin bonus!"}
            }
        },
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255),
            SUCCESS = Color3.fromRGB(0, 170, 0),
            WARNING = Color3.fromRGB(255, 215, 0),
            ERROR = Color3.fromRGB(200, 50, 50),
            BACKGROUND_PRIMARY = Color3.fromRGB(30, 30, 30),
            BACKGROUND_SECONDARY = Color3.fromRGB(44, 44, 46),
            BORDER = Color3.fromRGB(255, 223, 70)
        }
    }
    LazyLoadModules = {
        register = function() end,
        require = function() return nil end
    }
    SharedModule = {
        Constants = Constants,
        LazyLoadModules = LazyLoadModules
    }
end

local CurrencyManager = {}
CurrencyManager.__index = CurrencyManager

-- Configuration
local CONFIG = {
    ANIMATION_DURATION = 0.3,
    UI_SIZE = UDim2.new(0, 220, 0, 76),
    UI_POSITION = UDim2.new(1, -240, 0, 24),
    UPDATE_INTERVAL = 1.0,
    DEBUG_MODE = false,
    PURCHASE_MENU_SIZE = UDim2.new(0, 400, 0, 500),
    LEVEL_UPDATE_INTERVAL = 10
}

function CurrencyManager.new()
    local self = setmetatable({}, CurrencyManager)
    
    -- Core properties
    self.player = Players.LocalPlayer
    self.isActive = false
    
    -- Data
    self.balance = 0
    self.level = 1
    
    -- UI components
    self.gui = nil
    self.mainFrame = nil
    self.balanceLabel = nil
    self.levelLabel = nil
    self.purchaseButton = nil
    self.purchaseMenu = nil
    
    -- Connections for cleanup
    self.connections = {}
    
    -- Remote events
    self.remotes = {}
    
    -- State tracking
    self.lastUpdateTime = 0
    self.lastLevelUpdate = 0
    
    return self
end

function CurrencyManager:Initialize()
    print("[CurrencyManager] Initializing...")
    
    if not self.player then
        warn("[CurrencyManager] No LocalPlayer found")
        return false
    end
    
    -- Setup remote events
    self:SetupRemoteEvents()
    
    -- Create UI components
    self:CreateUI()
    
    -- Setup update loop
    self:StartUpdateLoop()
    
    -- Setup event handlers
    self:SetupEventHandlers()
    
    -- Initial data fetch
    self:FetchInitialData()
    
    self.isActive = true
    print("[CurrencyManager] Initialization complete")
    return true
end

function CurrencyManager:SetupRemoteEvents()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
    end
    
    if not remotesFolder then
        warn("[CurrencyManager] Remotes folder not found")
        return
    end
    
    -- Cache commonly used remote events
    local remoteNames = {
        "UpdateBalance", "GetMyBalance"
    }
    
    for _, remoteName in ipairs(remoteNames) do
        local remote = remotesFolder:FindFirstChild(remoteName)
        if remote then
            self.remotes[remoteName] = remote
        else
            if CONFIG.DEBUG_MODE then
                warn("[CurrencyManager] Remote not found:", remoteName)
            end
        end
    end
    
    print("[CurrencyManager] Remote events cached:", #remoteNames, "requested,", 
          self:CountTable(self.remotes), "found")
end

function CurrencyManager:CreateUI()
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui then
        warn("[CurrencyManager] PlayerGui not found")
        return false
    end
    
    -- Remove existing currency UI
    local existingUIs = {
        "CurrencyUI", "CurrencyUIScreen", "DirectCurrencyUI"
    }
    
    for _, uiName in ipairs(existingUIs) do
        local existingUI = playerGui:FindFirstChild(uiName)
        if existingUI then
            existingUI:Destroy()
            print("[CurrencyManager] Removed existing UI:", uiName)
        end
    end
    
    -- Create main ScreenGui
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "CurrencyUI"
    self.gui.ResetOnSpawn = false
    self.gui.Parent = playerGui
    
    -- Create main frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "MainFrame"
    self.mainFrame.Size = CONFIG.UI_SIZE
    self.mainFrame.Position = CONFIG.UI_POSITION
    self.mainFrame.BackgroundColor3 = Constants.UI_COLORS.BACKGROUND_PRIMARY
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Parent = self.gui
    
    -- Add corner radius and border
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = self.mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Constants.UI_COLORS.BORDER
    stroke.Parent = self.mainFrame
    
    -- Create content layout
    self:CreateMainContent()
    
    print("[CurrencyManager] UI components created")
    return true
end

function CurrencyManager:CreateMainContent()
    -- Add padding
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = self.mainFrame
    
    -- Coin icon
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 24, 0, 24)
    coinIcon.Position = UDim2.new(0, 0, 0, 0)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = "rbxassetid://6034973115" -- Coin icon
    coinIcon.Parent = self.mainFrame
    
    -- Balance label
    self.balanceLabel = Instance.new("TextLabel")
    self.balanceLabel.Name = "BalanceLabel"
    self.balanceLabel.Size = UDim2.new(0, 120, 0, 24)
    self.balanceLabel.Position = UDim2.new(0, 32, 0, 0)
    self.balanceLabel.BackgroundTransparency = 1
    self.balanceLabel.Text = "---"
    self.balanceLabel.TextColor3 = Constants.UI_COLORS.WARNING
    self.balanceLabel.TextSize = 18
    self.balanceLabel.Font = Enum.Font.GothamBold
    self.balanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.balanceLabel.Parent = self.mainFrame
    
    -- Level label
    self.levelLabel = Instance.new("TextLabel")
    self.levelLabel.Name = "LevelLabel"
    self.levelLabel.Size = UDim2.new(0, 120, 0, 20)
    self.levelLabel.Position = UDim2.new(0, 32, 0, 26)
    self.levelLabel.BackgroundTransparency = 1
    self.levelLabel.Text = "⭐ Level 1"
    self.levelLabel.TextColor3 = Constants.UI_COLORS.TEXT
    self.levelLabel.TextSize = 14
    self.levelLabel.Font = Enum.Font.Gotham
    self.levelLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.levelLabel.Parent = self.mainFrame
    
    -- Purchase button
    self.purchaseButton = Instance.new("TextButton")
    self.purchaseButton.Name = "PurchaseButton"
    self.purchaseButton.Size = UDim2.new(0, 24, 0, 24)
    self.purchaseButton.Position = UDim2.new(1, -32, 0, 0)
    self.purchaseButton.BackgroundColor3 = Constants.UI_COLORS.SUCCESS
    self.purchaseButton.Text = "+"
    self.purchaseButton.TextColor3 = Constants.UI_COLORS.TEXT
    self.purchaseButton.TextSize = 18
    self.purchaseButton.Font = Enum.Font.GothamBold
    self.purchaseButton.BorderSizePixel = 0
    self.purchaseButton.Parent = self.mainFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = self.purchaseButton
    
    -- Purchase button functionality
    self.purchaseButton.MouseButton1Click:Connect(function()
        self:TogglePurchaseMenu()
    end)
    
    -- Hover effects
    self.purchaseButton.MouseEnter:Connect(function()
        TweenService:Create(self.purchaseButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        }):Play()
    end)
    
    self.purchaseButton.MouseLeave:Connect(function()
        TweenService:Create(self.purchaseButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Constants.UI_COLORS.SUCCESS
        }):Play()
    end)
end

function CurrencyManager:StartUpdateLoop()
    local connection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- Regular updates
        if currentTime - self.lastUpdateTime >= CONFIG.UPDATE_INTERVAL then
            self:Update()
            self.lastUpdateTime = currentTime
        end
        
        -- Level updates (less frequent)
        if currentTime - self.lastLevelUpdate >= CONFIG.LEVEL_UPDATE_INTERVAL then
            self:UpdateLevelFromXP()
            self.lastLevelUpdate = currentTime
        end
    end)
    table.insert(self.connections, connection)
    
    print("[CurrencyManager] Update loop started")
end

function CurrencyManager:SetupEventHandlers()
    -- Listen for balance updates from server
    if self.remotes.UpdateBalance then
        local connection = self.remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
            self:UpdateBalance(newBalance)
        end)
        table.insert(self.connections, connection)
        print("[CurrencyManager] Connected to UpdateBalance event")
    else
        -- Retry connection after delay
        task.delay(2, function()
            local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
            if remotesFolder then
                local updateBalanceEvent = remotesFolder:FindFirstChild("UpdateBalance")
                if updateBalanceEvent then
                    local connection = updateBalanceEvent.OnClientEvent:Connect(function(newBalance)
                        self:UpdateBalance(newBalance)
                    end)
                    table.insert(self.connections, connection)
                    print("[CurrencyManager] Connected to UpdateBalance event after delay")
                end
            end
        end)
    end
end

function CurrencyManager:FetchInitialData()
    -- Fetch initial balance
    if self.remotes.GetMyBalance then
        local success, balance = pcall(function()
            return self.remotes.GetMyBalance:InvokeServer()
        end)
        
        if success and type(balance) == "number" then
            self:UpdateBalance(balance)
        else
            warn("[CurrencyManager] Failed to fetch initial balance:", balance)
            self:UpdateBalance(Constants.CURRENCY.STARTING_COINS)
        end
    else
        warn("[CurrencyManager] GetMyBalance remote not available")
        self:UpdateBalance(Constants.CURRENCY.STARTING_COINS)
    end
    
    -- Fetch initial level
    self:UpdateLevelFromXP()
end

function CurrencyManager:Update()
    if not self.isActive then return end
    
    -- Periodic health checks and updates can go here
    -- For now, just ensure UI is still valid
    if not self.gui or not self.gui.Parent then
        warn("[CurrencyManager] UI was destroyed, reinitializing...")
        self:CreateUI()
    end
end

function CurrencyManager:UpdateBalance(balance)
    if type(balance) ~= "number" then
        warn("[CurrencyManager] Invalid balance type:", type(balance))
        return
    end
    
    self.balance = balance
    
    if self.balanceLabel then
        -- Animate balance change
        local currentText = self.balanceLabel.Text
        self.balanceLabel.Text = tostring(balance)
        
        -- Brief highlight animation
        local originalColor = self.balanceLabel.TextColor3
        self.balanceLabel.TextColor3 = Constants.UI_COLORS.SUCCESS
        
        TweenService:Create(self.balanceLabel, TweenInfo.new(0.5), {
            TextColor3 = originalColor
        }):Play()
        
        if CONFIG.DEBUG_MODE then
            print("[CurrencyManager] Balance updated:", balance)
        end
    else
        warn("[CurrencyManager] Balance label not found")
    end
end

function CurrencyManager:UpdateLevel(level)
    if type(level) ~= "number" then
        warn("[CurrencyManager] Invalid level type:", type(level))
        return
    end
    
    self.level = level
    
    if self.levelLabel then
        self.levelLabel.Text = "⭐ Level " .. tostring(level)
        
        if CONFIG.DEBUG_MODE then
            print("[CurrencyManager] Level updated:", level)
        end
    else
        warn("[CurrencyManager] Level label not found")
    end
end

function CurrencyManager:UpdateLevelFromXP()
    -- Try to get level from XP system
    local success, level = pcall(function()
        local xpManager = _G.ForeverBuildSystems and _G.ForeverBuildSystems.XPManager
        if xpManager and xpManager.GetPlayerLevel then
            return xpManager:GetPlayerLevel(self.player)
        end
        return 1 -- Default level
    end)
    
    if success and level then
        self:UpdateLevel(level)
    else
        if CONFIG.DEBUG_MODE then
            warn("[CurrencyManager] Failed to get level from XP system")
        end
    end
end

function CurrencyManager:TogglePurchaseMenu()
    if self.purchaseMenu and self.purchaseMenu.Parent then
        self:HidePurchaseMenu()
    else
        self:ShowPurchaseMenu()
    end
end

function CurrencyManager:ShowPurchaseMenu()
    if self.purchaseMenu and self.purchaseMenu.Parent then
        return -- Already showing
    end
    
    -- Create overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "PurchaseOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = self.gui
    
    -- Create purchase menu
    self.purchaseMenu = Instance.new("Frame")
    self.purchaseMenu.Name = "PurchaseMenu"
    self.purchaseMenu.Size = CONFIG.PURCHASE_MENU_SIZE
    self.purchaseMenu.Position = UDim2.new(0.5, -CONFIG.PURCHASE_MENU_SIZE.X.Offset/2, 0.5, -CONFIG.PURCHASE_MENU_SIZE.Y.Offset/2)
    self.purchaseMenu.BackgroundColor3 = Constants.UI_COLORS.BACKGROUND_SECONDARY
    self.purchaseMenu.BorderSizePixel = 0
    self.purchaseMenu.Parent = overlay
    
    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 12)
    menuCorner.Parent = self.purchaseMenu
    
    -- Create menu content
    self:CreatePurchaseMenuContent()
    
    -- Close on overlay click
    overlay.MouseButton1Click:Connect(function()
        self:HidePurchaseMenu()
    end)
    
    -- Animate in
    self.purchaseMenu.BackgroundTransparency = 1
    overlay.BackgroundTransparency = 1
    
    TweenService:Create(overlay, TweenInfo.new(CONFIG.ANIMATION_DURATION), {
        BackgroundTransparency = 0.5
    }):Play()
    
    TweenService:Create(self.purchaseMenu, TweenInfo.new(CONFIG.ANIMATION_DURATION), {
        BackgroundTransparency = 0
    }):Play()
end

function CurrencyManager:HidePurchaseMenu()
    if not self.purchaseMenu or not self.purchaseMenu.Parent then
        return
    end
    
    local overlay = self.purchaseMenu.Parent
    
    local hideTween = TweenService:Create(overlay, TweenInfo.new(CONFIG.ANIMATION_DURATION), {
        BackgroundTransparency = 1
    })
    
    hideTween.Completed:Connect(function()
        if overlay and overlay.Parent then
            overlay:Destroy()
        end
        self.purchaseMenu = nil
    end)
    
    hideTween:Play()
end

function CurrencyManager:CreatePurchaseMenuContent()
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Purchase Coins"
    title.TextColor3 = Constants.UI_COLORS.TEXT
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = self.purchaseMenu
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Constants.UI_COLORS.ERROR
    closeButton.Text = "✕"
    closeButton.TextColor3 = Constants.UI_COLORS.TEXT
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = self.purchaseMenu
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:HidePurchaseMenu()
    end)
    
    -- Scrolling frame for products
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ProductsFrame"
    scrollFrame.Size = UDim2.new(1, -20, 1, -70)
    scrollFrame.Position = UDim2.new(0, 10, 0, 60)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Constants.UI_COLORS.PRIMARY
    scrollFrame.Parent = self.purchaseMenu
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = scrollFrame
    
    -- Create product options
    local totalHeight = 0
    local itemHeight = 85
    
    if Constants.CURRENCY and Constants.CURRENCY.PRODUCTS then
        for i, product in ipairs(Constants.CURRENCY.PRODUCTS) do
            local productFrame = self:CreateProductOption(product, i)
            productFrame.Parent = scrollFrame
            totalHeight = totalHeight + itemHeight + 10
        end
        
        if #Constants.CURRENCY.PRODUCTS > 0 then
            totalHeight = totalHeight - 10 -- Remove last padding
        end
    else
        -- No products message
        local noProductsLabel = Instance.new("TextLabel")
        noProductsLabel.Size = UDim2.new(1, 0, 0, 50)
        noProductsLabel.BackgroundTransparency = 1
        noProductsLabel.Text = "No currency products available"
        noProductsLabel.TextColor3 = Constants.UI_COLORS.TEXT
        noProductsLabel.TextSize = 16
        noProductsLabel.Font = Enum.Font.Gotham
        noProductsLabel.TextXAlignment = Enum.TextXAlignment.Center
        noProductsLabel.Parent = scrollFrame
        totalHeight = 60
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

function CurrencyManager:CreateProductOption(product, layoutOrder)
    local frame = Instance.new("Frame")
    frame.Name = "Product_" .. (product.id or layoutOrder)
    frame.Size = UDim2.new(1, 0, 0, 85)
    frame.BackgroundColor3 = Constants.UI_COLORS.BACKGROUND_PRIMARY
    frame.BorderSizePixel = 0
    frame.LayoutOrder = layoutOrder
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 15)
    padding.PaddingRight = UDim.new(0, 15)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = frame
    
    -- Product name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ProductName"
    nameLabel.Size = UDim2.new(0.6, 0, 0, 25)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = product.name or "Unknown Product"
    nameLabel.TextColor3 = Constants.UI_COLORS.TEXT
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = frame
    
    -- Product description
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "ProductDescription"
    descLabel.Size = UDim2.new(0.6, 0, 0, 20)
    descLabel.Position = UDim2.new(0, 0, 0, 25)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = product.description or "No description"
    descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    descLabel.TextSize = 12
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Parent = frame
    
    -- Coins amount
    local coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "CoinsAmount"
    coinsLabel.Size = UDim2.new(0.6, 0, 0, 20)
    coinsLabel.Position = UDim2.new(0, 0, 0, 45)
    coinsLabel.BackgroundTransparency = 1
    
    local totalCoins = (product.coins or 0) + (product.bonusCoins or 0)
    local coinsText = tostring(product.coins or 0) .. " Coins"
    if product.bonusCoins and product.bonusCoins > 0 then
        coinsText = coinsText .. " + " .. product.bonusCoins .. " Bonus!"
    end
    
    coinsLabel.Text = coinsText
    coinsLabel.TextColor3 = Constants.UI_COLORS.WARNING
    coinsLabel.TextSize = 14
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
    coinsLabel.Parent = frame
    
    -- Purchase button
    local buyButton = Instance.new("TextButton")
    buyButton.Name = "BuyButton"
    buyButton.Size = UDim2.new(0, 80, 0, 35)
    buyButton.Position = UDim2.new(1, -80, 0.5, -17.5)
    buyButton.BackgroundColor3 = Constants.UI_COLORS.PRIMARY
    buyButton.Text = "R$ " .. (product.robux or 0)
    buyButton.TextColor3 = Constants.UI_COLORS.TEXT
    buyButton.TextSize = 16
    buyButton.Font = Enum.Font.GothamBold
    buyButton.BorderSizePixel = 0
    buyButton.Parent = frame
    
    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = UDim.new(0, 6)
    buyCorner.Parent = buyButton
    
    -- Purchase functionality
    buyButton.MouseButton1Click:Connect(function()
        if product.assetId and product.assetId > 0 then
            local success, error = pcall(function()
                MarketplaceService:PromptProductPurchase(self.player, product.assetId)
            end)
            
            if not success then
                warn("[CurrencyManager] Purchase error:", error)
                -- Show error feedback
                buyButton.BackgroundColor3 = Constants.UI_COLORS.ERROR
                buyButton.Text = "Error"
                
                task.delay(2, function()
                    buyButton.BackgroundColor3 = Constants.UI_COLORS.PRIMARY
                    buyButton.Text = "R$ " .. (product.robux or 0)
                end)
            end
        else
            warn("[CurrencyManager] Invalid assetId for product:", product.name)
        end
    end)
    
    -- Hover effects
    buyButton.MouseEnter:Connect(function()
        TweenService:Create(buyButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(0, 140, 200)
        }):Play()
    end)
    
    buyButton.MouseLeave:Connect(function()
        TweenService:Create(buyButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Constants.UI_COLORS.PRIMARY
        }):Play()
    end)
    
    return frame
end

function CurrencyManager:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function CurrencyManager:Cleanup()
    print("[CurrencyManager] Cleaning up...")
    
    self.isActive = false
    
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Clean up UI
    if self.gui then
        self.gui:Destroy()
    end
    
    print("[CurrencyManager] Cleanup complete")
end

return CurrencyManager 