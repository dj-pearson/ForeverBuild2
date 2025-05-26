-- BottomPurchasePopup.luau
-- Clean bottom purchase popup system that matches the user's existing UI style
-- Enhanced with Line of Sight detection to prevent prompts through walls
-- Enhanced with E-key purchase support for crowded areas

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Import LineOfSightChecker
local LineOfSightChecker
local lineOfSightSuccess = pcall(function()
    LineOfSightChecker = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("interaction"):WaitForChild("LineOfSightChecker"))
end)

if not lineOfSightSuccess then
    warn("BottomPurchasePopup: Could not load LineOfSightChecker, using basic proximity only")
    LineOfSightChecker = nil
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Safely require SharedModule for Constants
local SharedModule
local success = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
end)

if not success then
    warn("BottomPurchasePopup: Could not load SharedModule, using fallback pricing")
    SharedModule = {
        Constants = {
            ITEMS = {},
            ITEM_PRICES = {
                BASIC = {INGAME = 5, ROBUX = 5}
            }
        }
    }
end

-- Try to get currency manager
local CurrencyManager
local currencySuccess = pcall(function()
    CurrencyManager = SharedModule.CurrencyManager
end)

if not currencySuccess then
    warn("BottomPurchasePopup: Could not load CurrencyManager")
end

local BottomPurchasePopup = {}
BottomPurchasePopup.__index = BottomPurchasePopup

function BottomPurchasePopup.new()
    local self = setmetatable({}, BottomPurchasePopup)
    
    -- Configuration - OPTIMIZED FOR RESPONSIVENESS
    self.PROXIMITY_DISTANCE = 8
    self.UPDATE_INTERVAL = 0.05 -- Much faster update rate (20 FPS)
    self.SLOW_UPDATE_INTERVAL = 0.2 -- Slower rate when no items nearby
    self.FAST_UPDATE_DISTANCE = 12 -- Distance threshold for fast updates
    self.lastUpdate = 0
    self.fastUpdateMode = false
    
    -- State
    self.currentStoreItem = nil
    self.currentPopup = nil
    self.enabled = true
    
    -- E-key purchase state
    self.eKeyEnabled = true
    self.currentItemData = nil
    
    -- Connection tracking
    self.connections = {}
    
    -- Initialize LineOfSightChecker if available
    if LineOfSightChecker then
        self.lineOfSightChecker = LineOfSightChecker:Init()
        -- Optimize LineOfSightChecker for faster response
        self.lineOfSightChecker:SetMaxDistance(15)
        -- Reduce cache duration for more responsive updates
        if self.lineOfSightChecker.SetCacheDuration then
            self.lineOfSightChecker:SetCacheDuration(0.1)
        end
        print("BottomPurchasePopup: Line of sight detection enabled with fast response")
    else
        self.lineOfSightChecker = nil
        print("BottomPurchasePopup: Using basic proximity detection only")
    end
    
    return self
end

function BottomPurchasePopup:Initialize()
    print("BottomPurchasePopup: Initializing...")
    
    -- Setup E-key input handling
    self:SetupEKeyInput()
    
    -- Start the main update loop with dynamic update rates
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        local now = tick()
        
        -- Use dynamic update interval based on proximity to items
        local currentInterval = self.fastUpdateMode and self.UPDATE_INTERVAL or self.SLOW_UPDATE_INTERVAL
        
        if now - self.lastUpdate >= currentInterval then
            self.lastUpdate = now
            self:CheckForNearbyItems()
        end
    end)
    table.insert(self.connections, heartbeatConnection)
    
    print("BottomPurchasePopup: Ready! Small unobtrusive popup system active with E-key support.")
    return true
end

-- Setup E-key input handling
function BottomPurchasePopup:SetupEKeyInput()
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E and self.eKeyEnabled then
            if self.currentStoreItem and self.currentItemData then
                self:HandleEKeyPurchase()
            end
        end
    end)
    table.insert(self.connections, inputConnection)
    
    print("BottomPurchasePopup: E-key purchase system enabled")
end

-- Handle E-key purchase
function BottomPurchasePopup:HandleEKeyPurchase()
    if not self.currentStoreItem or not self.currentItemData then
        return
    end
    
    local currentCoins = self:GetPlayerCoins()
    local itemPrice = self.currentItemData.coinPrice or 5
    
    print("BottomPurchasePopup: E-key pressed - Player has", currentCoins, "coins, item costs", itemPrice)
    
    if currentCoins >= itemPrice then
        -- Player can afford it - proceed with purchase
        print("BottomPurchasePopup: E-key purchase with coins for", self.currentStoreItem.Name)
        self:PurchaseItem(self.currentStoreItem.Name, "INGAME")
    else
        -- Insufficient funds - show notification
        local shortfall = itemPrice - currentCoins
        print("BottomPurchasePopup: Insufficient funds - need", shortfall, "more coins")
        self:ShowInsufficientFundsNotification(shortfall, itemPrice, currentCoins)
    end
end

-- Get player's current coins
function BottomPurchasePopup:GetPlayerCoins()
    -- Try currency manager first
    if CurrencyManager and typeof(CurrencyManager.GetCoins) == "function" then
        local coins = CurrencyManager:GetCoins()
        if coins then return coins end
    end
    
    -- Fallback to leaderstats
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

-- Show insufficient funds notification
function BottomPurchasePopup:ShowInsufficientFundsNotification(shortfall, needed, current)
    -- Create notification UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InsufficientFundsNotification"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Notification frame (top center)
    local notificationFrame = Instance.new("Frame")
    notificationFrame.Size = UDim2.new(0, 350, 0, 80)
    notificationFrame.Position = UDim2.new(0.5, -175, 0, -100) -- Start above screen
    notificationFrame.BackgroundColor3 = Color3.fromRGB(60, 20, 20) -- Dark red
    notificationFrame.BorderSizePixel = 0
    notificationFrame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notificationFrame
    
    -- Red border for emphasis
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 50, 50)
    stroke.Thickness = 2
    stroke.Parent = notificationFrame
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -10, 0, 25)
    titleLabel.Position = UDim2.new(0, 5, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "💰 Insufficient Funds"
    titleLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Parent = notificationFrame
    
    -- Message
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -10, 0, 45)
    messageLabel.Position = UDim2.new(0, 5, 0, 30)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = string.format("Need %s more coins!\nRequired: %s | You have: %s", 
        self:FormatNumber(shortfall), 
        self:FormatNumber(needed), 
        self:FormatNumber(current))
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.TextSize = 12
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextXAlignment = Enum.TextXAlignment.Center
    messageLabel.TextYAlignment = Enum.TextYAlignment.Top
    messageLabel.Parent = notificationFrame
    
    -- Slide in animation
    local slideIn = TweenService:Create(notificationFrame, 
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -175, 0, 20)}
    )
    slideIn:Play()
    
    -- Auto hide after 3 seconds
    task.delay(3, function()
        local slideOut = TweenService:Create(notificationFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -175, 0, -100)}
        )
        slideOut:Play()
        slideOut.Completed:Connect(function()
            screenGui:Destroy()
        end)
    end)
end

-- Function to get correct pricing from Constants
function BottomPurchasePopup:GetItemPricing(itemName)
    local Constants = SharedModule.Constants
    
    -- First check if item exists in Constants.ITEMS
    if Constants.ITEMS and Constants.ITEMS[itemName] then
        local itemData = Constants.ITEMS[itemName]
        if itemData.price then
            if type(itemData.price) == "table" then
                return itemData.price.INGAME or 5, itemData.price.ROBUX or 5
            else
                -- Old format, use same price for both
                return itemData.price, itemData.price
            end
        end
    end
    
    -- Determine tier and get price from ITEM_PRICES
    local tier = "BASIC" -- Default tier
    
    -- Simple tier detection based on item name
    local lowerName = itemName:lower()
    if lowerName:find("glow") or lowerName:find("basic") then
        tier = "BASIC"
    elseif lowerName:find("level1") then
        tier = "LEVEL_1"
    elseif lowerName:find("level2") then
        tier = "LEVEL_2"
    elseif lowerName:find("rare") then
        tier = "RARE"
    elseif lowerName:find("exclusive") then
        tier = "EXCLUSIVE"
    end
    
    -- Get price from tier
    if Constants.ITEM_PRICES and Constants.ITEM_PRICES[tier] then
        local tierPrice = Constants.ITEM_PRICES[tier]
        return tierPrice.INGAME or 5, tierPrice.ROBUX or 5
    end
    
    -- Fallback
    return 5, 5
end

function BottomPurchasePopup:CreateBottomPurchasePopup(item)
    local itemName = item.Name:gsub("_", " ")
    local coinPrice, robuxPrice = self:GetItemPricing(item.Name)
    
    -- Store current item data for E-key purchases
    self.currentItemData = {
        name = itemName,
        coinPrice = coinPrice,
        robuxPrice = robuxPrice,
        originalName = item.Name
    }
    
    -- Remove existing popup
    if self.currentPopup then
        self.currentPopup:Destroy()
        self.currentPopup = nil
    end
    
    -- Create popup container
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BottomPurchasePopup"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main popup frame (small and unobtrusive)
    local popupFrame = Instance.new("Frame")
    popupFrame.Size = UDim2.new(0, 360, 0, 120) -- Slightly wider for E-key text
    popupFrame.Position = UDim2.new(0.5, -180, 1, -140) -- Bottom center
    popupFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    popupFrame.BorderSizePixel = 0
    popupFrame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = popupFrame
    
    -- Subtle border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = popupFrame
    
    -- Item name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 25)
    nameLabel.Position = UDim2.new(0, 5, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.Parent = popupFrame
    
    -- Price label (matches screenshot style)
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, -10, 0, 15)
    priceLabel.Position = UDim2.new(0, 5, 0, 30)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = string.format("Price: 💰%d Coins or 💎%d Robux", coinPrice, robuxPrice)
    priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    priceLabel.TextSize = 12
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.TextXAlignment = Enum.TextXAlignment.Center
    priceLabel.Parent = popupFrame
    
    -- E-key prompt (NEW)
    local eKeyLabel = Instance.new("TextLabel")
    eKeyLabel.Size = UDim2.new(1, -10, 0, 15)
    eKeyLabel.Position = UDim2.new(0, 5, 0, 45)
    eKeyLabel.BackgroundTransparency = 1
    
    -- Check affordability and set appropriate text/color
    local currentCoins = self:GetPlayerCoins()
    if currentCoins >= coinPrice then
        eKeyLabel.Text = "[E] Quick Purchase with Coins"
        eKeyLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green
    else
        eKeyLabel.Text = "[E] Need More Coins"
        eKeyLabel.TextColor3 = Color3.fromRGB(255, 150, 150) -- Light red
    end
    
    eKeyLabel.TextSize = 11
    eKeyLabel.Font = Enum.Font.GothamBold
    eKeyLabel.TextXAlignment = Enum.TextXAlignment.Center
    eKeyLabel.Parent = popupFrame
    
    -- Button container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -20, 0, 35)
    buttonContainer.Position = UDim2.new(0, 10, 0, 75)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = popupFrame
    
    -- Coins button (yellow like in screenshot)
    local coinsButton = Instance.new("TextButton")
    coinsButton.Size = UDim2.new(0.48, 0, 1, 0)
    coinsButton.Position = UDim2.new(0, 0, 0, 0)
    coinsButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
    coinsButton.Text = string.format("💰 Buy with %d Coins", coinPrice)
    coinsButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    coinsButton.TextSize = 11
    coinsButton.Font = Enum.Font.GothamBold
    coinsButton.Parent = buttonContainer
    
    local coinsCorner = Instance.new("UICorner")
    coinsCorner.CornerRadius = UDim.new(0, 6)
    coinsCorner.Parent = coinsButton
    
    -- Robux button (green like in screenshot)
    local robuxButton = Instance.new("TextButton")
    robuxButton.Size = UDim2.new(0.48, 0, 1, 0)
    robuxButton.Position = UDim2.new(0.52, 0, 0, 0)
    robuxButton.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
    robuxButton.Text = string.format("💎 Buy with %d Robux", robuxPrice)
    robuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxButton.TextSize = 11
    robuxButton.Font = Enum.Font.GothamBold
    robuxButton.Parent = buttonContainer
    
    local robuxCorner = Instance.new("UICorner")
    robuxCorner.CornerRadius = UDim.new(0, 6)
    robuxCorner.Parent = robuxButton
    
    -- Button click handlers
    coinsButton.MouseButton1Click:Connect(function()
        print("BottomPurchasePopup: Purchasing", item.Name, "with", coinPrice, "coins")
        self:PurchaseItem(item.Name, "INGAME")
    end)
    
    robuxButton.MouseButton1Click:Connect(function()
        print("BottomPurchasePopup: Purchasing", item.Name, "with", robuxPrice, "Robux")
        self:PurchaseItem(item.Name, "ROBUX")
    end)
    
    -- Smooth slide-in animation (only if this is a new popup, not a replacement)
    local isReplacement = self.currentPopup ~= nil
    
    if not isReplacement then
        -- Start below screen for new popups
        popupFrame.Position = UDim2.new(0.5, -180, 1, 20) 
        local slideIn = TweenService:Create(popupFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -180, 1, -140)
        })
        slideIn:Play()
    else
        -- For replacements, just put it in the correct position immediately
        popupFrame.Position = UDim2.new(0.5, -180, 1, -140)
    end
    
    self.currentPopup = screenGui
    print("BottomPurchasePopup: Showing popup for", item.Name, "with E-key support")
end

function BottomPurchasePopup:PurchaseItem(itemName, currencyType)
    local purchaseEvent = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("PurchaseItem")
    if purchaseEvent then
        purchaseEvent:FireServer(itemName, 1, currencyType)
        print("BottomPurchasePopup: Purchase request sent for", itemName, "with", currencyType)
    else
        warn("BottomPurchasePopup: PurchaseItem remote event not found")
    end
    
    -- Hide popup after purchase
    self:HidePopup()
end

function BottomPurchasePopup:HidePopup()
    if self.currentPopup then
        local popupFrame = self.currentPopup:FindFirstChild("Frame")
        if popupFrame then
            local slideOut = TweenService:Create(popupFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -180, 1, 20)
            })
            slideOut:Play()
            slideOut.Completed:Connect(function()
                self.currentPopup:Destroy()
                self.currentPopup = nil
            end)
        else
            self.currentPopup:Destroy()
            self.currentPopup = nil
        end
    end
    self.currentStoreItem = nil
    self.currentItemData = nil -- Clear E-key data
end

function BottomPurchasePopup:CheckForNearbyItems()
    if not self.enabled then return end
    
    local character = player.Character
    if not character then 
        self.fastUpdateMode = false
        return 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        self.fastUpdateMode = false
        return 
    end
    
    local playerPosition = humanoidRootPart.Position
    local closestItem = nil
    local closestDistance = self.PROXIMITY_DISTANCE
    local nearestDistance = math.huge -- Track nearest item for update mode
    
    -- Quick scan for performance optimization
    local itemsFound = 0
    local proximityChecks = 0
    local lineOfSightChecks = 0
    
    -- Scan Items folder for purchasable items (including glow items in subfolders)
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder then
        local function scanForItems(parent)
            for _, item in ipairs(parent:GetChildren()) do
                if item:IsA("Model") or item:IsA("Part") then
                    -- Check if item has purchase attributes
                    if item:GetAttribute("Purchasable") or item:GetAttribute("Price") or item:GetAttribute("priceIngame") then
                        itemsFound = itemsFound + 1
                        local itemPosition
                        
                        -- Get position safely
                        if item:IsA("Model") and item.PrimaryPart then
                            itemPosition = item.PrimaryPart.Position
                        elseif item:IsA("Model") then
                            itemPosition = item:GetPivot().Position
                        elseif item:IsA("Part") then
                            itemPosition = item.Position
                        end
                        
                        if itemPosition then
                            local distance = (itemPosition - playerPosition).Magnitude
                            proximityChecks = proximityChecks + 1
                            
                            -- Track nearest item for update mode optimization
                            if distance < nearestDistance then
                                nearestDistance = distance
                            end
                            
                            if distance < closestDistance then
                                -- For very close items (< 3 studs), skip line of sight for instant response
                                local hasLineOfSight = true
                                if distance >= 3 and self.lineOfSightChecker then
                                    lineOfSightChecks = lineOfSightChecks + 1
                                    hasLineOfSight = self.lineOfSightChecker:HasLineOfSight(player, item)
                                end
                                
                                if hasLineOfSight then
                                    closestDistance = distance
                                    closestItem = item
                                end
                            end
                        end
                    end
                elseif item:IsA("Folder") then
                    scanForItems(item) -- Recursive scan for glow items
                end
            end
        end
        
        scanForItems(itemsFolder)
    end
    
    -- Dynamic update mode based on proximity to any purchasable item
    local shouldUseFastMode = nearestDistance < self.FAST_UPDATE_DISTANCE
    if shouldUseFastMode ~= self.fastUpdateMode then
        self.fastUpdateMode = shouldUseFastMode
        -- Optional debug output
        -- print("BottomPurchasePopup: Switched to", shouldUseFastMode and "FAST" or "SLOW", "update mode")
    end
    
    -- Handle popup changes
    if closestItem ~= self.currentStoreItem then
        self.currentStoreItem = closestItem
        
        if self.currentStoreItem then
            -- If we're switching from one item to another, update immediately
            -- If there's an existing popup, we'll replace it directly
            self:CreateBottomPurchasePopup(self.currentStoreItem)
        else
            -- No item nearby, hide popup
            self:HidePopup()
        end
    end
end

function BottomPurchasePopup:SetEnabled(enabled)
    self.enabled = enabled
    if not enabled then
        self:HidePopup()
    end
end

function BottomPurchasePopup:SetEKeyEnabled(enabled)
    self.eKeyEnabled = enabled
end

function BottomPurchasePopup:FormatNumber(number)
    local formatted = tostring(number)
    local k = 3
    while k <= #formatted do
        formatted = formatted:sub(1, #formatted - k) .. "," .. formatted:sub(#formatted - k + 1)
        k = k + 4
    end
    return formatted
end

function BottomPurchasePopup:Cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Hide popup
    self:HidePopup()
    
    print("BottomPurchasePopup: Cleaned up successfully")
end

return BottomPurchasePopup 